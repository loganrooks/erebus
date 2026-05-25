# Execution model

This document defines the autonomous-execution machinery for the
erebus Phase-1 build. An agent given the prompt at
`auto-execution/GOAL_PROMPT.md` runs the initiative phase-by-phase
without human intervention except at explicitly-marked HUMAN-GATE
checkpoints. State persists to disk under `auto-execution/`.

This file is the contract codex `/goal` reads on every `GO`
bootstrap. It is referenced from `AGENTS.md` as a hard-rule entry
so non-codex agents reading the repo on session start also pick
up the contract.

Source ADR: [`docs/decisions/0011-phase-1-orchestration.md`](../docs/decisions/0011-phase-1-orchestration.md).

## The `GO` command

### What the user types

```text
GO
```

Or equivalently: load `.planning/auto-execution/GOAL_PROMPT.md`
into a fresh codex `/goal` session and let it run.

### What the agent does first (bootstrap)

On receiving `GO`, the agent's very first action is to read, in
order:

1. `.planning/auto-execution/GOAL_PROMPT.md`
2. `docs/decisions/0011-phase-1-orchestration.md`
3. `.planning/EXECUTION-MODEL.md` (this file)
4. `.planning/GUARDRAILS.md`
5. `.planning/HUMAN-GATES.md`
6. `.planning/RISK-REGISTER.md`
7. `AGENTS.md` (general agent rules)
8. `.planning/auto-execution/STATE.md` if it exists

Then:

- **If STATE.md does NOT exist** → execute phase P0 (bootstrap).
  P0's first task is to initialize STATE.md.
- **If STATE.md exists** → read it; identify `current_phase` and
  `current_task_id`; read the relevant `.planning/phases/PN-*.md`;
  proceed with the next task per the driver loop.
- **If `.planning/auto-execution/DONE.md` exists** → halt.
  Initiative is complete; print summary.
- **If an unresolved escalation exists** (any file under
  `.planning/auto-execution/escalations/` without a `RESOLVED:`
  or `BLOCKED:` line at column 0) → halt. Print the path.
  Wait for the supervisor.

### What the agent reads at every task

Every single task (no exceptions):

1. `.planning/auto-execution/STATE.md` — verify `current_phase`
   and `current_task_id`.
2. The relevant `.planning/phases/PN-*.md` — phase definition +
   task definition (after P0 atomizes the phase doc into
   per-task specs).
3. `.planning/GUARDRAILS.md` — for any rule that bears on the
   task.
4. Any task-specific files the task spec references (REQ-IDs,
   anchor tests, presets).

### What the agent writes at every task

After every task, before declaring it complete:

1. Verify postconditions per the task spec.
2. Append a one-line entry to `.planning/auto-execution/SESSION-LOG.md`
   (format below).
3. Update `.planning/auto-execution/STATE.md` atomically
   (write-replace; never partial edits).
4. Append to `.planning/auto-execution/ARTIFACTS.md` if a new
   committed file was produced.
5. If the task transitions phases: write
   `.planning/auto-execution/checkpoints/CHECKPOINT-PN.md` and
   append a summary block to `CHECKPOINTS.md`.

## Driver loop

The agent follows this loop on every task:

```text
while True:
    state = read(".planning/auto-execution/STATE.md")
    if state.done:
        halt("DONE.md exists; nothing to do")
    if state.escalation_path and not state.escalation_resolved:
        halt("ESCALATION pending; supervisor input required")
    if state.context_pressure_high:
        write_session_summary()
        halt("Session ending; resume with GO")
    task = next_task(state)
    if task is None:
        if all_phases_complete(state):
            write_done()
            halt("All phases complete")
        else:
            escalate("No next task identified but not done")
    verify_preconditions(task)
    if precondition_failed:
        if retries_exhausted: escalate(...)
        else: increment_retry(); continue
    execute_task(task)
    if execution_failed:
        if retries_exhausted: escalate(...)
        else: increment_retry(); continue
    verify_postconditions(task)
    if postcondition_failed:
        if retries_exhausted: escalate(...)
        else: increment_retry(); continue
    advance_state(task)
    if task.is_phase_terminal:
        run_checkpoint(task.phase)
    if waiting_for_external(task):
        # Dormancy contract — see below.
        invoke_wait_script_in_foreground(task.wait_kind, task.wait_args)
```

