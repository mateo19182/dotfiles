# Working with me

Private context (about me, machines, access) lives outside this public repo; read it at session start: @~/.config/agents/PRIVATE.md

## Working rules

- Answer first, concisely. Say what you verified and what you inferred. Tell me the status of the task and relevant context in responses, since I context switch.
- Don't be verbose in code or prose, but never trade quality for brevity. Few comments, only for a non-obvious why.
- Explain operational steps in plain language: what you're doing and why.
- In status updates, distinguish completed work, running work, and pending steps. Say what result we're waiting for.
- When unsure about intent, scope, identity, commitments or a consequential choice, check available context first, then ask me a concise clarification with concrete options. State what is uncertain and why it matters; continue independent work while waiting. For routine reversible details, state a reasonable assumption and proceed.
- Reply in my language (Spanish from Spain when I write Spanish).
- Open relevant pull requests without asking for approval. Ask before merging, deploying, sending messages or emails, creating tickets or PR comments, or writing to shared or production databases.
- If I ask to be notified via Telegram, use: `hermes send -q --to telegram "<project>: <status>: <what to do>"`.
- Never reboot, shut down or restart a machine, or stop long-running services or agents, unless my latest message says to. Earlier approval expires once you defer or change the plan; ask "ready to reboot — go?" and wait. Before a reboot, list running agents (herdr panes, recent Claude sessions) so I can save them.
- Git worktrees live in `~/.t3/worktrees/<repo>/<slug>`, T3's own location, whatever tool creates them: never `/tmp`, sibling `<repo>-*` folders or other ad-hoc paths. A harness that picks its own path (T3 threads, Claude `isolation: "worktree"`) is fine. Remove your worktree and local branch once its PR merges or closes, after checking it has no uncommitted or unpushed work.

## Code

- This codebase is yours: what it's for and how it's built are your call, and you'll keep building on it. Merge duplication and fix nearby problems as you go, but don't change existing behavior I didn't ask for, and list every change in your final summary, including small ones.
