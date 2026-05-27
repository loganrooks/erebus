# 0011 — Phase-1 autonomous orchestration

- **Status:** proposed
- **Date:** 2026-05-25
- **Author(s):** Logan + Claude Code (interactive drafting session)
- **Related REQ-IDs:** REQ-INTEG-001 (Phase-1 end-to-end verification),
  REQ-DOC-003 (ADRs), REQ-SEC-003 (no secrets in repo)
- **Related anchors:** none yet — orchestration infrastructure is
  policy + scripts, not tested behaviour. `test_phase1_integration`
  is the eventual evidence anchor for the orchestration succeeding.
- **Supersedes:** n/a

## Context

Goal-0 closed on 2026-05-25 with PR #1 merged. The repo, CI,
branch protection, templates, and the post-setup audit artifact
are all in place. Goal-1 — Phase-1 MVP pipeline — is the next dev
target. Per [PROJECT.md §4](../../PROJECT.md), Phase-1 delivers
the seven stages (ingest, concat, grade, visualize, caption, mix,
encode) at minimum-viable quality, the `cyberpsycho.toml` preset,
and end-to-end `erebus render --preset cyberpsycho ...` working
on the supplied playlists.

Phase-1 spans many PRs over weeks. Manual orchestration of each
PR — branching, anchor-test-first discipline, stage-build,
lab-clip review, codex review, merge — is slow and error-prone.
The goal of this ADR is to set up autonomous execution with the
following properties:

1. **Maximum automation.** Codex orchestrates the work via the
   `/goal` mechanic. Codex opens PRs, pushes commits, writes
   tests, runs locally, and signals when it needs help.
2. **Cross-vendor risk mitigation.** Codex's blind spots are
   covered by Claude (via `claude -p` for load-bearing
   reasoning) and by the GitHub `@codex review` bot for diff
   review. Claude blind spots are covered by codex's grinding
   discipline and the bot's mechanical-rules pass.
3. **Zero-token-while-waiting.** Codex burning tokens on
   stop-hook continuations while waiting for a PR review or CI
   to finish is the dominant failure mode of naive `/goal`
   setups. The dormancy contract (foreground blocking script,
   same turn as the action that triggered the wait) is the fix.
4. **Mechanical merge gating.** Branch protection plus an
   automated monitor session that approves and merges only when
   hard preconditions are met. The monitor is Claude (separate
   session from the codex orchestrator) using project skills
   `escalation-watch` and `pr-review-triage`.
5. **Human-gate preservation for creative direction.** Codex
   cannot judge whether the cyberpsycho grading looks cyberpunk,
   whether the visualizer has the right energy, or whether a
   lab clip is ready to commit. Those decisions stay with Logan
   via the escalation mechanism.

### Prior art

`loganrooks/agentic-ops` is a sibling project that has run
multi-phase autonomous execution under codex `/goal`. Its
five-pass friction inventory documented the failure modes:

- `F-007` — supervisor↔/goal coordination loop. Without an
  explicit dormancy contract, an escalating executor either
  hard-halts (losing in-context state) or starts the next
  ready-looking task (shadow-replacing the supervisor). The
  systemic fix landed in [`agentic-ops@36824a5`](https://github.com/loganrooks/agentic-ops/commit/36824a5)
  as an `EXECUTION-MODEL.md` §"Escalation dormancy contract"
  with a paired `wait-for-resolution.sh` script. The script
  blocks codex's turn via `fswatch -1` (event-driven on macOS,
  polling fallback otherwise). Zero tokens are consumed while
  blocking because codex's turn never ends.
- `F-008` — high-reasoning merge gate. Codex's diff review is
  fast but shallower than claude-opus extended-thinking. For
  load-bearing decisions (architecture choices, security
  surfaces, REQ-ID re-shaping), an escalation to `claude -p`
  with max reasoning is the right tool.
- `F-003` — ambiguous chat shortcuts. The supervisor must not
  proxy maintainer signals when scope is ambiguous; escalate
  clarification instead.

