import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from policy import BackupError, selection_plan, validate_mount, is_excluded
from runner import Runner


class SafetyTests(unittest.TestCase):
    def test_explicit_model_cache_and_nested_model_selection(self):
        config = {'selections': [
            {'kind': 'files', 'path': '/work', 'choice': 'both'},
            {'kind': 'files', 'path': '/work/models', 'choice': 'local'},
            {'kind': 'files', 'path': '/user/.cache/huggingface', 'choice': 'local'}],
            'exclude_patterns': ['.cache', 'node_modules'], 'protected_paths': []}
        roots, excluded = selection_plan(config, 'local')
        self.assertEqual(roots, ['/work', '/user/.cache/huggingface'])
        self.assertFalse(is_excluded('/user/.cache/huggingface/hub/model', roots, excluded))
        self.assertTrue(is_excluded('/work/task/.cache/file', roots, excluded))
        roots, excluded = selection_plan(config, 'cloud')
        self.assertTrue(is_excluded('/work/models/checkpoint.pt', roots, excluded))

    def test_pending_and_local_only_subdirectories_are_not_in_cloud(self):
        config = {'selections': [
            {'kind': 'files', 'path': '/work', 'choice': 'both'},
            {'kind': 'files', 'path': '/work/pending', 'choice': 'pending'},
            {'kind': 'files', 'path': '/work/local', 'choice': 'local'}],
            'exclude_patterns': [], 'protected_paths': ['/work/key']}
        roots, excluded = selection_plan(config, 'cloud')
        self.assertEqual(roots, ['/work'])
        self.assertEqual(set(excluded), {'/work/pending', '/work/local', '/work/key'})

    def test_wrong_or_readonly_drive_rejected(self):
        profile = {'mount': '/mnt/backup', 'uuid': 'expected',
                   'repository': '/mnt/backup/restic', 'minimum_free_gib': 1}
        def mount(uuid, options):
            return SimpleNamespace(returncode=0, stdout=json.dumps({'filesystems': [
                {'uuid': uuid, 'options': options}]}))
        with patch('policy.subprocess.run', return_value=mount('other', 'rw')):
            with self.assertRaisesRegex(BackupError, 'Wrong drive'):
                validate_mount(profile, True)
        with patch('policy.subprocess.run', return_value=mount('expected', 'ro')):
            with self.assertRaisesRegex(BackupError, 'read-only'):
                validate_mount(profile, True)
        with patch('policy.subprocess.run', return_value=SimpleNamespace(returncode=1)):
            with self.assertRaisesRegex(BackupError, 'not mounted'):
                validate_mount(profile, True)

    def test_restic_partial_backup_returns_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            key = root / 'key'
            key.write_text('test-key')
            key.chmod(0o600)
            config = {'profiles': {'local': {'repository': str(root/'repo')}},
                      'password_file': str(key), 'restic_binary': 'restic'}
            runner = Runner(config, root/'state')
            with patch('runner.validate_mount'), patch('runner.subprocess.run',
                 return_value=SimpleNamespace(returncode=3, stdout='', stderr='unreadable source')):
                runner.restic('local', ['backup'])
                with self.assertRaisesRegex(BackupError, 'exit 3'):
                    runner.restic('local', ['check'])


