# CLAUDE.md

Claude Code reads this file at the start of every session. The
authoritative agent instructions live in `AGENTS.md` (the
cross-vendor standard); this file holds Claude-Code-specific
behaviour only.

## Import the shared rules

Read `AGENTS.md` in full. Every rule there applies here. The text
below extends rather than replaces those rules.

## Claude-Code-specific notes

- **Use `--allowedTools` explicitly.** Even in interactive mode,
  prefer explicit permission grants over `acceptEdits`. See
  `docs/WORKFLOW.md` §"Permissions" for the standard allow-list.

- **Subagent usage.** When the task is large, spawn focused
  subagents (one per stage) rather than holding the entire codebase
  in context. Pass the relevant REQ-IDs and anchor IDs explicitly.

- **Skills directory.** Project-specific Claude skills live in
  `.claude/skills/`. If you add one, document it in
  `docs/decisions/` with rationale.

- **The `/agents` subcommand** can drive review checkpoints; see
  `docs/WORKFLOW.md` §"Cross-vendor review checkpoints" for the
  specific invocations and model + reasoning recommendations.

## What goes in CLAUDE.md vs AGENTS.md

| Rule type                                | Goes in       |
| ---------------------------------------- | ------------- |
| Project conventions (any agent)          | `AGENTS.md`   |
| TDD discipline (any agent)               | `AGENTS.md`   |
| Architectural constraints (any agent)    | `AGENTS.md`   |
| Claude-specific flags / subagent usage   | `CLAUDE.md`   |
| Cursor-specific rules                    | `.cursorrules`|
| Codex hierarchical overrides             | `AGENTS.override.md` |

If you find yourself adding something here that isn't
Claude-specific, move it to `AGENTS.md`.

## Local overrides

For personal preferences that shouldn't be committed, use
`CLAUDE.local.md` (gitignored). Keep it small; team-relevant
preferences should be discussed and added to `AGENTS.md` instead.