This ADR adopts the F-007 pattern (dormancy contract,
foreground blocking script). It adapts the F-008 pattern
(claude -p escalation) for orchestration-time reasoning. It
inherits the F-003 discipline implicitly through the
`escalation-watch` skill on the supervisor side.

agentic-ops is acknowledged here as structural inspiration, not
as a copy-source. Its planning surface accumulated artifacts
(INITIATIVE.md, PHASE-MAP.md, RISK-REGISTER.md as separate
files, multiple decimal-point "hotfix" phases) that reflect its
specific scaling history. erebus starts with a tighter
structure.

## Decision

Phase-1 runs as an autonomous codex `/goal` execution with the
following architecture.

### Role split

| Role | Vendor / surface | Primary tools | Job |
|---|---|---|---|
| Orchestrator | Codex CLI under `/goal` | gh, git, ffmpeg, uv, pytest, claude -p | Sequences phase-by-phase work; writes anchor tests; implements stages; opens PRs; writes escalations |
| Diff reviewer | `@codex review` GitHub bot | n/a (automatic) | Cold-reads each PR; posts findings |
| Deep reasoner | `claude -p` (Opus with max reasoning) | invoked by orchestrator with read-only tools | Adjudicates load-bearing decisions (architecture, security, design) when codex emits a `needs-deep-reasoning` escalation |
| Supervisor / Monitor | Claude Code (separate session, Logan's interactive surface) | escalation-watch skill, pr-review-triage skill, Monitor tool | Watches escalations; triages codex-bot findings; approves and merges PRs when hard preconditions are met; surfaces HUMAN-GATE escalations to Logan |
| Maintainer | Logan | manual | Resolves HUMAN-GATE escalations; reviews lab clips; tunes the cyberpsycho preset |

The cross-vendor property is preserved by codex as orchestrator
+ codex-bot as diff reviewer (single-vendor diff perspective) +
claude-p as deep reasoner (different vendor for design
decisions) + claude monitor (different vendor for merge gating).

### State on disk

All execution state lives under `.planning/`:

- `EXECUTION-MODEL.md` — driver loop, escalation procedure,
  dormancy contract, done detection. The contract codex reads
  on every `GO`.
- `GUARDRAILS.md` — orchestration-specific hard rules (general
  dev rules live in AGENTS.md and are not duplicated).
- `HUMAN-GATES.md` — points where /goal must halt for Logan.
- `RISK-REGISTER.md` — known autonomy risks and their
  mitigations.
- `phases/P0-bootstrap.md` through `phases/P9-final.md` —
  one file per phase. Skeleton form: stage scope, REQ-IDs,
  anchor tests, lab-clip gate. Atomic task decomposition
  with mechanical postconditions is `/goal`'s P0 task.
- `auto-execution/` — runtime state. `GOAL_PROMPT.md`
  (paste-into-codex artifact), `STATE.md` (single source of
  truth, mutated atomically), `SESSION-LOG.md` (append-only),
  `ESCALATIONS.md` (index), `ARTIFACTS.md` (file registry),
  `CHECKPOINTS.md` (phase-completion summaries), plus
  `escalations/`, `checkpoints/`, and `sessions/`
  subdirectories.

The `.planning/` root is chosen for compatibility with the
existing `escalation-watch` skill, which expects
`.planning/auto-execution/escalations/`.

### Phase decomposition

Ten phases, each landing as a separate PR (or pair of PRs where
the work is naturally split):

| Phase | Goal | Branch prefix |
|---|---|---|
| P0 | Bootstrap auto-execution state; draft atomic task specs for P1–P9 | `phase/p0-bootstrap` |
| P1 | `ingest` stage — playlist ingestion, archive dedup, manifest | `phase/p1-ingest` |
| P2 | `concat` stage — lossless concat when possible | `phase/p2-concat` |
| P3 | `grade` stage — cyberpsycho colour grading | `phase/p3-grade` |
| P4 | `visualize` stage — showcqt overlay | `phase/p4-visualize` |
| P5 | `caption` stage — track-name overlay with fade | `phase/p5-caption` |
| P6 | `mix` stage — two-stream amix with lowpass | `phase/p6-mix` |
| P7 | `encode` stage — final mp4 (libx264 / aac) | `phase/p7-encode` |
| P8 | `integration` — end-to-end `erebus render` on supplied playlists | `phase/p8-integration` |
| P9 | `done` — verify all REQ-IDs covered; write DONE.md; tune cyberpsycho preset; merge | `phase/p9-final` |

Stage ordering follows the build-time dependency graph (see
`PHASE-MAP` section in EXECUTION-MODEL.md): each later stage
consumes the output of an earlier one in the production
pipeline. The `caption` and `mix` stages both depend on
upstream stages but on each other only at integration time;
either order works.

### Dormancy contract (zero-token-while-waiting)

When `/goal` awaits an external event (CI completion, codex
review, monitor merge, maintainer escalation resolution), it
must invoke a foreground blocking script **in the same turn**
as the action that created the wait. Three script families
exist:

| Script | When invoked | Wakes on |
|---|---|---|
| `.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh <ESCALATION-FILE>` | After writing an escalation file | `RESOLVED:` or `BLOCKED:` line in the file (fswatch event-driven on macOS) |
| `scripts/wait-for-ci-green.sh <PR-NUM>` | After pushing to a PR branch | All 7 required CI checks reach a terminal state |
| `scripts/wait-for-codex-review.sh <PR-NUM>` | After CI green, before requesting merge | `@codex review` bot posts a review on the PR |
| `scripts/wait-for-pr-merge.sh <PR-NUM>` | After review threads resolved | PR `state == MERGED` (the Claude monitor session is what actually merges) |

Each script:

- Blocks codex's turn without invoking the model (zero tokens
  while waiting)
