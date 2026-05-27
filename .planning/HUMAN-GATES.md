# Human-attention triggers

Points where the autonomous agent halts and waits for Logan.
Listed in expected order of encounter. Each gate writes an
escalation file and invokes the dormancy wait script per
`EXECUTION-MODEL.md` §"Dormancy contract".

The general principle: the agent handles mechanical work; Logan
handles creative direction, subjective quality, identity /
credential issues, and any decision whose blast radius is
unclear.

## HUMAN-GATE-1 — `/goal` launch authorization

**When.** Once, at the start of Phase-1. After PR #3 (this
orchestration setup) merges, Logan opens codex, pastes
`.planning/auto-execution/GOAL_PROMPT.md`, and types `GO`. The
gate is implicit: /goal does not exist until Logan launches it.

**Status:** pending until PR #3 merges.

## HUMAN-GATE-2 — First-PR validation run

**When.** After /goal opens its first PR under the orchestration
setup (PR #3, the walking skeleton or P1 ingest depending on P0
decomposition).

**Why.** First end-to-end run of the autonomous loop. Logan
watches closely:

- Does /goal open the PR with the expected scope?
- Does CI go green?
- Does the codex bot post a review?
- Does the Claude monitor session triage and address findings?
- Does the monitor merge cleanly?

**Resolution path.** Logan reviews the PR, watches it land, and
either (a) writes `RESOLVED: <ts> orchestration loop validated;
continue` on the validation-escalation file, or (b) writes a
diagnostic escalation if something looked wrong.

After this gate, subsequent PRs run without HUMAN-GATE-2-style
close watching. Lab-clip reviews (HUMAN-GATE-3) remain.

## HUMAN-GATE-3 — Lab clip review (per stage)

**When.** At the end of P1–P7, before the phase checkpoint is
written. Each stage produces a lab clip via
`erebus lab apply --stage <name> ...` (REQ-LAB-001/-002). The
clip lands at `lab/outputs/<filename>.mp4` and is referenced in
the PR body.

**What Logan does.** Plays the clip, judges the stage's
output:

- P1 (ingest): does the ingested clip have the expected
  metadata? Did chapter extraction work where present?
- P2 (concat): does the concatenated stream have correct
  total duration and no transition glitches?
- P3 (grade): does the cyberpsycho grading look cyberpunk?
  Tune preset values if not.
- P4 (visualize): does the showcqt overlay fit the bottom-
  center region? Is the opacity right?
- P5 (caption): is the track name readable? Does the fade
  feel right?
- P6 (mix): is the music dominant? Is the video audio
  audibly low-passed?
- P7 (encode): does the output mp4 play with correct
  resolution and framerate?

**Resolution path.**

- Approve → write `RESOLVED: <ts> lab clip approved for <stage>`
  → /goal writes the checkpoint and proceeds.
- Tune → write a `RESOLVED: <ts> tune <preset-key>: <old> → <new>;
  re-render and re-escalate` → /goal updates the preset, re-runs
  the lab clip, re-escalates.
- Reject → write `BLOCKED: <ts> <reason>; defer to Phase-2` →
  /goal marks the stage as partially-complete in STATE.md and
  proceeds. Phase-completion review will flag this.

## HUMAN-GATE-4 — Cyberpsycho preset tuning (cumulative)

**When.** Mid-Phase-1, when multiple stage outputs need
co-tuning (e.g., grade interacts with visualizer opacity). Logan
may request a tuning escalation at any lab-clip review by
including `tune-multi:` in the RESOLVED line.

**What Logan does.** Reviews the cumulative preset state across
stages, decides which knobs to adjust, signals back.

This gate is opt-in by Logan; /goal does not preemptively
escalate.

## HUMAN-GATE-5 — `claude -p` deep-reasoning escalation

**When.** /goal hits an architectural decision it can't settle
from existing REQ-IDs and ADRs. Writes an escalation with
`kind: needs-deep-reasoning`. The orchestrator can invoke
`claude -p` directly with the escalation file as input (see
0011-phase-1-orchestration.md §"Claude `-p` invocation"), but
the supervisor session (Claude monitor) typically reviews the
claude-p response before signaling resume.

**What Logan does.** Usually nothing — the supervisor handles
this loop. Logan is surfaced only if the supervisor sees a
disagreement between codex's hypothesis and claude-p's
analysis.

**Resolution path.** Supervisor writes the RESOLVED line based
on claude-p's response, or escalates to Logan if there's an
unresolvable disagreement.

## HUMAN-GATE-6 — Monitor merge blocked

**When.** Monitor session detects a PR that passes 6 of 7
merge preconditions but fails 1 in a way the monitor can't
resolve (e.g., codex bot review thread requesting clarification
on a design choice). Writes an escalation with
`kind: monitor-merge-blocked`.

**Resolution path.**

- If the failed precondition is a thread the codex orchestrator
  can address (e.g., "add a unit test for this edge case"),
  monitor escalates to /goal as a new task. /goal addresses,
  pushes, monitor re-checks.
- If the failed precondition needs Logan (e.g., a security
  question), monitor escalates to Logan directly.

## HUMAN-GATE-7 — Final phase-completion lab review

**When.** End of P8 (integration), before P9 writes DONE.md.

**What Logan does.** Plays the final end-to-end cyberpsycho
render on the supplied playlists. Judges whether Phase-1's
verification surface (PROJECT.md §4) is met to a quality bar
Logan is happy with.

**Resolution path.**

- Approve → write `RESOLVED: <ts> Phase-1 approved; proceed to
  P9` → /goal writes DONE.md and the phase-completion review
  artifact.
- Defer remaining tuning → write `RESOLVED: <ts> approve with
  Phase-2 tuning deferrals: [...]` → /goal records the deferrals
  in NOTES.md and proceeds.
- Reject → escalate to a re-plan ADR. Phase-1 stays open.

## HUMAN-GATE-8 — OAuth / API issues

**When.** Anytime gh, codex CLI, or claude CLI authentication
fails or sustained API errors occur.

**What Logan does.** Rotate token if expired; investigate
Anthropic / GitHub dashboard; clear caches if needed.

This is the catch-all for "the infrastructure broke and the
agent can't proceed."
