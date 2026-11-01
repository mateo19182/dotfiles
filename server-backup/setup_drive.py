#!/usr/bin/env python3
"""Mount the existing Toshiba disk for backups and persist its mount. Never formats it."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

UUID = '173AB4E57E2E7036'
MOUNT = '/mnt/external_drive'
ENTRY = f'UUID={UUID} {MOUNT} ntfs-3g rw,uid=1000,gid=1000,umask=077,nofail,x-systemd.device-timeout=10s 0 0'
LEGACY_SOURCE = Path('/mnt/data/hmm/foxEngineV2/credshed-api/lib/credshed/scripts')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    print('Expected Toshiba filesystem:', UUID)
    print('Mount entry:', ENTRY)
    print('No backup folders are deleted by this setup command.')
    print('Also grants Mateo read access to the otherwise unreadable legacy source folder:', LEGACY_SOURCE)
    if args.dry_run:
        return
    if os.geteuid() != 0:
        raise SystemExit('Run this setup command with sudo from your interactive SSH terminal')
    device = f'/dev/disk/by-uuid/{UUID}'
    detected = subprocess.check_output(['blkid', '-s', 'UUID', '-o', 'value', device], text=True).strip()
    if detected != UUID:
        raise SystemExit('Drive identity mismatch; nothing changed')
    mounted = subprocess.run(['findmnt', '--json', '--mountpoint', MOUNT, '--output', 'UUID'],
                             capture_output=True, text=True)
    if mounted.returncode == 0 and json.loads(mounted.stdout)['filesystems'][0].get('uuid') != UUID:
        raise SystemExit('Another drive is mounted there; nothing changed')
    fstab = Path('/etc/fstab')
    original = fstab.read_text()
    lines = [line for line in original.splitlines() if line.strip() and not line.lstrip().startswith('#')]
    matching = [line for line in lines if UUID in line or line.split()[1] == MOUNT]
    if matching and matching != [ENTRY]:
        raise SystemExit('An existing fstab entry needs manual review; nothing changed')
    if mounted.returncode == 0:
        subprocess.run(['umount', MOUNT], check=True)
    backup = Path('/etc/fstab.pre-server-backup-' + time.strftime('%Y%m%d-%H%M%S'))
    if not matching:
        shutil.copy2(fstab, backup)
        with tempfile.NamedTemporaryFile(mode='w', dir='/etc', delete=False) as output:
            output.write(original.rstrip() + '\n\n# Toshiba server backup drive\n' + ENTRY + '\n')
            temporary = Path(output.name)
        temporary.chmod(0o644)
        temporary.replace(fstab)
    try:
        subprocess.run(['mount', MOUNT], check=True)
    except subprocess.CalledProcessError:
        if not matching:
            shutil.copy2(backup, fstab)
        subprocess.run(['mount', '-o', 'ro', device, MOUNT])
        raise SystemExit('Writable mount failed; restored previous fstab and attempted read-only mount')
    print('Toshiba mounted writable and configured to mount on future boots.')
    if LEGACY_SOURCE.exists():
        if LEGACY_SOURCE.is_symlink() or not LEGACY_SOURCE.is_dir():
            raise SystemExit('Unexpected legacy source path; access setup refused')
        subprocess.run(['setfacl', '-R', '-P', '-m', 'u:1000:rX', str(LEGACY_SOURCE)], check=True)
        print('Legacy source is readable by the backup user; ownership and contents preserved.')


if __name__ == '__main__':
    main()
