---
name: escalation-dormancy
description: |
  Codex-side companion to the escalation dormancy contract. Use when you (the executing agent) have hit a HUMAN-GATE or task-failure that requires escalation, are about to write an `ESCALATION-<ts>.md` file, are entering or already in DORMANT state, or are about to re-interpret prior STATE.md notes and need to know whether to escalate clarification instead. Bundles `scripts/wait-for-resolution.sh` for blocking, zero-token waits on the escalation file.

  TRIGGERS: escalating, escalation, write escalation file, dormant, awaiting maintainer, halt for user, HUMAN-GATE, RESOLVED line, BLOCKED line, ESCALATION-, .planning/auto-execution/escalations, paused mid-task, awaiting external signal, supervisor handoff, /goal pause, executor-orchestrator coordination.

  Does NOT do: write production code, modify STATE.md beyond the AWAITING_HUMAN flip, re-interpret prior COMPLETE entries, or make policy decisions during DORMANT state. Those belong to the supervisor session (Claude Code in the maintainer's chat) — see the higher-reasoning supervisor framing below.
---

# Escalation Dormancy (Codex /goal side)

When you escalate, you are not waiting for a human directly. You are escalating to a **higher-reasoning supervisor agent** (Claude Code in the maintainer's chat) that has access to the maintainer's signal-channel, your full repo context, and the policy on file. The supervisor adjudicates, drafts the `RESOLVED:` line on maintainer authorization, and writes it to your escalation file. You then resume.

This skill is the executor-side half of the loop. The supervisor-side half lives at `.claude/skills/escalation-watch/SKILL.md` (loaded by the supervisor when it joins the workspace).

Adapted from `agentic-ops@f041a3a` per ADR `docs/decisions/0011-phase-1-orchestration.md`. The wait script is structurally identical; the skill text is tailored to erebus paths and Phase-1 escalation kinds.

## Why this skill exists

Without an explicit dormancy contract, an escalating executor has two bad defaults:

- **Hard-halt the session** — loses in-context state (conversation history, reasoning chain, scratchpad), forces the maintainer to re-prompt, often with re-explanation overhead.
- **Start the next thing it thinks is OK to do** — collides with the supervisor or maintainer doing parallel work, creates the shadow-replacement anti-pattern.

The dormancy contract closes both gaps. Source of truth: [`.planning/EXECUTION-MODEL.md`](../../../.planning/EXECUTION-MODEL.md) §"Dormancy contract". This skill operationalizes that section with concrete steps + a bundled wait script.

## When to load this skill

You should be reading this skill when:

1. You are about to fail a task in a way that triggers the escalation procedure (per EXECUTION-MODEL.md §"Escalation procedure"), OR
2. You have just written an `ESCALATION-<ts>.md` file and need to know what comes next, OR
3. You are already in DORMANT state and need to know how to wait correctly, OR
4. You are about to re-interpret a prior `STATE.md` note or COMPLETE entry and need to know whether that's allowed.

If none of the above and you're just executing a task per the driver loop, skip this skill.

## erebus-specific escalation kinds

Phase-1 escalations carry a `kind:` field that determines who responds and how:

| Kind | Who responds | How |
|---|---|---|
| `task-failure` | Supervisor (Claude monitor) | Triage; may push fix or escalate further |
| `human-gate-lab-clip` | Logan | Plays clip; writes RESOLVED with approve / tune / reject |
| `needs-deep-reasoning` | Supervisor invokes `claude -p` (Opus + max reasoning) | Response file referenced in RESOLVED line |
| `state-mismatch` | Supervisor | Reconciles STATE.md with workspace reality |
| `monitor-merge-blocked` | Either supervisor or Logan | Supervisor first; escalates to Logan if security/scope-related |
| `creative-direction` | Logan | Cyberpsycho preset tuning, visualizer aesthetics |
| `scope-expansion-request` | Logan | Yes/no on whether the work belongs in Phase-1 or defers to Phase-2 |
| `auth-failure` | Logan | OAuth / API credential issues |

The `kind:` field lets the supervisor's escalation-watch skill route correctly without re-reading the whole escalation.

## The five-step DORMANT protocol

### Step 1 — Write the escalation file (per existing procedure)

Per `EXECUTION-MODEL.md` §"Escalation procedure":

1. Write `.planning/auto-execution/escalations/ESCALATION-<ISO8601>.md` with:
   - `task_id:` (e.g., `P3-T2`)
   - `kind:` (from the table above)
   - `attempted:` verbatim commands run
   - `observed:` deterministic facts (CI status, PR state, file existence, mergeability)
   - `failure:` why /goal stopped
   - `suggested_resolution:` the maintainer signal /goal would expect

2. Update STATE.md (`status: escalated`, `escalation_path: <path>`).

3. Append one-line index entry to `.planning/auto-execution/ESCALATIONS.md`.

This skill does not change those steps. The dormancy protocol picks up after they complete.

### Step 2 — Flip to AWAITING_HUMAN and stop

Update `STATE.md` minimally:

- `task_status: AWAITING_HUMAN`
- `last_updated: <now>`
- `## Active escalation` block: path = the file you just wrote; resolved = false

Do **not** advance `current_task_id`. Do **not** modify any other state. Do **not** start the next task.

### Step 3 — Invoke the wait script

Run the bundled script in a single foreground bash call:

```bash
.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh \
  .planning/auto-execution/escalations/ESCALATION-<your-ts>.md
```

The script blocks until the escalation file gets a `RESOLVED:` or `BLOCKED:` line (or the 4-hour timeout fires). It uses `fswatch -1` for event-driven wakes when available, falls back to cadenced polling otherwise. **Token cost: zero while blocking.** No model inference happens until the script returns.

Useful flags:

- `--timeout <seconds>` — override 4h default. Use a longer timeout for known-async resolutions (e.g., lab-clip reviews from Logan).
- `--poll-interval <seconds>` — polling cadence when fswatch is unavailable. Default 30s.
- `--no-followup` — on timeout, exit without writing a follow-up escalation. Use only if you know what you're doing.

### Step 4 — Interpret the exit code

| Exit | Meaning | What to do |
|---|---|---|
| 0 | RESOLVED line found | Read full line via stdout; verify scope (next section); resume per §"Resume protocol" |
| 1 | BLOCKED line found | Read full line; mark task as blocked in STATE.md; continue to next task per EXECUTION-MODEL.md §"Permanent escalation (BLOCKED)" |
| 2 | Timeout (4h+) | Follow-up escalation written; re-invoke the script on the new file OR halt and surface to maintainer |
| 3 | Usage error | Fix the invocation |
| 4 | File missing | The escalation file disappeared — escalate clarification |
| 130 | Interrupted (Ctrl-C) | The maintainer or supervisor interrupted you intentionally — read STATE.md before doing anything |

### Step 5 — Verify scope before resuming

Before treating exit-0 as authoritative, verify the `RESOLVED:` line is unambiguously scoped to your escalation file. Acceptable forms:

- The line is in your own escalation file (strongest signal).
- The line in another file explicitly names yours by path/basename.
- The wording is "all open escalations resolved" or equivalent unambiguous multi-scope.

If ambiguous (e.g., generic "escalation resolved" with multiple unresolved files visible), do **not** resume. Write a clarification escalation:

```
ESCALATION-<new-ts>-clarify.md
```

asking which file the maintainer's signal covers. Then re-invoke the wait script on the clarification file. Do not unilaterally interpret an ambiguous resolution.

## Hard prohibitions during DORMANT

These are restated from `EXECUTION-MODEL.md` §"Prohibitions during DORMANT state" because they are the most-likely failure modes:

- Do **not** start the next task in the driver loop.
- Do **not** modify STATE.md beyond the AWAITING_HUMAN flip.
- Do **not** re-interpret prior STATE.md notes or COMPLETE entries. They are immutable audit records. If you believe a prior entry is wrong, write a `clarify` escalation rather than editing it.
- Do **not** do parallel "ready" work elsewhere in the codebase. The supervisor may be drafting a response, syncing state, or surfacing context. Concurrent work creates shadow-replacement.
- Do **not** modify `.planning/` files outside of STATE.md (and STATE.md only as specified). The planning surface is supervisor-managed during DORMANT.

## On resume

Per `EXECUTION-MODEL.md` §"Session-resume procedure":

1. Re-read `STATE.md` from the top.
2. Trust STATE.md notes dated AFTER your pause timestamp as authoritative supervisor-side updates. If a note's reasoning is unclear, escalate clarification rather than re-interpret.
3. Continue from `current_task_id`.
4. Update STATE.md: flip Status from `escalated (...)` back to `active`; flip `## Active escalation` `resolved: false → true`; bump `last_updated`.

## Cross-references

- **Source of truth for the contract:** `.planning/EXECUTION-MODEL.md` §"Dormancy contract"
- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Per-kind handling:** `.planning/HUMAN-GATES.md`
- **Supervisor-side companion skill:** `.claude/skills/escalation-watch/SKILL.md`
- **Wait script:** `.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh`