## Task state machine

```text
NOT_STARTED → IN_PROGRESS → AWAITING_VERIFICATION → COMPLETE
                ↓                  ↓
              FAILED            VERIFICATION_FAILED
                ↓                  ↓
              [retry up to N]    [retry up to N]
                ↓                  ↓
              ESCALATED         ESCALATED

AWAITING_EXTERNAL — special state for tasks blocked on CI, PR
                    review, monitor merge, or escalation
                    resolution. Always paired with an active
                    foreground wait script (dormancy contract).

AWAITING_HUMAN    — supervisor-side state. Set when an
                    escalation is written to disk and the
                    dormancy script is blocking.
```

## Task atomicity and verification

**Every task is atomic.** A task either completes (postconditions
verified) or it doesn't. No partial credit. Mid-task interruption →
retry the whole task.

**Verification is mechanical.** Postconditions are file-existence
checks, file-content greps, exit-code checks, `pytest -k`
selectors, anchor-name lookups in TEST_SPEC.md. The agent runs
them via Read / Bash and gets unambiguous yes/no.

**Subjective judgement is HUMAN-GATE only.** Tasks that require
qualitative review (does the cyberpsycho grading look cyberpunk?
does the visualizer have the right energy?) escalate to the
maintainer via the dormancy contract. They are never auto-resolved.

## Checkpoint protocol

At the end of each phase, before advancing:

1. Run all postconditions of all tasks in the phase. All must pass.
2. Write `.planning/auto-execution/checkpoints/CHECKPOINT-PN.md`
   with phase ID, completion timestamp, list of completed tasks
   (with timestamps), list of artifacts (paths + sha256 short),
   verified postconditions, cost estimate.
3. Append a summary block to
   `.planning/auto-execution/CHECKPOINTS.md`.
4. Update STATE.md (`current_phase` advances; `current_task_id`
   resets to the first task of the next phase).
5. **PR-merge gate:** if the phase produced a PR, the PR must be
   merged by the monitor before the checkpoint is written. (No
   merged PR → no checkpoint.)
6. **Lab-clip review gate:** if the phase produced a lab clip
   (P1–P7 always do; P8 does), the corresponding HUMAN-GATE
   must be resolved before the checkpoint is written.
7. **Do NOT skip checkpoints.** Even if the next phase seems
   trivial.

## Session management

### Context pressure thresholds

The agent self-monitors. Each codex session has a finite context
window:

- After every task completion, estimate remaining context budget.
- If context usage exceeds **70%** → begin session-end procedure.
- If a single upcoming task is estimated to consume **>25%** of
  remaining context → begin session-end procedure before starting it.

### Session-end procedure

1. Write `.planning/auto-execution/sessions/SESSION-<ISO8601-timestamp>.md`
   with: tasks completed this session, current STATE.md snapshot
   (mirror), next-task pointer, partial work needing cleanup,
   files modified (paths + commit refs), issues + resolutions.
2. Update STATE.md `last_session_end`.
3. Halt with message:
   ```text
   Session ending due to context pressure.
   Last completed task: <id>
   Next task: <id>
   Resume by running: GO
   ```

### Session-resume procedure

Start of every non-first session:

1. Read STATE.md.
2. Read most recent file in `.planning/auto-execution/sessions/`.
3. Read most recent file in `.planning/auto-execution/checkpoints/`
   if applicable.
