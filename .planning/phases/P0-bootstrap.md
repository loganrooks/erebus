# P0 — Bootstrap

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p0-bootstrap`
- **Predecessor:** none (entry phase)
- **Lab clip:** none (P0 is infrastructure-only)
- **HUMAN-GATE:** HUMAN-GATE-1 at session launch; HUMAN-GATE-2 at P0 PR merge

## Scope

Initialize the autonomous-execution state. Verify the orchestration
infrastructure (this PR landed) actually works end-to-end before
real product work begins. Atomize phase decomposition and triage
the 39-item deferred backlog.

This phase is the validation run for the orchestration setup. If
P0 cannot complete autonomously, no later phase will.

## Task overview (atomic decomposition is P0-T2's job)

1. **P0-T1 — Initialize STATE.md.** Write
   `.planning/auto-execution/STATE.md` from the template; set
   `current_phase: P0`, `current_task_id: P0-T2`, all phase
   statuses to `pending`. Append index entries to ESCALATIONS.md
   and ARTIFACTS.md.

2. **P0-T2 — Decompose phases into atomic tasks.** Read each
   `phases/PN-*.md` and produce one expanded task list per phase
   under `.planning/auto-execution/tasks/PN-tasks.md`. Each
   expanded task: ID, preconditions, work description,
   postconditions (mechanical), retry policy, wait kind on
   external dependency.

3. **P0-T3 — Triage the 39-item deferred backlog.** Read the
   closing notes of `docs/decisions/archive/{0005,0007,0009,0010}.md`
   and produce `.planning/auto-execution/BACKLOG-TRIAGE.md` with a
   row per item: `<source>`, `<summary>`, `<KEEP | DEFER-PHASE-2 | DROP>`,
   `<rationale>`. KEEP items get folded into the relevant phase's
   expanded task list.

4. **P0-T4 — Smoke-test the dormancy round-trip.** Write a
   throwaway escalation with `kind: smoke-test`; invoke
   `wait-for-resolution.sh` with `--timeout 60`; supervisor
   responds with `RESOLVED: smoke-test ok`; verify exit 0;
   delete the escalation file. Postcondition: `SESSION-LOG.md`
   has a `P0-T4` line with `status: COMPLETE`.

5. **P0-T5 — Smoke-test PR-event waits.** Open a no-op draft
   PR (whitespace change to NOTES.md); push; invoke
   `wait-for-ci-green.sh`; verify exit 0 after CI passes;
   close the PR without merge. Postcondition: dormancy
   contract held throughout (no token churn).

6. **P0-T6 — Open the P0 PR and signal merge-ready.** Branch
   `phase/p0-bootstrap`; commit P0 artifacts; push; invoke
   `wait-for-codex-review.sh` then `wait-for-pr-merge.sh`.
   Supervisor (monitor session) merges when preconditions met.

7. **P0-T7 — Write CHECKPOINT-P0.md and advance.** On merge,
   write the checkpoint file; update STATE.md; set
   `current_phase: P1`. Halt cleanly so a fresh session can
   pick up P1.

## Postconditions

- `.planning/auto-execution/STATE.md` exists and parses.
- `.planning/auto-execution/tasks/P{1..9}-tasks.md` exist.
- `.planning/auto-execution/BACKLOG-TRIAGE.md` exists with all
  39 items classified.
- `.planning/auto-execution/checkpoints/CHECKPOINT-P0.md` exists.
- The smoke-tests confirmed the dormancy contract works.
- The P0 PR is merged.

## Deferred backlog items relevant to this phase

None directly — P0 is the phase that **does the triage**, not
the phase that addresses items. KEEP items will surface in the
phase that owns them.

## Notes

- P0 is also when /goal validates that its own setup
  (claude -p invocation path, gh credentials, ffmpeg /
  yt-dlp on PATH, pre-commit hooks installed) is functional.
  Failures here are HUMAN-GATE-8.
- The expanded task lists under
  `.planning/auto-execution/tasks/` are gitignored from this
  point forward — they're runtime artifacts, not committed
  policy. (The phase docs in `.planning/phases/` ARE
  committed and are the policy.)
