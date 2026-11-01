"""Encrypted snapshots, database exports, and recovery verification."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import time

from policy import BackupError, atomic_json, is_excluded, selected, validate_mount, validate_sources

PROBE = b'server-backup restore verification v1\n'


def glob_escape(path):
    # Restic exclude patterns are globs; many real paths contain [ ] (e.g. "[87 bpm]").
    return ''.join('\\' + char if char in '*?[]\\' else char for char in path)


def size_label(size):
    return f'{size/1024**3:.1f} GiB' if size >= 1024**3 else f'{size/1024**2:.0f} MiB'


class Runner:
    def __init__(self, config, state):
        self.config = config
        self.state = Path(state)
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)

    def restic(self, target, args, writable=False):
        profile = self.config['profiles'][target]
        if target == 'local':
            validate_mount(profile, writable)
        if not profile.get('repository'):
            raise BackupError('Cloud repository is not configured')
        key = Path(self.config['password_file'])
        if not key.is_file() or key.stat().st_mode & 0o077:
            raise BackupError('Encryption key is missing or has unsafe permissions')
        env = os.environ.copy()
        for name in ['RESTIC_REPOSITORY', 'RESTIC_PASSWORD', 'RESTIC_PASSWORD_COMMAND',
                     'RESTIC_PASSWORD_FILE', 'RESTIC_REPOSITORY_FILE']:
            env.pop(name, None)
        extra = []
        if target == 'cloud':
            credentials = Path(profile['credentials_file'])
            if not credentials.is_file() or credentials.stat().st_mode & 0o077:
                raise BackupError('Cloud credential file missing or has unsafe permissions')
            env.update(json.loads(credentials.read_text()))
            extra = ['-o', 's3.region=auto']
        command = [self.config['restic_binary'], '-r', profile['repository'],
                   '--password-file', str(key), '--cache-dir', str(self.state / 'cache'),
                   *extra, *args]
        if args[0] == 'backup':
            progress = self.state / (target + '-backup.jsonl')
            env.setdefault('RESTIC_PROGRESS_FPS', '0.2')
            with progress.open('w') as output:
                progress.chmod(0o600)
                result = subprocess.run(command, env=env, stdout=output,
                                        stderr=subprocess.PIPE, text=True)
            stdout = progress.read_text()
            # Per-file read errors arrive as JSON lines on stderr.
            errors = self.state / (target + '-backup-errors.jsonl')
            errors.write_text(result.stderr)
            errors.chmod(0o600)
        else:
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            stdout = result.stdout
        if result.returncode:
            log = self.state / 'last-restic-error.log'
            log.write_text(result.stderr)
            log.chmod(0o600)
            # Restic exit 3 means the snapshot was written but some source
            # files could not be read. backup() records them as skipped.
            if result.returncode == 3 and args[0] == 'backup':
                return stdout
            raise BackupError(f'Restic {args[0]} failed with exit {result.returncode}; '
                              f'no successful backup recorded. Details: {log}')
        return stdout

    def docker_inventory(self):
        ids = subprocess.check_output(['docker', 'ps', '-q'], text=True).split()
        if not ids:
            return []
        data = json.loads(subprocess.check_output(['docker', 'inspect', *ids], text=True))
        # Keep only the metadata needed for backup coverage, never container env.
        return [{'name': c['Name'].lstrip('/'), 'image': c['Config']['Image'],
                 'mounts': c['Mounts']} for c in data]

    def sqlite_idle(self, source):
        # Idle = no pending WAL/journal and nothing touched within the window.
        window = self.config.get('sqlite_idle_minutes', 60) * 60
        for path in (source, Path(str(source)+'-wal'), Path(str(source)+'-journal')):
            try:
                info = path.stat()
            except FileNotFoundError:
                continue
            if path != source and info.st_size:
                return False
            if time.time() - info.st_mtime < window:
                return False
        return True

    def pause_units(self, paused):
        # Stop writers (e.g. a crawler) so their databases hold still; resume_units restarts them.
        for unit in self.config.get('pause_user_units', []):
            if subprocess.run(['systemctl', '--user', 'is-active', '--quiet', unit]).returncode == 0:
                print(f'pausing {unit} for the backup', flush=True)
                subprocess.run(['systemctl', '--user', 'stop', unit], check=True)
                paused.append(unit)

    def resume_units(self, paused):
        for unit in reversed(paused):
            if subprocess.run(['systemctl', '--user', 'start', unit]).returncode:
                print(f'warning: could not restart {unit}', flush=True)

    def new_items(self, target, previous, snapshot, roots):
        """What the snapshot added since the previous one, as {path: (bytes, files)}: each new
        folder as a whole (never above a selected root), or a new file in a folder already backed up."""
        added = set()
        for line in self.restic(target, ['diff', '--json', previous, snapshot]).splitlines():
            if line.startswith('{'):
                change = json.loads(line)
                if change.get('message_type') == 'change' and change.get('modifier') == '+':
                    added.add(change['path'])
        items = {}
        for path in added:
            if path.endswith('/') or path.startswith(str(self.state) + '/'):
                continue
            item, parent = path, os.path.dirname(path)
            while parent + '/' in added and not any(
                    root != parent and Path(root).is_relative_to(parent) for root in roots):
                item, parent = parent, os.path.dirname(parent)
            try:
                size = os.lstat(path).st_size
            except OSError:
                continue
            total, count = items.get(item, (0, 0))
            items[item] = (total + size, count + 1)
        return items

    def held(self, target):
        """Items held back by earlier runs that still wait for a choice."""
        try:
            items = json.loads((self.state / (target + '-held.json')).read_text())
        except (OSError, ValueError):
            return []
        decided = {i['path'] for i in self.config['selections'] if i['kind'] == 'files'}
        return [i for i in items if i['path'] not in decided and os.path.lexists(i['path'])]

    def drop_from_snapshot(self, target, snapshot, paths):
        """Rewrite the snapshot without paths; returns the new snapshot ID."""
        exclude_file = self.state / (target + '-held-exclude.txt')
        exclude_file.write_text(''.join(glob_escape(path) + '\n' for path in paths))
        self.restic(target, ['rewrite', '--forget', '--exclude-file', str(exclude_file), snapshot], writable=True)
        for candidate in json.loads(self.restic(target, ['snapshots', '--json'])):
            if candidate.get('original') == snapshot:
                return candidate['id']
        raise BackupError('Rewritten snapshot not found')

    def notify(self, message):
        command = self.config.get('notify_command')
        if command:
            try:
                subprocess.run([*command, message], timeout=60, capture_output=True)
            except (OSError, subprocess.SubprocessError) as error:
                print(f'warning: notification failed: {error}', flush=True)

    def prepare(self, target):
        roots, excluded, missing = validate_sources(self.config, target)
        self.raw_sqlite = {}
        staging = self.state / 'staging' / target
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True, mode=0o700)
        inventory = self.docker_inventory()
        by_name = {c['name']: c for c in inventory}
        database_paths = []
        known_db_destinations = ['/var/lib/postgresql', '/var/lib/mysql', '/data/db']
        for container in inventory:
            for mount in container['mounts']:
                if any(mount['Destination'].startswith(d) for d in known_db_destinations):
                    database_paths.append(mount['Source'])
        excluded.extend(database_paths)
        # Items waiting for a choice stay out until one is recorded.
        excluded.extend(glob_escape(item['path']) for item in self.held(target))
        if missing:
            message = (f'{target} backup: selected paths are missing (moved or deleted?) and were skipped:\n'
                       + '\n'.join(missing))
            print(message, flush=True)
            self.notify(message)
        manifest = {'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                    'target': target, 'config': self.config,
                    'containers': inventory, 'exports': []}
        for item in self.config['selections']:
            if not selected(item, target) or item['kind'] == 'files':
                continue
            name = item['container']
            if name not in by_name:
                raise BackupError(f'Selected service container is not running: {name}')
            if item['kind'] == 'postgres':
                script = 'export PGPASSWORD="${POSTGRES_PASSWORD:-}"; exec pg_dumpall -U "${POSTGRES_USER:-postgres}"'
                command = ['docker', 'exec', name, 'sh', '-c', script]
                destination = staging / (item['id'] + '.sql')
            elif item['kind'] == 'mysql':
                script = ('export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}"; '
                          'exec mysqldump -uroot --all-databases --single-transaction '
                          '--routines --events --triggers --hex-blob')
                command = ['docker', 'exec', name, 'sh', '-c', script]
                destination = staging / (item['id'] + '.sql')
            elif item['kind'] == 'assets':
                mounts = by_name[name]['mounts']
                if not any(m['Destination'] == item['destination'] and
                           m.get('Name') == item['volume'] for m in mounts):
                    raise BackupError(f'Volume identity changed for {item["id"]}')
                command = ['docker', 'exec', name, 'tar', '-C', item['destination'], '-cf', '-', '.']
                destination = staging / (item['id'] + '.tar')
            else:
                raise BackupError(f'Unsupported service backup kind: {item["kind"]}')
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            try:
                # Restic handles compression after chunking, so unchanged
                # database/content blocks can be reused across snapshots.
                with destination.open('wb') as output:
                    destination.chmod(0o600)
                    shutil.copyfileobj(process.stdout, output)
                process.stdout.close()
                if process.wait() != 0:
                    raise BackupError(f'Database/asset export failed for {item["id"]}')
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
            manifest['exports'].append({'id': item['id'], 'file': str(destination)})
        # Export SQLite databases through SQLite's online backup API. Raw files
        # and WAL/SHM sidecars are excluded from the file snapshot.
        # Walking a slow disk just to find databases costs hours; DBs there go in as plain files.
        no_scan = [Path(p) for p in self.config.get('sqlite_scan_skip', [])]
        for root in roots:
            paths = []
            if any(Path(root).is_relative_to(p) for p in no_scan):
                continue
            if Path(root).is_dir():
                for base, dirs, files in os.walk(root):
                    dirs[:] = [d for d in dirs if not is_excluded(Path(base)/d, roots, excluded)]
                    paths.extend(Path(base)/f for f in files if f.endswith(('.sqlite', '.sqlite3', '.db')))
            elif root.endswith(('.sqlite', '.sqlite3', '.db')):
                paths.append(Path(root))
            for source in paths:
                if is_excluded(source, roots, excluded) or source.is_symlink():
                    continue
                try:
                    with source.open('rb') as f:
                        if f.read(16) != b'SQLite format 3\x00':
                            continue
                    if (self.config.get('sqlite_service_policy') == 'skip' and
                        source.is_relative_to(Path('/home/mateo/projects/services'))):
                        excluded.extend([str(source), str(source)+'-wal', str(source)+'-shm', str(source)+'-journal'])
                        manifest.setdefault('excluded_service_sqlite', []).append(str(source))
                        continue
                    # Idle databases go in as raw files: restic stores an unchanged file
                    # for free, while an export re-copies it on every run.
                    if self.sqlite_idle(source):
                        excluded.extend([str(source)+'-shm'])
                        self.raw_sqlite[str(source)] = source.stat().st_mtime_ns
                        manifest['exports'].append({'source': str(source), 'kind': 'sqlite-raw'})
                        continue
                    destination = staging / ('sqlite-' + hashlib.sha256(str(source).encode()).hexdigest()[:20] + '.sqlite')
                    with sqlite3.connect(source.as_uri() + '?mode=ro', uri=True) as original:
                        with sqlite3.connect(destination) as copied:
                            # 2 min plus 90 s per GB: large databases (tg-monitor's vec.db, 18 GB) need minutes, not a flat 2 min
                            deadline = time.monotonic() + 120 + 90 * source.stat().st_size / 1e9
                            def progress(status, remaining, total):
                                if time.monotonic() > deadline:
                                    raise BackupError(f'SQLite export timed out: {source}')
                            original.backup(copied, pages=256, progress=progress)
                            if copied.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
                                raise BackupError(f'SQLite integrity check failed: {source}')
                    excluded.extend([str(source), str(source)+'-wal', str(source)+'-shm', str(source)+'-journal'])
                    manifest['exports'].append({'source': str(source), 'file': str(destination), 'kind': 'sqlite'})
                except (OSError, sqlite3.Error) as error:
                    raise BackupError(f'Cannot safely export SQLite database: {source}') from error
        from github_scope import exclusions as github_exclusions
        print(f'{target}: verifying mirrored GitHub source', flush=True)
        redundant, git_report = github_exclusions(self.config, roots, excluded)
        excluded.extend(redundant)
        manifest['github_scope'] = git_report
        (staging / 'restore-probe.txt').write_bytes(PROBE)
        atomic_json(staging / 'manifest.json', manifest)
        return roots, excluded, staging

    def backup(self, target):
        if not self.config['recovery_key_saved']:
            raise BackupError('Save the recovery key off this server before the first real backup')
        # Preflight the repository and drive before reading service data.
        print(f'{target}: checking repository and exporting selected databases', flush=True)
        existing = json.loads(self.restic(target, ['snapshots', '--json'], writable=True) or '[]')
        previous = max((s for s in existing if {'server-backup', target} <= set(s.get('tags') or [])
                        and s.get('hostname') == self.config['host']),
                       key=lambda s: s['time'], default={}).get('id')
        paused = []
        try:
            self.pause_units(paused)
            roots, excluded, staging = self.prepare(target)
            arguments = ['backup', '--json', '--host', self.config['host'],
                         '--tag', 'server-backup', '--tag', target,
                         '--group-by', 'host,tags']
            exclude_file = self.state / (target + '-exclude.txt')
            exclude_file.write_text('\n'.join(excluded) + '\n')
            exclude_file.chmod(0o600)
            arguments.extend(['--exclude-file', str(exclude_file)])
            arguments.extend([*roots, str(staging)])
            print(f'{target}: starting encrypted backup; progress in {self.state / (target + "-backup.jsonl")}', flush=True)
            output = self.restic(target, arguments, writable=True)
        finally:
            self.resume_units(paused)
        # A raw database written during the read may be torn; next run exports it instead.
        changed_raw = [path for path, mtime in self.raw_sqlite.items()
                       if not Path(path).exists() or Path(path).stat().st_mtime_ns != mtime]
        messages = [json.loads(line) for line in output.splitlines() if line.startswith('{')]
        summary = next((m for m in reversed(messages) if m.get('message_type') == 'summary'), None)
        if not summary or not summary.get('snapshot_id'):
            raise BackupError('Restic did not report a completed snapshot')
        snapshot = summary['snapshot_id']
        errors = (self.state / (target + '-backup-errors.jsonl')).read_text().splitlines()
        errors = [json.loads(line) for line in errors if line.startswith('{')]
        skipped = sorted({m['item'] for m in errors
                          if m.get('message_type') == 'error' and m.get('item')})
        skipped_file = self.state / (target + '-skipped.txt')
        skipped_file.write_text(''.join(path + '\n' for path in skipped))
        skipped_file.chmod(0o600)
        held = self.held(target)
        items = {}
        if previous:
            try:
                items = self.new_items(target, previous, snapshot, roots)
            except (BackupError, OSError, ValueError) as error:
                print(f'{target}: warning: new-item check failed: {error}', flush=True)
        decided = {i['path'] for i in self.config['selections'] if i['kind'] == 'files'}
        minimum = self.config.get('review_new_min_bytes', 1024**3)
        # Folders whose new contents always go in, e.g. the music library.
        always = self.config.get('review_auto_include', [])
        new_held = [{'path': path, 'bytes': size, 'files': count}
                    for path, (size, count) in sorted(items.items(), key=lambda kv: -kv[1][0])
                    if size >= minimum and path not in decided
                    and not any(Path(path).is_relative_to(folder) for folder in always)]
        if new_held:
            print(f'{target}: holding back {len(new_held)} new items until a choice is recorded', flush=True)
            snapshot = self.drop_from_snapshot(target, snapshot, [item['path'] for item in new_held])
        atomic_json(self.state / (target + '-held.json'), held + new_held)
        self.restore_test(target, snapshot)
        if target == 'local':
            print(f'{target}: checking repository and a 5% data sample', flush=True)
            self.restic(target, ['check', '--read-data-subset=5%'])
        status = {'last_success': time.time(), 'snapshot': snapshot,
                  'restore_test': 'passed', 'check': 'passed' if target == 'local' else None,
                  'skipped_files': len(skipped), 'summary': summary,
                  'raw_sqlite': len(self.raw_sqlite), 'raw_sqlite_changed': changed_raw,
                  'held': len(held) + len(new_held)}
        atomic_json(self.state / (target + '-status.json'), status)
        # The snapshot holds the exports now; prepare() rebuilds staging from scratch next run.
        shutil.rmtree(staging)
        print(f'{target}: snapshot {snapshot} completed and restore probe passed')
        if skipped:
            print(f'{target}: {len(skipped)} unreadable files were skipped; list in {skipped_file}')
        alerts = []
        if changed_raw:
            alerts.append('SQLite files changed while being read (exported next run):\n' + '\n'.join(changed_raw))
        if new_held:
            alerts.append('New, NOT backed up until you choose:\n' +
                          '\n'.join(f'{n}. {size_label(item["bytes"])}  {item["path"]}  ({item["files"]:,} files)'
                                    for n, item in enumerate(new_held, 1)) +
                          '\nReply per item: both (drive + R2), local (drive only) or skip.')
        if held:
            alerts.append(f'Still waiting for a choice: {len(held)} items (server-backup held)')
        reported = self.config.get('report_new_min_bytes', 500 * 1024**2)
        big = [(size, path) for path, (size, _) in items.items()
               if reported <= size and not any(path == item['path'] for item in new_held)]
        if big:
            alerts.append('New paths since the previous snapshot:\n' +
                          '\n'.join(f'{size_label(size)}  {path}' for size, path in sorted(big, reverse=True)[:15]))
        if alerts:
            message = f'{target} backup {snapshot[:8]}\n' + '\n\n'.join(alerts)
            print(message, flush=True)
            self.notify(message)
        if self.config['profiles'][target].get('auto_retention'):
            print(f'{target}: applying retention policy', flush=True)
            self.retention(target, apply=True)

    def estimate(self, target):
        roots, excluded, missing = validate_sources(self.config, target)
        if missing:
            print('Missing selected paths (skipped):', *missing, sep='\n  ')
        total = count = 0
        errors = []
        def problem(error):
            errors.append(error.filename)
        for root in roots:
            if not Path(root).is_dir():
                total += Path(root).stat().st_size
                count += 1
                continue
            for base, dirs, files in os.walk(root, onerror=problem):
                dirs[:] = [d for d in dirs if not is_excluded(Path(base)/d, roots, excluded)]
                for name in files:
                    path = Path(base) / name
                    if path.is_symlink() or is_excluded(path, roots, excluded):
                        continue
                    try:
                        total += path.stat().st_size
                        count += 1
                    except OSError:
                        errors.append(str(path))
        print(f'{target}: {count:,} files, {total/1024**3:.1f} GiB logical size before compression/deduplication')
        if target == 'cloud':
            print(f'R2 Standard baseline estimate: ${total/1e9*0.015:.2f}/month before versions, free allowance, operations and tax')
        if errors:
            print('Unreadable sources need resolution before backup:')
            print('\n'.join(sorted(set(errors))))
        return total, errors

    def restore_test(self, target, snapshot='latest'):
        probe = self.state / 'staging' / target / 'restore-probe.txt'
        with tempfile.TemporaryDirectory(prefix='server-backup-restore-', dir=self.state) as temp:
            self.restic(target, ['restore', snapshot, '--host', self.config['host'],
                                 '--tag', 'server-backup', '--tag', target,
                                 '--include', str(probe), '--target', temp])
            restored = Path(temp) / str(probe).lstrip('/')
            if not restored.is_file() or restored.read_bytes() != PROBE:
                raise BackupError('Restore verification failed')

    def retention(self, target, apply=False):
        status_file = self.state / (target + '-status.json')
        if apply and not status_file.exists():
            raise BackupError('A verified successful backup is required before retention deletes snapshots')
        args = ['forget', '--host', self.config['host'], '--tag', 'server-backup',
                '--tag', target, '--group-by', 'host,tags']
        policy = self.config['profiles'][target].get('retention', self.config['retention'])
        for period, count in policy.items():
            args.extend(['--keep-' + period, str(count)])
        args.append('--prune' if apply else '--dry-run')
        print(self.restic(target, args, writable=apply))
