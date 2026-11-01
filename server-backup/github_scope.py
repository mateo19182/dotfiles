"""Exclude GitHub copies only while fresh remote checks prove them redundant."""
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
from urllib.parse import urlparse
from policy import is_excluded


def git(path, *args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_OPTIONAL_LOCKS='0')
    return subprocess.check_output(['git', '-C', str(path), *args],
                                   env=env, stderr=subprocess.DEVNULL, timeout=25)


def github_url(url):
    return url.startswith('git@github.com:') or urlparse(url).hostname == 'github.com'


def repository_exclusions(path, remote_reader=None, restore_record=None):
    """Any uncertainty retains the complete repository. Original untracked files stay."""
    path = Path(path)
    try:
        hashes = set()
        remote_locations = set()
        for remote in git(path, 'remote').decode().splitlines():
            url = git(path, 'remote', 'get-url', remote).decode().strip()
            if not github_url(url):
                continue
            location = url.split(':', 1)[1] if url.startswith('git@github.com:') else urlparse(url).path.lstrip('/')
            remote_locations.add('https://github.com/' + location.split('?', 1)[0])
            response = remote_reader(path, remote) if remote_reader else git(path, 'ls-remote', '--heads', '--tags', remote)
            hashes.update(line.split()[0] for line in response.decode().splitlines() if line.split())
        refs = [line.split(' ', 1) for line in git(path, 'for-each-ref', '--format=%(objectname) %(refname)', 'refs/heads', 'refs/tags').decode().splitlines()]
        head = git(path, 'rev-parse', 'HEAD').decode().strip()
        if not refs or not hashes:
            return [], 'kept: commits not verified on GitHub'
        tips = []
        for value in hashes:
            try:
                git(path, 'cat-file', '-e', value + '^{commit}')
                tips.append(value)
            except subprocess.SubprocessError:
                pass
        def recoverable(value):
            if value in hashes:
                return True
            # An unpublished annotated tag has unique metadata, so retain Git.
            if git(path, 'cat-file', '-t', value).strip() != b'commit':
                return False
            for tip in tips:
                try:
                    git(path, 'merge-base', '--is-ancestor', value, tip)
                    return True
                except subprocess.SubprocessError:
                    pass
            return False
        if not all(recoverable(value) for value in [head, *(row[0] for row in refs)]):
            return [], 'kept: commits not verified on GitHub'
        if git(path, 'stash', 'list').strip():
            return [], 'kept: local stash'
        exclusions = [str(path / '.git')]
        # Retain each locally changed file and all untracked/ignored originals.
        changed = set(os.fsdecode(name) for name in git(
            path, 'diff', '--name-only', '-z', '--ignore-submodules=none', 'HEAD').split(b'\0') if name)
        for raw in git(path, 'ls-files', '-z').split(b'\0'):
            if not raw:
                continue
            name = os.fsdecode(raw)
            if name in changed or (path / name).is_dir():
                continue
            if any(char in name for char in '*?[]\n\r\\'):
                continue
            exclusions.append(str(path / name))
        if restore_record is not None:
            restore_record.update({'github': sorted(remote_locations), 'head': head,
                                   'refs': {name: value for value, name in refs},
                                   'retained_changed_files': sorted(changed),
                                   'deleted_files': [os.fsdecode(name) for name in git(path, 'diff', '--name-only', '-z', '--diff-filter=D', '--no-renames', '--ignore-submodules=none', 'HEAD').split(b'\0') if name]})
        return exclusions, 'Git metadata and unchanged mirrored source; local changes retained'
    except (OSError, subprocess.SubprocessError, UnicodeError):
        return [], 'kept: remote verification unavailable'


def exclusions(config, roots, patterns):
    result, report = [], []
    preserved_models = [item['path'].rstrip('/') for item in config['selections']
                        if item['kind'] == 'files' and item['choice'] == 'local'
                        and (item['id'].startswith('model') or item['id'].startswith('own-tfg-checkpoint'))]
    candidates = [root for root in config.get('github_backup_candidates', [])
                  if any(Path(root).is_relative_to(Path(parent)) for parent in roots)
                  and not is_excluded(root, roots, patterns)]
    def check(root):
        restore = {}
        excluded, reason = repository_exclusions(root, restore_record=restore)
        excluded = [name for name in excluded if not any(name == model or name.startswith(model + '/') for model in preserved_models)]
        return excluded, {'path': root, 'decision': reason,
                          'excluded_paths': len(excluded), 'restore': restore}
    # Checks are read-only and disable optional Git locks; bound network
    # concurrency so remote timeouts don't delay every repository in series.
    with ThreadPoolExecutor(max_workers=4) as pool:
        for excluded, entry in pool.map(check, candidates):
            result.extend(excluded)
            report.append(entry)
    return result, report
