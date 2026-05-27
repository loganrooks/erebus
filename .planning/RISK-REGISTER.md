# Risk register

Known risks for the Phase-1 autonomous build. Each entry: risk
description, likelihood (L/M/H), impact (L/M/H), mitigation,
and detection signal.

The risks here are scoped to the **autonomous-execution
machinery** (not general Phase-1 product risks; those are
implicit in REQUIREMENTS.md). They are the things that could
make the orchestration setup itself fail.

## R-001 — Token churn from naive /goal continuation

- **Likelihood:** H (primary failure mode of naive setups)
- **Impact:** M (cost, not correctness)
- **Mitigation:** Dormancy contract in EXECUTION-MODEL.md;
  GUARDRAILS rule 12; all wait scripts are foreground blockers.
- **Detection:** Codex session token usage growing without
  task completion. Supervisor monitors via `SESSION-LOG.md`
  duration-per-task; if duration is high but no postconditions
  flipped, suspect token churn.

## R-002 — Monitor session merges a defective PR

- **Likelihood:** L (7 hard preconditions; codex bot review)
- **Impact:** H (defect lands on main)
- **Mitigation:** Hard merge-gating preconditions in
  `wait-for-pr-merge.sh`; codex bot reviews every PR;
  phase-completion review at end of Phase-1 is the catch-net.
- **Detection:** Phase-completion review surfaces an issue.
  Or: a Phase-2 stage that depends on the merged stage fails
  unexpectedly and the failure mode points back at the merged
  PR.

## R-003 — Codex /goal session loses STATE.md context

- **Likelihood:** M (long sessions, context pressure)
- **Impact:** M (resume overhead; possible redo of tasks)
- **Mitigation:** STATE.md is single source of truth, mutated
  atomically; session-resume protocol re-reads it from top;
  session-end procedure writes session snapshot before halting.
- **Detection:** /goal's resume hits a state-mismatch and
  escalates with `kind: state-mismatch`. Supervisor
  reconciles.

## R-004 — Wait script hangs past 4-hour timeout

- **Likelihood:** L (timeout is the safety valve)
- **Impact:** M (codex session blocks; supervisor must notice)
- **Mitigation:** 4-hour default timeout; on timeout, the
  wait script writes a follow-up escalation and exits with
  code 2; supervisor's escalation-poller picks up the
  follow-up file.
- **Detection:** Follow-up escalation appears in
  `escalations/`. Supervisor surfaces to Logan.

## R-005 — Lab-clip review backlog (Logan unavailable)

- **Likelihood:** M (Logan has other work, time zones)
- **Impact:** M (Phase-1 throughput drops)
- **Mitigation:** Lab clips committed to `lab/outputs/` and
  linked in PR body so Logan can review asynchronously from
  any device with playback. HUMAN-GATE-3 escalation files
  include the clip path explicitly.
- **Detection:** STATE.md `task_status: AWAITING_HUMAN`
  persisting > 24h on a lab-clip gate.

## R-006 — Codex bot review misses a regression

- **Likelihood:** M (bot is fast/shallow, single-vendor blind spots)
- **Impact:** M-H (defective code merges if the monitor also misses it)
- **Mitigation:** Cross-vendor split (codex bot reviews, claude
  monitor triages); `claude -p` escalation for load-bearing
  decisions; phase-completion review at Phase-1 end with
  claude-opus extended reasoning.
- **Detection:** Per R-002 (downstream failure points back).

## R-007 — Attribution problem (monitor merges as Logan)

- **Likelihood:** H (it's the default)
- **Impact:** L (audit trail noise; no security or correctness impact)
- **Mitigation:** Acknowledged in 0011 ADR; deferred to a
  later milestone (GitHub App or bot PAT). For Phase-1,
  monitor PR-comment posts include a `[monitor-session]`
  prefix so the audit trail is recoverable from the comment
  log even though the merge commit shows Logan's identity.
- **Detection:** Logan sees a merge they didn't perform; the
  PR's comment history shows monitor activity.

## R-008 — codex bot is rate-limited or down

- **Likelihood:** L
- **Impact:** M (PRs stall in `AWAITING_EXTERNAL` waiting
  for codex review)
- **Mitigation:** `wait-for-codex-review.sh` has a 1-hour
  timeout (shorter than other wait scripts because the bot is
  usually fast); on timeout, monitor manually requests review
  via `@codex review` comment. If still no response in
  another hour → HUMAN-GATE escalation.
- **Detection:** Wait-script timeout fires.

## R-009 — claude -p extended-reasoning escalation produces a
  bad recommendation

- **Likelihood:** L
- **Impact:** M (codex acts on bad design guidance)
- **Mitigation:** claude -p response is logged in the
  escalation file and reviewed by the supervisor session
  before /goal resumes. Supervisor can re-escalate if the
  recommendation looks wrong.
- **Detection:** Phase-completion review or downstream
  failure.

## R-010 — Shadow-replacement (supervisor does /goal's work
  during DORMANT state)

- **Likelihood:** M (tempting when Claude session has time)
- **Impact:** M (state desync, re-litigation, F-007 friction)
- **Mitigation:** Explicit prohibition in EXECUTION-MODEL
  §"Prohibitions during DORMANT state"; reinforced in the
  escalation-watch skill ("Does NOT do: write production code
  on /goal's behalf").
- **Detection:** STATE.md notes from supervisor don't match
  the actual workspace state; or a task /goal expected to
  start its next session is already done.

## R-011 — Branch protection misconfiguration blocks monitor
  admin-merge

- **Likelihood:** L (admin bypass was tested on PR #1)
- **Impact:** H (PRs can't merge → Phase-1 stalls)
- **Mitigation:** Branch protection `enforce_admins: false`
  was deliberately set during Goal-0 setup specifically to
  allow admin merges. If a future ADR tightens this, the
  monitor's merge path needs reconsideration.
- **Detection:** `gh pr merge --admin` returns a permissions
  error.

## R-012 — Wait script's polling exceeds GitHub API rate limit

- **Likelihood:** L (30s default cadence, 5000 req/hr limit)
- **Impact:** L (transient; gh CLI retries with backoff)
- **Mitigation:** Default 30s polling cadence; fswatch event-
  driven where possible (file-based waits don't hit gh API
  at all). Concurrent wait scripts are bounded (only one PR
  in flight per /goal session).
- **Detection:** gh CLI errors in wait script logs.
