---
name: escalation-watch
description: |
  Supervisor-side companion for /goal (Codex). Watches a /goal escalations directory, surfaces new or status-changed escalations, helps the supervisor draft RESOLVED-line responses that follow the per-file resolution protocol, and keeps STATE.md / FRICTIONS.md in sync. Use when /goal is paused on a HUMAN-GATE or escalation and the supervisor (Claude) is the maintainer-proxy responder.

  TRIGGERS: /goal escalation, escalation watch, escalation poller, monitor escalations, /goal is dormant, /goal is paused, awaiting maintainer signal, ESCALATION-*.md, .planning/auto-execution/escalations, resolve escalation, RESOLVED line, escalation file resolution, supervisor proxy for /goal, /goal handoff, /goal coordination loop.

  Does NOT do: write production code on /goal's behalf (use /goal itself; the discipline note in STATE.md forbids shadow-replacement); make policy decisions without maintainer authorization (escalate clarification instead); modify STATE.md unilaterally without explicit user authorization (state mutations require authorization, observations that state should change are themselves escalations).
---

# Escalation Watch

Supervisor-side companion for /goal (Codex). When /goal escalates and goes dormant, you (Claude) are the supervisor-proxy: you watch for the escalation, surface it to the maintainer with enough context to decide, draft the RESOLVED line per the per-file protocol, and keep the audit trail (STATE.md, FRICTIONS.md) coherent.

This skill exists because the supervisor↔/goal loop is the load-bearing coordination boundary in this workflow, and getting it wrong creates re-litigation, shadow-replacement, and context-gap frictions (see F-003, F-004, F-007 in `FRICTIONS.md`).

## What this skill is for

Three distinct moments where the supervisor engages with an escalation:

1. **Detection.** /goal writes a new `ESCALATION-<ts>.md` file in `.planning/auto-execution/escalations/`. You need to know it happened — usually via `~/.local/bin/escalation-poller.sh` running in a separate terminal with osascript notifications, or by re-running it `--once` between turns.

2. **Adjudication.** Read the escalation file end-to-end. Decide: can you respond on the maintainer's behalf with policy already on file (e.g., "all addressed CR findings declined per ADR-001"), or is this a maintainer-only call (e.g., "merge this PR")? Default to maintainer-only for merges, branch-pushes-against-protected-branches, and any architectural reframe.

3. **Resolution.** Write a `RESOLVED:` line to the escalation file per the EXECUTION-MODEL §"User-resolved escalation" protocol. Update STATE.md `## Active escalation` block and the relevant `## Notes` line.

## The per-file resolution protocol (binding)

Per `.planning/EXECUTION-MODEL.md` §"User-resolved escalation":

- **Formal mechanism:** append a single line to the escalation file at column 0:
  ```
  RESOLVED: <ISO8601-utc> <one-line note>
  ```
- **Chat shortcuts** (e.g., maintainer typing "escalation resolved" in chat) are extra-protocol. Per F-003 adjudication, they are **valid only if scope is explicit when multiple escalations are open**. Generic "escalation resolved" with multiple open requires you to escalate clarification rather than proxy.
- **Multi-gate cases** require explicit per-gate signal or explicit "all open escalations resolved" wording.

Wrong moves (do not do these):

- Modifying STATE.md to retroactively change a COMPLETE → IN_PROGRESS based on a re-interpretation of a prior chat shortcut. State mutations require authorization; if you think state needs to change, write a clarifying escalation instead. (See GOVERNANCE NOTE in STATE.md, 2026-05-14T19:30Z.)
- Writing the RESOLVED line based on your own assumption that the maintainer would approve. Always either (a) cite the exact maintainer signal received, or (b) escalate clarification.
- Doing /goal's per-repo P7-T<n>-3/-4/-5 work on /goal's behalf during a pause. This is the "shadow-replacement" anti-pattern documented in STATE.md `## Discipline note for /goal resume`. Supervisor handles policy-level escalations only.

## Workflow

### Step 1 — Start the poller (once per session)

```
~/.local/bin/escalation-poller.sh \
  --dir /Users/rookslog/Development/agentic-ops/.planning/auto-execution/escalations \
  --interval 30
```