- Has a 4-hour default timeout, after which it writes a
  follow-up escalation rather than failing silently
- Returns exit codes that encode the resolution (0 success,
  1 known terminal failure, 2 timeout)

The dormancy contract is enforced by `GUARDRAILS.md` ("when
STATE.md flips to AWAITING_EXTERNAL or AWAITING_HUMAN, the
same turn must end with a wait-for-X.sh invocation"). Codex
reads `GUARDRAILS.md` on every `GO`, so the contract is
always in force.

### Merge gating

PRs merge automatically when **all** of the following are
true (encoded in `scripts/wait-for-pr-merge.sh` and the
Claude monitor session's pre-merge check):

1. `gh pr view N --json mergeable` returns `"MERGEABLE"`.
2. All 7 required CI checks pass (`lint-and-type`,
   `test-unit-meta (ubuntu-latest)`, `test-unit-meta
   (macos-latest)`, `test-integration`, `gitleaks`,
   `docs-consistency`, `review-artifact-exists`).
3. The `@codex review` bot has posted at least one review
   (i.e., review actually happened — don't merge before the
   reviewer had a chance).
4. Zero unresolved review threads (codex bot's findings,
   monitor's own triage comments, any human reviewer's).
5. No new commits in the last 5 minutes (prevents merging
   mid-push).
6. The PR does not carry a `do-not-merge` label.
7. PR body includes a verified `REQ-ID:` line matching a
   Phase-1 REQ in REQUIREMENTS.md.
8. **MCI consistency gate.** A cheap Haiku call scores the
   PR title + body against the diff stat; the consistency
   score must be ≥ 0.3. Per the F5 finding in the
   AgenticOpsResearch synthesis
   ([`system-design/04-ai-failure-mitigation.md` §3.5](https://github.com/loganrooks/Documents/Claude/Projects/AgenticOpsResearch/system-design/04-ai-failure-mitigation.md)),
   Message-Code Inconsistency is the most actionable
   single-signal predictor of PR defects: PRs whose
   description doesn't match the diff drop from 80%
   acceptance to 28%. Cost: ~$0.001 per check.

Any one failing → no merge. The monitor posts a status
comment naming the failed precondition and continues to wait.

### Relaxation of the "agent never merges" rule

Both `AGENTS.md` (non-negotiable rules) and `WORKFLOW.md` §3
currently say:

> Only the human merges. The agent never merges its own PRs.

This ADR relaxes that rule with a single explicit carve-out:

> The Claude monitor session may merge a PR when and only when
> all eight merge-gating preconditions in 0011-phase-1-orchestration.md
> are satisfied. No other agent — including the codex
> orchestrator that opened the PR — may merge.

The asymmetry is deliberate: codex opens, claude merges. A
single vendor never both writes and approves its own work.

**Precedent.** This carve-out follows
[`agentic-review-loop` ADR-001 (Autonomous execution under bot-review gates)](https://github.com/loganrooks/agentic-review-loop/blob/main/docs/adr/ADR-001-autonomous-execution-policy.md),
which inverts the same agentic-ops-kernel rule on three justifications
that also apply to erebus:

1. **Roadmap fully specified at bootstrap.** Phase-1 scope, REQ-IDs,
   anchor tests, and acceptance criteria are pre-committed in
   PROJECT.md, REQUIREMENTS.md, and TEST_SPEC.md. No open architectural
   questions remain for the maintainer to adjudicate mid-stream —
   those that exist are HUMAN-GATE escalations.
2. **Deliverable surface does not fan out to consumers via floating
   tag.** Phase-1 produces a CLI + Python library; it does not get
   consumed by downstream repos through a moving `v1`-style reference.
   Bugs caught late are recoverable by follow-up PR; they do not
   propagate silently.
3. **The Claude monitor session is the production-grade pre-merge
   check.** Once the monitor is running, the maintainer's per-PR
   inspection role is replaced by mechanical-gate verification.
   The monitor's job is exactly this.

Conditions under which this relaxation holds — all of which the
monitor enforces mechanically via the eight preconditions:

- Bot review still runs (`@codex review` posts on every PR)
- Bot findings still get addressed or rejected with rationale
  (zero unresolved threads precondition)
- CI still passes (all 7 required checks green precondition)
- Branch protection still enforces (`gh pr merge --admin` is the
  bypass, but only when preconditions are met; admin is not used
  to skip the check itself)
- MCI consistency gate verifies the PR body matches the diff
  (precondition #8)

If any condition slips, the monitor does not merge. It posts a
status comment naming the failed precondition and continues to
wait.

The merge action happens under Logan's GitHub credentials
(attribution problem). A bot identity (GitHub App or PAT for a
dedicated bot user) is the clean long-term fix and is deferred
to a later milestone once Phase-1 PRs are flowing and the
attribution noise becomes actionable.

### Claude `-p` invocation for load-bearing decisions

When codex hits an architectural decision it doesn't have
strong evidence to settle (e.g., "should `concat` use the
demuxer or `-c copy`?"), it emits an `ESCALATION-<ts>.md`
tagged `kind: needs-deep-reasoning`. The escalation file
includes:

- The decision point
- Codex's current best guess
- The evidence already gathered
- Specific REQ-IDs the decision affects

The escalation file triggers a paired invocation:

```bash
claude -p "$(cat .planning/auto-execution/escalations/ESCALATION-<ts>.md)" \
  --allowedTools "Read,Grep,Glob,Bash(uv run pytest *),Bash(git diff *)" \
  --model claude-opus-4-7 \
  --output-format text \
  --max-turns 25 \
  > .planning/auto-execution/escalations/ESCALATION-<ts>-claude-p-response.md
```

Opus with max reasoning is the default for deep-reasoning
escalations; the prompt-level instruction to "think deeply
before responding" engages the model's reasoning surface. The
response file's content gets appended
to the original escalation as the `RESOLVED:` line's content.
The orchestrator resumes when `wait-for-resolution.sh`
returns.

The supervisor (Claude monitor session) can also invoke
`claude -p` directly when adjudicating a particularly thorny
codex-bot finding it doesn't have confidence to triage alone.

### Phase-1 deferred backlog (39 items)

The five-pass pre-setup audit deferred 39 items to Phase-1.
They are listed verbatim in
[`.planning/phases/P0-bootstrap.md`](../../.planning/phases/P0-bootstrap.md)
with a triage column (KEEP / DEFER-TO-PHASE-2 / DROP) that
`/goal` populates as its P0 task. Distribution:

- mix: 5 (loudness measurement, dominance assertion, lowpass infeasibility, duration semantics, loudnorm parameterization)
- concat: 4 (lossless heuristic, REQ-CLI-002 trim placement, bitrate proxy, concat contract)
- ingest: 2 (yt-dlp resolution, REQ-INGEST-001/-005 carve-out)
- caption: 3 (font provenance, fade extraction method, fade surface)
- encode/grade: 2 (deterministic mp4 flags, framerate placement)
- CI: 6 (hook bumps, version floors, hatchling pin, gitleaks redundancy, macOS ffmpeg skip, recovery procedure)
- lab: 2 (filename collision, .gitkeep cosmetic)
- docs: 5 (anchor dead-links, REQUIREMENTS.md voicing, stub-file mypy guidance, review-artifact discovery, ADR template carve-out)
- other (architecture / observability / test): 3 (orchestrator API, schema-defaults carve-out, stdout/stderr inversion)

The plan ADR does not pre-triage these. /goal does it in P0
because the triage decisions need codex's read of the live
docs as of P0 execution time, not as of this ADR's
authorship.

## Consequences

### New files

- `docs/decisions/0011-phase-1-orchestration.md` (this file)
- `.planning/EXECUTION-MODEL.md`
- `.planning/GUARDRAILS.md`
- `.planning/HUMAN-GATES.md`
- `.planning/RISK-REGISTER.md`
- `.planning/phases/P0-bootstrap.md` through `P9-final.md`
- `.planning/auto-execution/GOAL_PROMPT.md`
- `.planning/auto-execution/STATE.md` (template)
- `.planning/auto-execution/{SESSION-LOG,ESCALATIONS,ARTIFACTS,CHECKPOINTS}.md` (templates / placeholders)
- `.planning/auto-execution/{escalations,checkpoints,sessions}/.gitkeep`
- `.agents/skills/escalation-dormancy/SKILL.md`
- `.agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh`
- `.claude/skills/escalation-watch/SKILL.md` (project-scoped copy of the personal skill)
- `scripts/escalation-poller.sh`
- `scripts/wait-for-ci-green.sh`
- `scripts/wait-for-codex-review.sh`
- `scripts/wait-for-pr-merge.sh`

### Doc updates

- `AGENTS.md` — lift "agent never merges" with the monitor
  carve-out; add a "Hard rules" line pointing at the
  dormancy contract in EXECUTION-MODEL.md.
- `WORKFLOW.md` — update §3 (merge rule) with the carve-out;
  add a new section on autonomous-execution orchestration;
  update §5 (review checkpoints) to include the monitor's role.

### Code updates

None at this point. Orchestration infrastructure is
policy + scripts; product code lands in P1–P8 under the
infrastructure this ADR sets up.

### Tests / anchors

No new anchor tests at this point. The orchestration scripts
get exercised by P0 as a smoke test (codex's first task under
`/goal` is to verify the dormancy round-trip works). The
existing `test-meta` suite continues to enforce REQ↔anchor
coverage as Phase-1 stages land.

### Workflows that change

- PR review: codex review bot fires automatically on PR open;
  monitor session triages findings; monitor merges when
  preconditions met. Logan is no longer the manual approver
  for routine Phase-1 PRs (but remains the escalation
  responder).
- Branch protection: unchanged. The monitor uses
  `gh pr merge --admin` to bypass the approving-review
  requirement (carve-out documented above).
- Phase-completion review: per WORKFLOW.md §5, runs at the
  end of Phase-1 as a deep `claude -p` audit. Unchanged.

### Risks introduced

- **Monitor session approves and merges a bad PR.** Mitigated
  by the 7 hard preconditions; further mitigated by codex's
  bot review running on every PR. Residual risk: if the bot
  misses a defect and CI is green, monitor merges. The
  phase-completion review at end of Phase-1 is the catch-net.
- **Attribution problem.** Monitor merges as Logan via gh
  credentials; audit trail says "Logan merged" when really
  the monitor did. Deferred to a bot-identity milestone.
- **Codex /goal session loses context mid-phase.** Mitigated
  by STATE.md as single source of truth; session-resume
  protocol re-reads STATE on every GO.
- **Wait scripts hang past 4-hour timeout.** Mitigated by
  the timeout-writes-follow-up-escalation contract.

### Risks mitigated

- **Token waste during waits.** F-007 dormancy contract.
- **Missed escalations.** `escalation-poller.sh` running in
  Logan's terminal + monitor session watching the
  escalations directory.
- **Codex-bot blind spots on design questions.** `claude -p`
  escalation path for load-bearing decisions.
- **Diff-review collusion (same vendor builds and approves).**
  Cross-vendor split: codex orchestrates, codex-bot reviews,
  claude monitors and merges.

## Alternatives considered

### Alternative A: Manual Phase-1 execution

Logan drives each PR through normal interactive Claude Code
sessions. No autonomy, no /goal, no monitor.

Why rejected: explicit user goal is "launch /goal and sit
back." Phase-1 is 8+ PRs over weeks; manual driving is a
real cost. The infrastructure investment in this ADR pays
off across all those PRs and into Phase-2+.

### Alternative B: Claude-driven orchestration (no codex)

Claude Code with a long-horizon goal contract drives Phase-1.
No codex, no `/goal` mechanic. Use ScheduleWakeup / Monitor /
TaskCreate to manage cadence.

Why rejected: loses the cross-vendor property. A single
vendor authoring AND reviewing AND merging is the collusion
risk we're trying to avoid. Also, codex's `/goal` is
specifically designed for evidence-based long-horizon work;
claude lacks an equivalent durable-contract surface.

### Alternative C: Codex orchestration without the dormancy contract

Use `/goal` but skip the foreground-blocking wait scripts.
Let `/goal` poll naturally between turns. Cheaper to set up.

Why rejected: this is the F-007 failure mode in agentic-ops.
Each "is it ready yet?" turn costs tokens. Over a multi-PR
Phase-1 build, the waste compounds significantly. The
dormancy infrastructure is the load-bearing piece.

### Alternative D: Codex orchestration without the Claude monitor

`/goal` opens PRs and Logan merges manually. Skip the
monitor session. Simpler setup.

Why rejected: defeats the "sit back" goal. Routine PRs
(stage build + green CI + clean codex-bot review) don't
need Logan's eyes; he should only see HUMAN-GATE escalations.
The monitor session is what enables that separation.

### Alternative E: Skip the explicit cross-vendor design; use codex everywhere

Codex orchestrates, codex-bot reviews. No claude in the loop.

Why rejected: this collapses to single-vendor work. The
codex-bot is the same vendor as the orchestrator; its review
catches mechanical defects but cannot catch design-level
blind spots the orchestrator shares with it. claude as
deep-reasoner-on-escalation and as monitor-merger is the
cross-vendor hedge.

## References

- [PROJECT.md §4 Phase 1](../../PROJECT.md) — verification surface
- [PROJECT.md §5 cyberpsycho preset](../../PROJECT.md) — target values
- [REQUIREMENTS.md](../../REQUIREMENTS.md) — all Phase-1 REQ-IDs
- [TEST_SPEC.md](../TEST_SPEC.md) — all Phase-1 anchor tests
- [AGENTS.md](../../AGENTS.md) — non-negotiable rules, hard rules
- [WORKFLOW.md](../WORKFLOW.md) — current merge / review discipline
- agentic-ops F-007 systemic fix:
  [`36824a5`](https://github.com/loganrooks/agentic-ops/commit/36824a5)
  and skill commit
  [`f041a3a`](https://github.com/loganrooks/agentic-ops/commit/f041a3a)
- OpenAI cookbook on `/goal`:
  https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex
- Archived audit ADRs in `docs/decisions/archive/` — the 39-item
  deferred Phase-1 backlog lives in the closing notes of `0005`,
  `0007`, `0009`, `0010`.