class RecoveryTest(unittest.TestCase):
    def test_encrypted_backup_recovers_git_env_and_consistent_sqlite(self):
        with tempfile.TemporaryDirectory(prefix='server-backup-test-') as temp:
            root = Path(temp)
            source = root/'work'
            source.mkdir()
            (source/'.git').mkdir()
            (source/'.git/HEAD').write_text('ref: refs/heads/main\n')
            (source/'.env').write_text('FIXTURE_ONLY=yes\n')
            (source/'pending').mkdir()
            (source/'pending/private').write_text('excluded')
            (source/'node_modules').mkdir()
            (source/'node_modules/cache').write_text('excluded')
            (source/'.cache').mkdir()
            (source/'.cache/build').write_text('excluded cache')
            (source/'locked').write_text('unreadable')
            (source/'locked').chmod(0)
            models = root/'.cache/huggingface'
            models.mkdir(parents=True)
            (models/'model.bin').write_text('fixture model')
            database = source/'app.sqlite'
            with sqlite3.connect(database) as connection:
                connection.execute('create table important(value text)')
                connection.execute("insert into important values ('recover me')")
            key = root/'key'
            key.write_text('disposable-integration-test-key\n')
            key.chmod(0o600)
            config = {'host': 'backup-test', 'restic_binary': '/home/mateo/.local/bin/restic',
                      'password_file': str(key), 'recovery_key_saved': True,
                      'data_uuid': 'unused', 'exclude_patterns': ['node_modules', '.cache'],
                      'protected_paths': [], 'selections': [
                        {'id':'work','kind':'files','path':str(source),'choice':'both'},
                        {'id':'models','kind':'files','path':str(models),'choice':'local'},
                        {'id':'pending','kind':'files','path':str(source/'pending'),'choice':'pending'}],
                      'profiles': {'local': {'repository': str(root/'repo')}},
                      'retention': {'daily':14,'weekly':8,'monthly':12}}
            runner = Runner(config, root/'state')
            with patch('runner.validate_mount'), patch.object(runner, 'docker_inventory', return_value=[]):
                runner.restic('local', ['init'], writable=True)
                runner.backup('local')
                self.assertTrue((root/'state/local-status.json').is_file())
                self.assertFalse((root/'state/staging/local').exists())
                self.assertIn(str(source/'locked'), (root/'state/local-skipped.txt').read_text())
                restore = root/'restored'
                runner.restic('local', ['restore','latest','--target',str(restore)])
                restored_source = restore/str(source).lstrip('/')
                self.assertEqual((restored_source/'.env').read_text(), 'FIXTURE_ONLY=yes\n')
                self.assertTrue((restored_source/'.git/HEAD').is_file())
                self.assertFalse((restored_source/'pending').exists())
                self.assertFalse((restored_source/'node_modules').exists())
                self.assertFalse((restored_source/'.cache').exists())
                self.assertEqual((restore/str(models).lstrip('/')/'model.bin').read_text(),
                                 'fixture model')
                self.assertFalse((restored_source/'app.sqlite').exists())
                staging = restore/str(root/'state/staging/local').lstrip('/')
                manifest = json.loads((staging/'manifest.json').read_text())
                entry = next(x for x in manifest['exports'] if x.get('kind')=='sqlite')
                restored_db = restore/entry['file'].lstrip('/')
                with sqlite3.connect(restored_db) as connection:
                    self.assertEqual(connection.execute('select value from important').fetchone(), ('recover me',))
                with self.assertRaises(BackupError):
                    bad = Runner({**config, 'password_file': str(root/'wrongkey')}, root/'badstate')
                    (root/'wrongkey').write_text('wrong-key')
                    (root/'wrongkey').chmod(0o600)
                    bad.restic('local', ['snapshots'])

    def test_idle_sqlite_raw_and_new_path_report(self):
        with tempfile.TemporaryDirectory(prefix='server-backup-test-') as temp:
            root = Path(temp)
            source = root/'work'
            source.mkdir()
            idle = source/'idle.sqlite'
            with sqlite3.connect(idle) as connection:
                connection.execute('create table t(v text)')
                connection.execute("insert into t values ('raw copy')")
            old = time.time() - 3 * 3600
            os.utime(idle, (old, old))
            key = root/'key'
            key.write_text('disposable-integration-test-key\n')
            key.chmod(0o600)
            sent = []
            config = {'host': 'backup-test', 'restic_binary': '/home/mateo/.local/bin/restic',
                      'password_file': str(key), 'recovery_key_saved': True,
                      'data_uuid': 'unused', 'exclude_patterns': [], 'protected_paths': [],
                      'selections': [{'id':'work','kind':'files','path':str(source),'choice':'both'}],
                      'profiles': {'local': {'repository': str(root/'repo')}},
                      'retention': {'last': 10}, 'report_new_min_bytes': 1000}
            runner = Runner(config, root/'state')
            with patch('runner.validate_mount'), patch.object(runner, 'docker_inventory', return_value=[]), \
                 patch.object(runner, 'notify', side_effect=sent.append):
                runner.restic('local', ['init'], writable=True)
                runner.backup('local')
                status = json.loads((root/'state/local-status.json').read_text())
                self.assertEqual((status['raw_sqlite'], status['raw_sqlite_changed']), (1, []))
                restore = root/'restored'
                runner.restic('local', ['restore', 'latest', '--target', str(restore)])
                with sqlite3.connect(restore/str(idle).lstrip('/')) as connection:
                    self.assertEqual(connection.execute('select v from t').fetchone(), ('raw copy',))
                self.assertEqual(sent, [])
                (source/'new/deep').mkdir(parents=True)
                (source/'new/deep/blob').write_bytes(b'x' * 4000)
                (source/'small').write_bytes(b'x' * 10)
                runner.backup('local')
                self.assertEqual(len(sent), 1)
                self.assertIn(str(source/'new'), sent[0])
                self.assertNotIn(str(source/'small'), sent[0])

    def test_sqlite_scan_skip_leaves_databases_as_plain_files(self):
        with tempfile.TemporaryDirectory(prefix='server-backup-test-') as temp:
            root = Path(temp)
            source = root/'slow'
            source.mkdir()
            with sqlite3.connect(source/'app.sqlite') as connection:
                connection.execute('create table t(v text)')
            key = root/'key'
            key.write_text('disposable-integration-test-key\n')
            key.chmod(0o600)
            config = {'host': 'backup-test', 'restic_binary': '/home/mateo/.local/bin/restic',
                      'password_file': str(key), 'recovery_key_saved': True,
                      'data_uuid': 'unused', 'exclude_patterns': [], 'protected_paths': [],
                      'selections': [{'id':'slow','kind':'files','path':str(source),'choice':'both'}],
                      'profiles': {'local': {'repository': str(root/'repo')}},
                      'retention': {'last': 10}, 'sqlite_scan_skip': [str(source)]}
            runner = Runner(config, root/'state')
            with patch('runner.validate_mount'), patch.object(runner, 'docker_inventory', return_value=[]), \
                 patch.object(runner, 'notify'):
                runner.restic('local', ['init'], writable=True)
                runner.backup('local')
                restore = root/'restored'
                runner.restic('local', ['restore', 'latest', '--target', str(restore)])
                self.assertTrue((restore/str(source/'app.sqlite').lstrip('/')).is_file())
                self.assertEqual(json.loads((root/'state/local-status.json').read_text())['raw_sqlite'], 0)

    def test_pause_units_restarts_only_running_units(self):
        runner = Runner({'pause_user_units': ['a.timer', 'b.service']}, tempfile.mkdtemp())
        calls = []
        def run(command, **kwargs):
            calls.append(command[2:])
            return SimpleNamespace(returncode=0 if command[3:] in (['--quiet', 'a.timer'], ['a.timer']) else 3)
        with patch('runner.subprocess.run', side_effect=run):
            paused = []
            runner.pause_units(paused)
            runner.resume_units(paused)
        self.assertEqual(paused, ['a.timer'])
        self.assertIn(['stop', 'a.timer'], calls)
        self.assertNotIn(['stop', 'b.service'], calls)
        self.assertEqual(calls[-1], ['start', 'a.timer'])

    def test_auto_retention_forgets_superseded_snapshots(self):
        with tempfile.TemporaryDirectory(prefix='server-backup-test-') as temp:
            root = Path(temp)
            source = root/'work'
            source.mkdir()
            key = root/'key'
            key.write_text('disposable-integration-test-key\n')
            key.chmod(0o600)
            config = {'host': 'backup-test', 'restic_binary': '/home/mateo/.local/bin/restic',
                      'password_file': str(key), 'recovery_key_saved': True,
                      'data_uuid': 'unused', 'exclude_patterns': [], 'protected_paths': [],
                      'selections': [{'id':'work','kind':'files','path':str(source),'choice':'both'}],
                      'profiles': {'local': {'repository': str(root/'repo'), 'auto_retention': True}},
                      'retention': {'weekly':4,'monthly':6}}
            runner = Runner(config, root/'state')
            with patch('runner.validate_mount'), patch.object(runner, 'docker_inventory', return_value=[]):
                runner.restic('local', ['init'], writable=True)
                ids = []
                for content in ('first', 'second', 'third'):
                    (source/'file').write_text(content)
                    runner.backup('local')
                    ids.append(json.loads((root/'state/local-status.json').read_text())['snapshot'])
                snapshots = {s['id'] for s in json.loads(runner.restic('local', ['snapshots', '--json']))}
                # Same week: restic keeps the newest, plus the oldest while fewer weeks exist than requested.
                self.assertEqual(snapshots, {ids[0], ids[2]})
                # A per-target policy overrides the global one.
                config['profiles']['local']['retention'] = {'last': 1}
                runner.backup('local')
                newest = json.loads((root/'state/local-status.json').read_text())['snapshot']
                snapshots = {s['id'] for s in json.loads(runner.restic('local', ['snapshots', '--json']))}
                self.assertEqual(snapshots, {newest})


if __name__ == '__main__':
    unittest.main()
