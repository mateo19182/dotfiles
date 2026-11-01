---
name: server-backup
description: "Use when Mateo replies to a backup message about new items held back, or asks what the server backup includes."
version: 0.1.0
author: Mateo
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [backup, server]
---

# Server backup choices

The server backup is opt-in. At the start of each run it holds back anything new over 1 GB inside a
backed-up folder and sends a numbered "New, not backed up until you choose" list. Held items stay out
of every backup until a choice is recorded.

## Applying a reply

Mateo replies per item, for example `1 local, 2 skip` or `all skip`. Map each number to the path in
that message, then run one command per item:

```bash
server-backup decide '<path>' both    # local drive and Cloudflare R2
server-backup decide '<path>' local   # local drive only
server-backup decide '<path>' skip    # never back it up
```

Quote the path; many contain spaces. `server-backup held` lists what is still waiting. Confirm what
you applied in one short line per item, including any note the command prints. Choices apply from the
next scheduled run; never start a backup or change anything else.

If the reply is unclear (an unknown number or choice), ask instead of guessing.
