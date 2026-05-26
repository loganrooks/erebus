# Phase-1 goal prompt for Codex /goal

This is the paste-into-codex artifact. Logan loads it into a
fresh codex session with `/goal`, then types `GO`.

---

## Goal

Drive erebus Phase-1 to evidence-based completion: the
`erebus render --preset cyberpsycho --videos <playlist-url>
--music <playlist-url> --out out.mp4` invocation completes on
the supplied playlists with the output passing the precise
assertions in [`docs/TEST_SPEC.md`](../../docs/TEST_SPEC.md)
§"End-to-end integration", every stage exposed as a typed
Python function in `erebus/stages/` and isolatable in the lab,
all Phase-1 TDD anchors green, and the `test_phase1_integration`
anchor passing on `main`. Preserve all hard rules in
[`AGENTS.md`](../../AGENTS.md) and
[`GUARDRAILS.md`](../GUARDRAILS.md). Use the dormancy contract
in [`EXECUTION-MODEL.md`](../EXECUTION-MODEL.md) §"Dormancy
contract" any time you await an external event — no token
churn on continuation polling. Between iterations, advance one
atomic task at a time per the driver loop. If blocked or no
valid paths remain, escalate via the dormancy contract rather
than guessing.

## Bootstrap reading order

Your **first action on every `GO`** is to read, in this order:

1. This file (you are here)
2. [`docs/decisions/0011-phase-1-orchestration.md`](../../docs/decisions/0011-phase-1-orchestration.md)
3. [`.planning/EXECUTION-MODEL.md`](../EXECUTION-MODEL.md)
4. [`.planning/GUARDRAILS.md`](../GUARDRAILS.md)
5. [`.planning/HUMAN-GATES.md`](../HUMAN-GATES.md)
6. [`.planning/RISK-REGISTER.md`](../RISK-REGISTER.md)
7. [`AGENTS.md`](../../AGENTS.md)
8. [`PROJECT.md`](../../PROJECT.md) (Phase 1 scope + cyberpsycho preset)
9. [`REQUIREMENTS.md`](../../REQUIREMENTS.md) (all Phase-1 REQ-IDs)
10. [`docs/TEST_SPEC.md`](../../docs/TEST_SPEC.md) (anchor test definitions)
11. [`.planning/auto-execution/STATE.md`](STATE.md) if it exists

Then bootstrap per EXECUTION-MODEL.md §"What the agent does
first".

## Evidence-based completion

You may not mark Phase-1 complete on a hunch. The completion
contract is:

- Every reachable phase has a checkpoint file in
  `.planning/auto-execution/checkpoints/`.
- All checkpoints have `verified: true`.
- No unresolved escalations under
  `.planning/auto-execution/escalations/`.
- `test_phase1_integration` is green on `main` (run
  `uv run pytest -k test_phase1_integration` to verify).
- The cyberpsycho preset render passes Logan's final lab
  review (HUMAN-GATE-7 resolved).
- `.planning/auto-execution/DONE.md` has been written per
  EXECUTION-MODEL.md §"Done detection".

Until all of those hold, the goal is not complete.

## Allowed inputs, tools, and boundaries

You may use:

- `git`, `gh`, `uv`, `pytest`, `pre-commit`, `ruff`, `mypy`,
  `ffmpeg`, `ffprobe`, `yt-dlp` (via the typed wrapper only —
  no raw subprocess per AGENTS.md hard rule), `claude -p` (for
  deep-reasoning escalations).
- File operations within the erebus repo.
- Pushing to feature branches.
- Writing PR bodies and review responses.

You may NOT:

- Push to `main` directly.
- Merge any PR (the Claude monitor session merges, never you).
- Modify repo settings (branch protection, secrets, etc.).
- Use `--no-verify`, `--no-gpg-sign`, or hook-bypass flags.
- Commit secrets, `.env` files, or anything `gitleaks`
  would flag.
- Modify files under `docs/decisions/archive/` or
  `docs/decisions/reviews/` (immutable audit records).
- Skip a checkpoint to "speed things up."
- Edit STATE.md beyond the protocol in EXECUTION-MODEL.md.

## Iteration policy

Between iterations of the driver loop:

1. Update STATE.md atomically.
2. Append to SESSION-LOG.md.
3. If transitioning phase: write the checkpoint, update
   STATE.md `current_phase`, halt cleanly so a fresh session
   can pick up the next phase.
4. If context pressure exceeds 70% or the next task is
   estimated >25% of remaining context: write a session
   snapshot under `sessions/`, halt, and let Logan resume.

## Dormancy: when you wait, wait correctly

Any time you await an external event, invoke the appropriate
wait script in the **same turn** as the action that created
the wait. Token cost is zero while the script blocks.

| Awaiting | Same-turn invocation |
|---|---|
| Escalation resolution | `.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh <ESCALATION-FILE>` |
| CI to reach terminal state | `scripts/wait-for-ci-green.sh <PR-NUM>` |
| `@codex review` bot | `scripts/wait-for-codex-review.sh <PR-NUM>` |
| Monitor to merge | `scripts/wait-for-pr-merge.sh <PR-NUM>` |

Load the `.agents/skills/escalation-dormancy/` skill the first
time you're about to escalate; it has the full DORMANT
protocol.

## Stop condition

If blocked or no valid paths remain after the retry policy in
EXECUTION-MODEL.md is exhausted, escalate per the dormancy
contract and stop. Do not improvise; the supervisor or Logan
will resume you with a `RESOLVED:` line.

## Higher-reasoning escalation to claude -p

When you hit an architectural decision you don't have strong
evidence to settle, emit an escalation with
`kind: needs-deep-reasoning`. The supervisor will invoke
`claude -p` with Opus + max reasoning on the escalation file.
Their response appended to the escalation becomes your
`RESOLVED:` payload.

Concrete invocation pattern (you may run this yourself if the
supervisor session is unavailable):

```bash
claude -p "$(cat .planning/auto-execution/escalations/ESCALATION-<ts>.md)" \
  --allowedTools "Read,Grep,Glob,Bash(uv run pytest *),Bash(git diff *)" \
  --model claude-opus-4-7 \
  --output-format text \
  --max-turns 25 \
  > .planning/auto-execution/escalations/ESCALATION-<ts>-claude-p-response.md
```

## What `GO` triggers

On `GO`:

1. Read the bootstrap files (above).
2. Check STATE.md / DONE.md / ESCALATIONS.md per
   EXECUTION-MODEL.md §"What the agent does first".
3. If clean: start or continue the driver loop.
4. If escalation pending: halt; print the path; wait for
   supervisor.
5. If DONE: print summary and stop.

---

**Phase-1 starting point:** P0-T1 (initialize STATE.md).

**Phase-1 ending point:** P9-T6 PR merged → DONE.md written.

**Maintainer (Logan) interaction surface during Phase-1:**
HUMAN-GATE escalations only. Routine PRs flow through codex
bot review + Claude monitor merge without your attention.

Type `GO` to start.
