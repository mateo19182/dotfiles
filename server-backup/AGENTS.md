# Server backup maintenance

Read README.md and the live ~/.config/server-backup/config.json before changes.
This folder is public (dotfiles); config, keys, state and file inventories stay out of it.

- Scope is opt-in. Preserve the user's choices in the config; ask before adding or
  dropping data that may exist nowhere else. Scope exclusion never authorizes
  source-file deletion.
- Weekly local / monthly R2 schedules are intentional.
- Check running units first. Do not mutate config or restart a running backup;
  wait for the run to finish (`decide` is the exception: it only affects the next run).
  Other CLI operations share run.lock.
- There is no approval gate; config edits apply to the next scheduled run.
  Verify selection_plan output, especially nested exclusions: excluded ancestors
  cannot be overridden by selected children in the current implementation.
- Never print recovery keys, R2 credentials, SQL records, or container env values.
  Preserve private config/state permissions (0600). Do not commit secrets.
- Do not delete old recovery points, prune valid snapshots, or remove disk data
  without applicable user authorization.
- README.md is the operating guide. Keep it current when behavior changes.
- For implementation changes run meaningful checks:
  python3 -m unittest discover -s ~/dotfiles/server-backup -p 'test_*.py'
  Schedule-only edits need systemd-analyze calendar and daemon-reload, not code tests.
