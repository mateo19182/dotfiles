# Agents

Curated skills for coding agents, vendored verbatim from upstream, plus the small amount of agent configuration worth tracking. This folds in the former `fleet` repository.

Last reviewed: 2026-10-17.

## What the agents profile does

`./install.sh agents` symlinks every directory under `agents/skills/<source>/` into each skill directory that exists on the machine:

| Agent       | Skill directory       |
| ----------- | --------------------- |
| Claude Code | `~/.claude/skills/`   |
| Codex       | `~/.agents/skills/`   |

Set `SKILL_DIRS="$HOME/.cursor/skills:$HOME/.config/opencode/skills"` to target other agents. Skills that are already there as plain copies are moved to `~/.local/state/dotfiles/backups/` and replaced by links, so a `git pull` updates every agent at once.

It also links `agents/claude/statusline-command.sh` to `~/.claude/statusline-command.sh`, which `~/.claude/settings.json` points at.

## Curated skills (18)

### Matt Pocock (`skills/mattpocock/`)

Planning and design:

- `grilling` — the relentless-interview core other skills call.
- `grill-me` — user-invoked entry point to `grilling`.
- `grill-with-docs` — interview about a plan while reading and writing the project docs. Needs `grilling` and `domain-modeling`.
- `domain-modeling` — build the project glossary and ADRs.
- `codebase-design` — deep-module vocabulary for interface design.

Working the code:

- `code-review` — review changes against standards and spec with parallel subagents.
- `diagnosing-bugs` — diagnosis loop for hard bugs and regressions.
- `pr` — write a PR body.
- `retro` — retrospective on a coding session.

Session and writing:

- `handoff` — compact the conversation into a document another agent can pick up.
- `wait-what` — re-pitch the last message when it did not land.
- `writing-for-agents` — how to write skills, AGENTS.md and CLAUDE.md. Use it when editing this directory.

Deliberately not vendored: the tracker suite (`triage`, `to-spec`, `to-tickets`, `wayfinder`, `implement`, `implement-spec`, `setup-matt-pocock-skills`), which assumes a configured issue tracker; `tdd`; `ask-matt`, `prototype`, `research`, `teach`, `to-questionnaire`, `improve-codebase-architecture`, `wizard`; and everything under `in-progress/` and `misc/`. `code-review` mentions `implement` and `setup-matt-pocock-skills` in passing and works without them.

### Cursor pstack (`skills/cursor-pstack/`)

- `unslop` — cut AI tells from writing. Invoke it explicitly: since upstream `bc697d0` (2026-10-12) it is user-invoked only and no longer has the "add soul" section.
- `blast-radius` — find what a change could break beyond the diff and prove the one fact it depends on.

Not vendored: `how`, `why`, `interrogate`, `recall` (depend on `poteto-mode` and Cursor subagents), the `principle-*` leaves, and the rest of pstack.

### Cursor team-kit (`skills/cursor-team-kit/`)

- `thermo-nuclear-code-quality-review` — strict maintainability review: abstraction quality, giant files, spaghetti conditions.
- `verify-this` — restate a claim falsifiably, capture baseline and treatment, compare.
- `deslop` — remove AI-generated slop from code.

### Cursor thermos (`skills/cursor-thermos/`)

- `thermo-nuclear-review` — security and correctness audit of a branch's changes. The `thermos` orchestrator that runs both reviews as Cursor subagents is not vendored; run the two reviews by hand.

## Upstream pins

Copied verbatim on 2026-10-17. Licenses sit beside each source.

| Source                                   | Commit    | Paths                                                  |
| ---------------------------------------- | --------- | ------------------------------------------------------ |
| https://github.com/mattpocock/skills     | `49dd158` | `skills/engineering/*`, `skills/productivity/*`        |
| https://github.com/cursor/plugins        | `101b274` | `pstack/skills/*`, `cursor-team-kit/skills/*`, `thermos/skills/*` |

Previous pins (2026-08-20): mattpocock `885e2ca`, cursor `fd6dd6f`. Between those and the current pins, Pocock rewrote `code-review` (standards plus subagents), `diagnosing-bugs` (prove the mutation), `domain-modeling` (`CONTEXT-FORMAT.md` became `GLOSSARY-FORMAT.md`), and `grilling` (a plain "yes" accepts the recommendation).

To refresh: clone each upstream, copy the listed skill directories over `agents/skills/<source>/`, update the table, commit. Skill directory names must match the `name:` in each `SKILL.md`.

### Managed alternative

Matt Pocock's skills now install as a self-updating plugin (`claude plugin install mattpocock-skills@claude-plugins-official`, or `codex plugin marketplace add mattpocock/skills`). That gives all 27 skills with no curation. This repository keeps the vendored subset because the selection is deliberate; do not install both, or every skill shows up twice.

## Not vendored, but installed

- **HyperFrames skills** (`hyperframes*`, `media-use`) are written by the HyperFrames CLI into `~/.claude/skills/` and symlinked from `~/.cursor/skills/`, `~/.config/opencode/skills/` and `~/.config/devin/skills/`. Reinstall with the CLI, not from here.
- **Claude synced skills** under `~/.claude/skills/synced/` come from claude.ai and are managed there.
- **Claude plugins**: `shopify-ai-toolkit@claude-plugins-official`.
- **Cursor's own skills** under `~/.cursor/skills-cursor/` ship with Cursor.

## MCP servers (names only)

Credentials and tokens stay in each agent's own config, never here.

- Claude Code (`~/.claude.json`): `exa`, `posthog`.
- Codex (`~/.codex/config.toml`): `posthog`, `linear`, `huly-tribo`, `henad`, all currently disabled.
- Cursor: none.

## Hooks

Every hook in `~/.claude/settings.json`, `~/.codex/hooks.json` and `~/.cursor/hooks.json` is written by the Orca agent monitor and forwards events to `~/.orca/agent-hooks/`. Those files are tool-managed; let Orca own them.