4. Verify workspace state matches what STATE.md says (e.g., if
   STATE says PR #N is open, run `gh pr view N`).
5. If discrepancy → write ESCALATION (with `kind: state-mismatch`),
   halt.
6. Resume with the next task.

### Hard rule: never lose state

Every state-mutating action commits state to disk before claiming
the action complete. If the agent crashes mid-task, the next
session's resume protocol detects the inconsistency and either
rolls back or escalates.

## Failure handling and escalation

See `RISK-REGISTER.md` for risk-class-specific responses.

### Retry policy (per task)

- Default `max_retries: 3`.
- Specific tasks may override (defined in their phase-doc spec).
- Between retries: 30-second `sleep` (allows transient issues to
  clear).
- After max retries → escalate.

### Escalation procedure

1. Write `.planning/auto-execution/escalations/ESCALATION-<ISO8601>.md`
   with:
   - **Task ID** (e.g., `P3-T2`)
   - **Kind** (`task-failure`, `human-gate-lab-clip`,
     `needs-deep-reasoning`, `state-mismatch`,
     `monitor-merge-blocked`, `creative-direction`)
   - **What was attempted** — verbatim commands run
   - **Observed state** — deterministic facts (CI status, PR
     state, file existence, mergeability)
   - **Failure / gate** — why /goal stopped
   - **Suggested resolution** — the maintainer signal /goal
     would expect to see
2. Update STATE.md (`status: escalated`, `escalation_path: <path>`).
3. Append index entry to `.planning/auto-execution/ESCALATIONS.md`.
4. Invoke the dormancy script (see next section).

## Dormancy contract (zero-token-while-waiting)

This is the F-007 systemic fix from agentic-ops. The principle:
**when /goal awaits an external event, it must invoke a
foreground blocking script in the same turn as the action that
created the wait**. While the script blocks, codex's turn stays
open but no model inference happens. Zero tokens are consumed
while waiting.

This is the load-bearing piece. Without it, /goal's stop-hook
continuation burns tokens repeatedly checking "is it ready yet"
during multi-hour waits.

### When to invoke a wait script

Anytime STATE.md flips to `AWAITING_EXTERNAL` or `AWAITING_HUMAN`,
the **same turn** must end with one of:

| Awaiting | Script invocation |
|---|---|
| Escalation resolution | `.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh <ESCALATION-FILE>` |
| CI to reach terminal state | `scripts/wait-for-ci-green.sh <PR-NUM>` |
| `@codex review` bot review | `scripts/wait-for-codex-review.sh <PR-NUM>` |
| Monitor to merge the PR | `scripts/wait-for-pr-merge.sh <PR-NUM>` |

### Properties of every wait script

1. **Foreground bash tool call.** Single invocation, blocks until
   the awaited event or timeout.
2. **fswatch-event-driven when available** (file-based waits),
   polling fallback otherwise. gh-API-based waits use cadenced
   polling (default 30s).
3. **4-hour default timeout.** After timeout, the script writes
   a follow-up escalation and exits with code 2.
4. **Exit codes encode resolution:**
   - `0` — awaited event fired successfully
   - `1` — known terminal failure (`BLOCKED:` line, CI failure,
     PR closed without merge)
   - `2` — timeout, follow-up escalation written
5. **Repo-portable.** Scripts take all targets as arguments.

### Prohibitions during DORMANT state

The "DORMANT" state — between writing the escalation and the wait
script returning — is bounded by these prohibitions:

1. Do not start the next task.
2. Do not modify STATE.md beyond the AWAITING_* flip.
3. Do not re-interpret prior `STATE.md` notes or `COMPLETE`
   entries. They are immutable audit records. If a prior entry
   looks factually wrong, write a new escalation
   (`ESCALATION-<ts>-clarify.md`) rather than editing.
4. Do not do "ready" work while waiting. The pause is the
   contract — the supervisor may be drafting a response or
   syncing state. Parallel work creates shadow-replacement.

### Resume after wait

When the wait script returns:

- **Exit 0:** Read the resolution payload. For escalation
  resolutions, read the `RESOLVED:` line; verify scope matches
  this escalation's task ID. For PR-event waits, read the gh
  output. Resume per the task spec's "on resume" instructions.
- **Exit 1:** Known terminal failure. Apply the task spec's
  failure-mode handling. Most often: mark task as BLOCKED in
  STATE.md (per Permanent escalation below), advance to next
  task.
- **Exit 2:** Timeout. The follow-up escalation has already
  been written. Re-invoke the wait script on the new file, OR
  halt and surface to maintainer if the timeout was the second
  one in a row.

## Permanent escalation (BLOCKED)

The supervisor adds a `BLOCKED: <reason>` line to the escalation
file when a task cannot proceed and the next task should be
attempted instead. On the next `GO`:

1. The agent reads the BLOCKED line.
2. Marks the task as `BLOCKED` in STATE.md.
3. Continues to the next task.
4. The phase checkpoint will note the blockage and the phase may
   complete with a partial postcondition set, surfaced in the
   checkpoint summary.

`BLOCKED` is for "we can't do this in Phase-1 but the rest of
Phase-1 should proceed" — different from `RESOLVED: ... continue`
(do the task) or `RESOLVED: ... skip` (treat as complete).

## Done detection

`DONE` when ALL of:

- Every reachable phase has a checkpoint file in
  `.planning/auto-execution/checkpoints/`.
- All checkpoints have `verified: true`.
- No unresolved escalations.
- Final phase (P9) postconditions all pass.
- `test_phase1_integration` is green on main.
- The cyberpsycho preset render passes Logan's final lab review
  (HUMAN-GATE-7, see HUMAN-GATES.md).

When DONE is detected, the agent writes
`.planning/auto-execution/DONE.md` with: completion timestamp,
summary cross-referencing checkpoints, total tasks completed,
total sessions consumed, total estimated token cost, pointers to
the merged PRs and the final lab clip.

## State schemas

### STATE.md

Single source of truth. Mutated atomically (write-replace; never
append-then-edit). Schema:

```markdown
# Phase-1 execution state

**Source ADR:** docs/decisions/0011-phase-1-orchestration.md
**Started:** <ISO 8601>
**Last updated:** <ISO 8601>
**Last session end:** <ISO 8601 or null>
**Status:** active | escalated | done | paused

## Current position
- **current_phase:** P<N>
- **current_task_id:** P<N>-T<M>
- **task_status:** NOT_STARTED | IN_PROGRESS | AWAITING_VERIFICATION |
                   AWAITING_EXTERNAL | AWAITING_HUMAN | COMPLETE |
                   FAILED | ESCALATED | BLOCKED
- **retry_count:** N
- **awaiting:** null | { kind, args, since }

## Phase progress
- P0..P9 with status: complete | in_progress | pending | skipped

## Counters
- tasks_completed, tasks_blocked, sessions_used, estimated_cost_usd

## Active escalation
- **path:** null | escalations/ESCALATION-<ts>.md
- **resolved:** false | true

## Recent activity (last 5 tasks)
1. ...

## Notes
- Free-form supervisor annotations (governance notes,
  discipline reminders). Immutable once written.
```

### SESSION-LOG.md

Append-only. One line per task execution:

```text
<ISO 8601>\t<task_id>\t<status>\t<one-line summary>\t<duration_seconds>
```

### CHECKPOINTS.md

Append-only summary; one block per phase. Detail in
`checkpoints/CHECKPOINT-PN.md`.

### ESCALATIONS.md

Append-only index; one line per incident. Detail in
`escalations/ESCALATION-<ts>.md`.

### ARTIFACTS.md

Append-only registry of files produced. Used for audit,
rollback, and DONE.md summary. Format: markdown table with
columns artifact path, phase, task, created at, sha256 (first 16).

## Higher-reasoning supervisor

During DORMANT state, the active reasoning agent is the
Claude monitor session — not codex (which is blocked). The
supervisor is "higher-reasoning" in the sense that:

- It has the maintainer's signal channel (the chat).
- It has read access to the full repo plus the codex
  orchestrator's context via STATE.md.
- It can invoke `claude -p` for deeper reasoning when an
  escalation needs more than triage.

The supervisor's protocol lives in
[`.claude/skills/escalation-watch/SKILL.md`](../.claude/skills/escalation-watch/SKILL.md).
Codex does not need to read that file — it just writes
escalations and waits.
