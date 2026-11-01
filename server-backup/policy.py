"""Explicit backup selections and destination checks."""
import fnmatch
import json
import os
from pathlib import Path
import subprocess


class BackupError(Exception):
    pass


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_suffix('.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as f:
        json.dump(value, f, indent=2)
        f.write('\n')
    tmp.replace(path)


def selected(item, target):
    return item['choice'] in (target, 'both')


def selection_plan(config, target):
    items = config['selections']
    roots = []
    excluded = list(config['exclude_patterns'])
    for item in items:
        if item['kind'] != 'files':
            continue
        if selected(item, target):
            roots.append(item['path'])
        else:
            excluded.append(item['path'])
    for path in config['protected_paths']:
        excluded.append(path)
    roots = list(dict.fromkeys(roots))
    # A nested selected path is already covered by its selected parent.
    roots = [root for root in roots if not any(
        root != parent and Path(root).is_relative_to(Path(parent)) for parent in roots)]
    # Explicit model-cache roots must be included locally. Keep excluding
    # unrelated .cache directories under the other selected roots.
    if any('.cache' in Path(root).parts for root in roots) and '.cache' in excluded:
        excluded.remove('.cache')
        for root in roots:
            if '.cache' not in Path(root).parts:
                excluded.extend([root.rstrip('/') + '/.cache',
                                 root.rstrip('/') + '/**/.cache'])
    return roots, list(dict.fromkeys(excluded))


def is_excluded(path, roots, patterns):
    """Match our documented component exclusions and absolute subtrees."""
    path = Path(path)
    for pattern in patterns:
        if pattern.startswith('/'):
            if any(char in pattern for char in '*?['):
                if pattern.endswith('/.cache') and '.cache' not in path.parts:
                    continue
                prefix = pattern.split('*', 1)[0].split('?', 1)[0].split('[', 1)[0]
                if not str(path).startswith(prefix):
                    continue
                if any(fnmatch.fnmatchcase(str(parent), pattern)
                       for parent in (path, *path.parents)):
                    return True
                continue
            base = pattern.rstrip('/')
            if str(path) == base or str(path).startswith(base + '/'):
                return True
        elif any(fnmatch.fnmatchcase(part, pattern) for part in path.parts):
            return True
    return False


def validate_mount(profile, writable):
    mount = profile['mount']
    result = subprocess.run(['findmnt', '--json', '--mountpoint', mount,
                             '--output', 'TARGET,SOURCE,UUID,OPTIONS'],
                            capture_output=True, text=True)
    if result.returncode:
        raise BackupError(f'Backup drive is not mounted at {mount}')
    record = json.loads(result.stdout)['filesystems'][0]
    if record.get('uuid', '').lower() != profile['uuid'].lower():
        raise BackupError('Wrong drive mounted at the backup destination')
    options = record['options'].split(',')
    if writable and 'ro' in options:
        raise BackupError('Backup drive is mounted read-only')
    repo = Path(profile['repository'])
    if repo.is_symlink() or not repo.resolve().is_relative_to(Path(mount).resolve()):
        raise BackupError('Repository must stay inside the expected backup drive')
    if writable:
        free = os.statvfs(mount).f_bavail * os.statvfs(mount).f_frsize
        if free < profile['minimum_free_gib'] * 1024**3:
            raise BackupError('Backup drive is below the configured free-space reserve')


def validate_sources(config, target):
    """Return (roots, excluded, missing). A moved or deleted selection is skipped and reported
    rather than failing the run; an unmounted data drive still fails it."""
    roots, excluded = selection_plan(config, target)
    # Check the drive before dropping missing roots: an unmounted drive would otherwise look like
    # moved folders and produce a partial snapshot that cloud retention keeps as the only copy.
    if any(Path(root).is_relative_to(Path('/mnt/data')) for root in roots):
        result = subprocess.run(['findmnt', '--json', '--mountpoint', '/mnt/data',
                                 '--output', 'UUID'], capture_output=True, text=True)
        if result.returncode or json.loads(result.stdout)['filesystems'][0].get('uuid') != config['data_uuid']:
            raise BackupError('/mnt/data is missing or contains the wrong drive')
    missing = [root for root in roots if not Path(root).exists() or not os.access(root, os.R_OK)]
    roots = [root for root in roots if root not in missing]
    if not roots:
        raise BackupError('No selected source exists for this destination')
    for root in roots:
        if Path(root).is_symlink():
            raise BackupError(f'Select the actual data path rather than a symlink: {root}')
    return roots, excluded, missing