Run in a separate terminal so it persists across your turns. Notifications fire via macOS osascript with the "Submarine" sound. Logs to `/tmp/escalation-poller.log`.

If running headless (no notifications), use `--once` mode between turns to scan for changes:

```
~/.local/bin/escalation-poller.sh --dir <path> --once
```

### Step 2 — When an escalation fires

Read the escalation file in full. Extract:

- **Task ID** (e.g., `P7-T2-5`) — confirm against STATE.md `current_task_id`.
- **What was attempted** — the actions /goal took before escalating.
- **Observed state** — the deterministic facts (PR state, CI status, CR/Codex status, mergeStateStatus).
- **Failure / gate** — why /goal stopped.
- **Suggested user action** — /goal's proposed maintainer-signal wording.

### Step 3 — Adjudicate

Three buckets:

1. **Maintainer-only.** Surface to user with a 1-2 sentence summary + the PR URL + the suggested signal. Do not draft a response yourself. Examples: merge gates, branch-protection bypass requests, architectural reframes.

2. **Policy-on-file.** You can respond per existing ADR/EXECUTION-MODEL/STATE.md GOVERNANCE NOTE. Draft the RESOLVED line, surface to user for confirmation before writing.

3. **Ambiguous.** Per F-003 protocol, escalate clarification. Write a follow-up escalation file `ESCALATION-<ts>.md` with the clarifying question rather than guessing.

### Step 4 — Write the RESOLVED line

After maintainer signal received, append to the escalation file:

```
RESOLVED: 2026-05-14T20:55:00Z maintainer signal "Merge arxiv-sanity-mcp PR #2" received in chat at 2026-05-14T20:54Z; scope is explicit (one PR named); proceeding with merge per P7-T2-5.
```

The line should:
- Cite the exact maintainer wording.
- State the scope (which file/PR/task this resolves).
- Reference the next action /goal will take on resume.

### Step 5 — Sync STATE.md

Update STATE.md sections in this order:

1. `## Active escalation` block — flip `resolved: false` → `resolved: true`, add the resolution timestamp.
2. `## Notes` — append the resolution note to the existing per-task note line (e.g., `P7-T2-5 arxiv-sanity-mcp ESCALATED ...` becomes `P7-T2-5 arxiv-sanity-mcp RESOLVED 2026-05-14T20:55:00Z ...`).
3. `**Last updated**` — bump to current UTC timestamp.
4. `**Status:**` — flip from `escalated (...)` back to `active` (or whatever the next task_status warrants).

Do not modify task COMPLETE entries retroactively. They are immutable audit records.

### Step 6 — Signal /goal to resume

If /goal is in a separate Codex session, the maintainer is responsible for re-prompting it (typically with "resume from STATE.md current_task_id"). You don't proxy this — but you can offer to draft the resume prompt for the maintainer to paste.

## Friction-tracking responsibilities

Each escalation cycle is an opportunity to capture systemic friction:

- If you noticed something /goal could have handled but punted on (e.g., a CR finding that has a documented response template), consider whether to capture it as an `F-NNN` entry in `FRICTIONS.md`.
- If you noticed a coordination problem between supervisor and /goal (e.g., context gap, ambiguous shortcut, premature escalation), capture as `F-NNN`.
- If the same escalation pattern recurs across multiple PRs (e.g., template-level CR findings — see F-002), the systemic fix likely belongs in ONBOARDING.md or a kernel-side template change.

## Cross-references

- **Per-file resolution protocol:** `.planning/EXECUTION-MODEL.md` §"User-resolved escalation"
- **Discipline note:** `.planning/auto-execution/STATE.md` §"Discipline note for /goal resume"
- **Governance note:** `.planning/auto-execution/STATE.md` §"GOVERNANCE NOTE (2026-05-14T19:30Z, retroactive)"
- **Friction inventory:** `FRICTIONS.md` (PR #19 pending merge as of 2026-05-14)
- **Open questions:** `OPEN_QUESTIONS.md` (OQ-12 install/onboarding shape; OQ-13 extra_allowed_tools policy gap)
- **Poller script:** `~/.local/bin/escalation-poller.sh`
- **/goal-side companion:** see `.planning/auto-execution/goal-prompt-amendment.md` for the dormancy protocol /goal should run on its side
