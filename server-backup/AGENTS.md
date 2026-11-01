# Server backup maintenance

Read README.txt and the live ~/.config/server-backup/config.json before changes.
This folder contains the backup implementation; it is not a Git repository.

- Preserve the user's explicit inclusion/exclusion preferences in README.txt and
  the detailed config. Ask about uncertain original work. Scope exclusion never
  authorizes source-file deletion.
- Keep cloud paused unless the user authorizes an upload. Local is currently
  authorized. Weekly local / monthly R2 schedules are intentional.
- Check running units first. Do not mutate config or restart a running backup;
  wait for the run to finish. CLI operations share run.lock.
- There is no approval gate; config edits apply to the next scheduled run.
  Verify selection_plan output, especially nested exclusions: excluded ancestors
  cannot be overridden by selected children in the current implementation.
- HTML drafts are review requests, not applied config. Check their scan baseline,
  resolve ancestor/child toggles and automatic exclusions before applying.
- Preserve published-source verification that fails closed by keeping uncertain
  repos, unpushed/changed/untracked work and own final checkpoints.
- Never print recovery keys, R2 credentials, SQL records, or container env values.
  Preserve private config/state permissions. Do not commit secrets.
- Do not delete old recovery points, prune valid snapshots, alter the legacy
  backupincr repository, or remove disk data without applicable user authorization.
- README.txt is the operating guide. Keep it current when behavior changes.
  build_tree.py is the current review inventory builder; review/build.py is legacy.
- For implementation changes run meaningful checks:
  python3 -m unittest discover -s /home/mateo/.local/share/server-backup -p 'test_*.py'
  Schedule-only edits need systemd-analyze calendar and daemon-reload, not code tests.
