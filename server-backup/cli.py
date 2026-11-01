#!/usr/bin/env python3
"""Server backup command. No upload starts until scope and keys are ready."""
import argparse
import fcntl
import getpass
import hashlib
import json
import os
from pathlib import Path
import secrets
import sys
import time

from policy import BackupError, atomic_json, is_excluded, selection_plan
from runner import Runner

CONFIG = Path('/home/mateo/.config/server-backup/config.json')
STATE = Path('/home/mateo/.local/state/server-backup')
# Weekly local and monthly cloud schedules, plus a day of slack.
MAX_AGE_HOURS = {'local': 8 * 24, 'cloud': 32 * 24}


def decide_path(args, config):
    path = os.path.abspath(args.path)
    if not os.path.lexists(path):
        raise BackupError(f'No such path: {path}')
    if os.path.islink(path):
        raise BackupError('Choose the actual data path rather than a symlink')
    item = next((i for i in config['selections'] if i.get('path') == path), None)
    if item is None:
        item = {'id': 'review-' + hashlib.sha1(path.encode()).hexdigest()[:10], 'kind': 'files',
                'path': path, 'description': 'Chosen in backup review ' + time.strftime('%Y-%m-%d')}
        config['selections'].append(item)
    item['choice'] = args.choice
    atomic_json(args.config, config)
    for target in ['local', 'cloud']:
        atomic_json(args.state / (target + '-held.json'), Runner(config, args.state).held(target))
    roots, excluded = selection_plan(config, 'cloud')
    if args.choice == 'both' and is_excluded(path, roots, excluded):
        print('Note: a parent folder is local only, so this stays on the local drive.')
    print(f'{path}: {args.choice} from the next run')


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
    commands.add_parser('held')
    choose = commands.add_parser('select')
    choose.add_argument('id')
    choose.add_argument('choice', choices=['local', 'cloud', 'both', 'skip', 'pending'])
    decide = commands.add_parser('decide', help='Record a choice for a path, e.g. one held back as new')
    decide.add_argument('path')
    decide.add_argument('choice', choices=['both', 'local', 'skip'])
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
    # Choices only edit the config for the next run, so they work while a backup holds the lock.
    if args.command == 'held':
        for target in ['local', 'cloud']:
            for item in Runner(config, args.state).held(target):
                print(f'{target:5}  {item["bytes"]/1024**3:6.1f} GiB  {item["path"]}')
        return
    if args.command == 'decide':
        decide_path(args, config)
        return
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
                held = Runner(config, args.state).held(target)
                if held:
                    print(f'{target}: {len(held)} new items held back until decided (server-backup held)')
                error_file = args.state / (target + '-error.json')
                if error_file.exists():
                    print(f'{target}: most recent attempt failed: {json.loads(error_file.read_text())["error"]}')


if __name__ == '__main__':
    try:
        main()
    except (BackupError, OSError, ValueError) as error:
        print(f'Backup failed: {error}', file=sys.stderr)
        sys.exit(1)
