Server backup: operating guide
Updated 2026-10-03

Locations
  Command: /home/mateo/.local/bin/server-backup
  Implementation: /home/mateo/.local/share/server-backup/
  Source of truth: /home/mateo/.config/server-backup/config.json
  Private logs, status, export staging (deleted after each successful run): /home/mateo/.local/state/server-backup/
  Systemd units: /home/mateo/.config/systemd/user/server-backup*
  Local encrypted repository: /mnt/external_drive/restic-server
  Cloud: private R2 Standard bucket server-backup-m19182, prefix server-backup/
  Review: http://100.83.166.6:8766/
  Progress: http://100.83.166.6:8766/progress.html

How it works
cli.py provides commands. policy.py resolves selections and validates mounts.
runner.py exports service databases, verifies GitHub redundancy, and runs Restic.
github_scope.py excludes published Git contents only after fresh remote checks.
Restic repository version 2 compresses, encrypts and deduplicates file chunks.
Service dumps are plain .sql and Ghost content a plain .tar before Restic handles
compression. Each backup must complete and pass a small restore-probe test.
The probe is not a full service recovery test. Weekly checks read 5% of repo data.
An absent/wrong/read-only Toshiba drive fails instead of using the main disk.

Current policy
Keep original photos, exported artwork, misc and unique project work on both.
Other art, music, recordings, Syncthing vaults, downloaded audio collections,
retained own model checkpoints and old encrypted data archives are local-only.
Only Linkwarden and Ghost databases, plus Ghost content, are exported.
Exclude Desktop, backups, Work, Downloads, installers, public datasets,
reinstallable environments/dependencies, generated outputs, AI chat histories,
and known credentials including .env/auth/key files. Do not delete sources
when changing backup scope. The config defines the detailed exceptions.
Keep Ableton .asd files: they can contain original clip defaults/warp markers.
Keep own final checkpoints even when published. Keep unpushed commits, stashes,
local modifications, untracked/ignored originals, and unverifiable Git repos.
2026-10-22 cuts: skip typology-machine generated crops (multicategory,
store_sign), forocoches-lm runs/*/checkpoint-* and tg-monitor vec.db; keep
typology-machine/data and forocoches fc_dataset_7-8.sqlite local-only.
Also skip forocoches v2/final-bf16, graffiti-ai hf/uv caches, the quarantined
henad Next build, art/music/vst-installers and art/sounds/ytdl. Downloaded
sample packs, music-library and art/gente stay in scope by user choice.
Known-secret filters are not a guarantee that original files contain no secrets.
Raw Docker database directories are excluded. Active SQLite files (touched within
sqlite_idle_minutes, default 60, or with a pending WAL/journal) use online backup
copies (time limit 2 min + 90 s per GB); idle ones are backed up raw so restic
dedups unchanged files. A raw file that changes during the read is listed in
TARGET-status.json raw_sqlite_changed and exported on the next run. Unselected
service SQLite files are excluded. Units in pause_user_units (user systemd, e.g.
the forocoches crawler and its timers) are stopped while sources are read and
restarted afterwards only if they were running. After each snapshot, folders
added since the previous one that total over report_new_min_bytes (default
500 MiB) are printed and sent through notify_command (hermes Telegram). Root-owned files
may be unreadable; this is a user-level backup, not a bare-metal OS image.
Unreadable files do not fail a run: restic exit 3 still records the snapshot,
and the skipped paths are listed in ~/.local/state/server-backup/TARGET-skipped.txt
(server-backup status shows the count).

Schedules, Madrid server time
  Local: Sunday 03:00, up to 15 minutes randomized delay.
  Cloud: first day of each month 05:00, up to 15 minutes delay.
  Integrity check: every local backup ends with restic check on a 5% data
  sample. Cloud has no scheduled check; run server-backup check cloud by hand.
Timers activate for a target only after its first successful backup and restore
probe. status warns when local is older than 8 days or cloud older than 32.
User lingering lets jobs run while the laptop is disconnected.
Change OnCalendar in the corresponding timer, then systemctl --user daemon-reload.
Do not start or enable cloud scheduling merely because local succeeds.

Changing an existing selection
  server-backup plan
  server-backup select GROUP_ID both
Choices: both, local, cloud, skip, pending. pending and skip are omitted.
Example: server-backup select misc local
There is no approval step: the next scheduled run uses the new scope. To run now:
  systemctl --user start --no-block server-backup@local.service
These commands share a lock. While a backup runs, CLI commands fail with
'Another backup command is running'. Wait until it completes before scope edits.
Do not interrupt an active backup merely to change its next-run scope.

Adding a new folder
There is no CLI add command. An agent edits config.json's selections, preserving
all other entries and its 0600 permissions. A file selection has these fields:
  {"id":"my-original-work","kind":"files","path":"/absolute/real/path",
   "choice":"local","description":"Original work, local only"}
IDs must be unique. Use the actual target directory, not a symlink. If an included
parent already covers a folder, no additional entry is needed. To exclude a
nested folder, add a skip selection. Global exclude_patterns/protected_paths
still apply. A selected child cannot override an excluded ancestor with the
current resolver: split the scope into sibling roots or revise the ancestor
exclusion carefully; never assume more-specific selections win.
Changing a selection does not remove it from existing recovery points. Retention
or an explicitly reviewed snapshot rewrite is a separate operation.

HTML review workflow
The HTML shows measured disk/local/R2 sizes and stores draft changes in the
browser. Export changes JSON or Save HTML and send the file to an agent.
Neither button applies server changes. The agent checks baseline_hash against
the scan, interprets directory toggles and nested exceptions, applies authorized
config changes and validates selection_plan output.
Refresh the current nested inventory using:
  python3 /home/mateo/.local/share/server-backup/build_tree.py
This scans disk and checks GitHub; it does not upload. review/build.py is the
older flat inventory builder and is not the current tree's data source.
Some excluded directories are aggregated and some root-owned directories cannot
be fully measured. Review estimates are logical bytes before compression.
Actual cloud billing depends on compressed repository bytes and retained versions.

Status and manual checks
  systemctl --user status server-backup@local.service
  journalctl --user -u server-backup@local.service -n 20
  systemctl --user list-timers --all 'server-backup*'
  server-backup status
Use the progress page while a job holds the CLI lock. Status JSON records only
completed, restore-verified runs. local-backup.jsonl / cloud-backup.jsonl contain
progress. Private error files can contain file paths; do not publish their contents.

Retention and recovery
Retention: 4 weekly + 6 monthly recovery points (restic also keeps the oldest
while fewer periods exist). Local applies it automatically (forget --prune)
after each backup that passes its restore probe and check (profiles.local
auto_retention, set 2026-10-22 at user request). Cloud keeps only the latest
snapshot (profiles.cloud retention last=1, auto_retention); the previous one is
forgotten and pruned only after the new one passes its restore probe.
  server-backup retention TARGET
prints a dry run; --apply permanently removes recovery points and unused data.
Require explicit user authorization for retention beyond this policy or rewriting backups.
The legacy Duplicity repository (/mnt/external_drive/backupincr) was deleted on
2026-10-19 at user request; restic is the only backup.
The two approved standalone 2024 backups were already removed. The interrupted
R2 upload was pruned on 2026-10-03; only repository config/key metadata remained.

Save the recovery-key securely off-server. Never print/paste key or credential
values. Recovery requires this saved key and, for R2, bucket access credentials.
Restore into a NEW EMPTY directory, never onto a working database:
  restic -r REPOSITORY --password-file KEYFILE snapshots
  restic -r REPOSITORY --password-file KEYFILE restore SNAPSHOT --target EMPTY_DIR
For R2 set AWS credentials securely and use -o s3.region=auto. Read manifest.json
inside the saved staging directory to map SQL/SQLite/assets back to their services.
For Git repos whose published files were omitted, clone the recorded GitHub URL,
checkout recorded HEAD, overlay restored local files, remove recorded deleted_files,
and reconstruct recorded refs. Reinstall dependencies and redownload public data.
Test service restoration before directing real traffic to restored databases.

`sqlite_scan_skip` (list of paths): roots under these paths are not walked to find SQLite
databases; any database there is backed up as a plain file. Set to /mnt/data because walking
the slow Seagate took hours and it holds only one tiny database.
