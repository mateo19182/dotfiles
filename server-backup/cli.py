#!/usr/bin/env python3
"""Server backup command. No upload starts until scope and keys are ready."""
import argparse
import fcntl
import getpass
import json
import os
from pathlib import Path
import secrets
import sys
import time

from policy import BackupError, atomic_json, selection_plan, validate_mount
from runner import Runner

CONFIG = Path('/home/mateo/.config/server-backup/config.json')
STATE = Path('/home/mateo/.local/state/server-backup')
# Weekly local and monthly cloud schedules, plus a day of slack.
MAX_AGE_HOURS = {'local': 8 * 24, 'cloud': 32 * 24}


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=CONFIG)
    parser.add_argument('--state', type=Path, default=STATE)
    parser.add_argument('--wait-lock', action='store_true',
                        help='Queue scheduled backups behind another backup command')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('plan')
    commands.add_parser('keygen')
    commands.add_parser('key-saved')
    commands.add_parser('configure-cloud')
    commands.add_parser('status')
    commands.add_parser('cleanup-approved-2024')
    choose = commands.add_parser('select')
    choose.add_argument('id')
    choose.add_argument('choice', choices=['local', 'cloud', 'both', 'skip', 'pending'])
    for name in ['init', 'backup', 'check', 'restore-test', 'retention', 'estimate']:
        command = commands.add_parser(name)
        command.add_argument('target', choices=['local', 'cloud'])
        if name == 'retention':
            command.add_argument('--apply', action='store_true')
        if name == 'check':
            command.add_argument('--full', action='store_true')
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    args.state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (args.state / 'run.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | (0 if args.wait_lock else fcntl.LOCK_NB))
        except BlockingIOError:
            raise BackupError('Another backup command is running')
        runner = Runner(config, args.state)
        if args.command == 'plan':
            for item in config['selections']:
                if item['choice'] == 'skip':
                    continue
                print(f'{item["id"]:24} {item["choice"]:8} {item.get("path", item.get("container", ""))}')
            for target in ['local', 'cloud']:
                roots, excluded = selection_plan(config, target)
                print(f'\n{target}:')
                print('Includes:', *roots, sep='\n  ')
                print('Excludes:', *excluded, sep='\n  ')
            print('\nPending selections are omitted and remain visible.')
        elif args.command == 'select':
            item = next((i for i in config['selections'] if i['id'] == args.id), None)
            if item is None:
                raise BackupError('Unknown selection ID')
            item['choice'] = args.choice
            atomic_json(args.config, config)
            print('Selection saved; the next scheduled backup uses it')
        elif args.command == 'keygen':
            key = Path(config['password_file'])
            fd = os.open(key, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as file:
                file.write(secrets.token_urlsafe(48) + '\n')
            print(f'Created encryption key at {key}. Save it in your password manager from your SSH terminal.')
        elif args.command == 'key-saved':
            if not Path(config['password_file']).is_file():
                raise BackupError('Generate the key first')
            config['recovery_key_saved'] = True
            atomic_json(args.config, config)
            print('Recorded your confirmation that the recovery key is saved off-server')
        elif args.command == 'configure-cloud':
            cloud = config['profiles']['cloud']
            default_account = cloud.get('account', '')
            default_bucket = cloud.get('bucket', '')
            account = input(f'Cloudflare account ID [{default_account}]: ').strip() or default_account
            bucket = input(f'Dedicated private R2 bucket name [{default_bucket}]: ').strip() or default_bucket
            import re
            if not re.fullmatch('[a-fA-F0-9]{32}', account) or not re.fullmatch('[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]', bucket):
                raise BackupError('Invalid account ID or bucket name')
            access = getpass.getpass('Bucket-scoped Access Key ID: ')
            secret = getpass.getpass('Secret Access Key: ')
            if not access or not secret:
                raise BackupError('Both credentials are required')
            atomic_json(cloud['credentials_file'], {'AWS_ACCESS_KEY_ID': access,
                        'AWS_SECRET_ACCESS_KEY': secret, 'AWS_DEFAULT_REGION': 'auto'})
            cloud['repository'] = f's3:https://{account}.r2.cloudflarestorage.com/{bucket}/server-backup'
            cloud['account'] = account
            cloud['bucket'] = bucket
            atomic_json(args.config, config)
            print('Cloud configured. No bucket created and no files uploaded.')
        elif args.command == 'cleanup-approved-2024':
            # Exactly these two standalone recovery points were approved in
            # this session. Never delete the incremental repository.
            import shutil
            profile = config['profiles']['local']
            validate_mount(profile, writable=True)
            drive = Path(profile['mount'])
            preserved = drive / 'backupincr'
            if not (preserved / 'duplicity-full.20260118T151851Z.manifest').is_file():
                raise BackupError('January 2026 recovery point is missing; cleanup refused')
            for name, stamp in [('backup221024', '20241022T083750Z'),
                                ('backup031124', '20241103T130005Z')]:
                folder = drive / name
                if not folder.exists():
                    continue
                if folder.is_symlink() or not folder.is_dir():
                    raise BackupError('Unexpected old-backup path; cleanup refused')
                import re
                entries = list(folder.iterdir())
                prefix = re.escape(stamp)
                known = re.compile(r'duplicity-full\.' + prefix + r'\.(?:manifest(?:\.gpg)?|vol[0-9]+\.difftar\.(?:gz|gpg))|duplicity-full-signatures\.' + prefix + r'\.sigtar\.(?:gz|gpg)')
                if not entries or any(e.is_symlink() or not e.is_file() or not known.fullmatch(e.name) for e in entries):
                    raise BackupError(f'Unexpected contents in {name}; cleanup refused')
                if not any('.vol1.difftar.' in e.name for e in entries):
                    raise BackupError(f'Expected {name} volume missing; cleanup refused')
                shutil.rmtree(folder)
                print(f'Removed approved old full backup: {name}')
        elif args.command == 'init':
            print(runner.restic(args.target, ['init'], writable=True))
        elif args.command == 'backup':
            try:
                runner.backup(args.target)
            except Exception as error:
                atomic_json(args.state / (args.target + '-error.json'),
                            {'time': time.time(), 'error': str(error)})
                raise
            (args.state / (args.target + '-error.json')).unlink(missing_ok=True)
        elif args.command == 'estimate':
            runner.estimate(args.target)
        elif args.command == 'check':
            option = '--read-data' if args.full else '--read-data-subset=5%'
            print(runner.restic(args.target, ['check', option]))
        elif args.command == 'restore-test':
            runner.restore_test(args.target)
            print('Restore probe passed')
        elif args.command == 'retention':
            runner.retention(args.target, args.apply)
        elif args.command == 'status':
            for target in ['local', 'cloud']:
                file = args.state / (target + '-status.json')
                if not file.exists():
                    print(f'{target}: NO successful verified backup recorded')
                else:
                    value = json.loads(file.read_text())
                    age = (time.time() - value['last_success']) / 3600
                    print(f'{target}: last verified backup {age:.1f} hours ago, snapshot {value["snapshot"]}')
                    if age > MAX_AGE_HOURS[target]:
                        print(f'{target}: WARNING backup is overdue')
                    if value.get('skipped_files'):
                        print(f'{target}: {value["skipped_files"]} unreadable files skipped; '
                              f'see {args.state / (target + "-skipped.txt")}')
                error_file = args.state / (target + '-error.json')
                if error_file.exists():
                    print(f'{target}: most recent attempt failed: {json.loads(error_file.read_text())["error"]}')


if __name__ == '__main__':
    try:
        main()
    except (BackupError, OSError, ValueError) as error:
        print(f'Backup failed: {error}', file=sys.stderr)
        sys.exit(1)
