#!/usr/bin/env python3
"""Private Tailscale review server with a read-only, sanitized backup status endpoint."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parent / 'review'
STATE = Path('/home/mateo/.local/state/server-backup')

def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}

def status():
    result = {'time': time.time(), 'targets': {}}
    for target in ['cloud', 'local']:
        unit = subprocess.run(['systemctl', '--user', 'show', f'server-backup@{target}.service',
                               '-p', 'ActiveState', '-p', 'SubState', '-p', 'Result'],
                              capture_output=True, text=True, timeout=5)
        fields = dict(line.split('=', 1) for line in unit.stdout.splitlines() if '=' in line)
        paused = False
        entry = {'service': fields, 'paused_for_review': paused}
        verified = read_json(STATE / (target + '-status.json'))
        if verified:
            entry.update(last_success=verified.get('last_success'),
                         restore_test=verified.get('restore_test'), snapshot=verified.get('snapshot'))
        failure = read_json(STATE / (target + '-error.json'))
        if failure and not paused and entry['service'].get('ActiveState') == 'failed':
            entry['error'] = failure.get('error', 'Backup failed')
        progress = STATE / (target + '-backup.jsonl')
        if progress.exists():
            with progress.open('rb') as file:
                file.seek(max(0, progress.stat().st_size - 65536))
                lines = file.read().decode(errors='replace').splitlines()
            for line in reversed(lines):
                try:
                    parsed = json.loads(line)
                except ValueError:
                    continue
                if parsed.get('message_type') in ['status', 'summary']:
                    allowed = ['message_type', 'seconds_elapsed', 'seconds_remaining', 'percent_done',
                               'total_files', 'files_done', 'total_bytes', 'bytes_done', 'data_added',
                               'data_added_packed', 'total_bytes_processed', 'snapshot_id']
                    entry['progress'] = {k: parsed[k] for k in allowed if k in parsed}
                    entry['progress_time'] = progress.stat().st_mtime
                    break
        result['targets'][target] = entry
    return result

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)
    def do_GET(self):
        if self.path.split('?', 1)[0] == '/backup-status.json':
            body = json.dumps(status()).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

if __name__ == '__main__':
    ThreadingHTTPServer(('100.83.166.6', 8766), Handler).serve_forever()
