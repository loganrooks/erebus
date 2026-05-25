# P9 — Final

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p9-final`
- **Predecessor:** P8 merged + `CHECKPOINT-P8.md` written
  + HUMAN-GATE-7 resolved (Phase-1 deliverable approved)
- **Lab clip:** none (P9 is wrap-up)
- **HUMAN-GATE:** none (gated by HUMAN-GATE-7 in P8)

## Scope

Wrap up Phase-1: verify all reachable REQ-IDs have anchor
coverage, write `DONE.md`, kick off the phase-completion review,
and archive the auto-execution runtime state.

## Tasks

1. **P9-T1 — REQ↔anchor coverage audit.** Run
   `pytest -m meta` to confirm `test_every_must_req_has_anchor_citation`
   and `test_every_anchor_cites_valid_req` are green. Anchor
   `BACKLOG-TRIAGE.md` against the actually-landed REQ set:
   any KEEP item that didn't land becomes a Phase-2 entry in
   NOTES.md or a separate deferred-backlog file.

2. **P9-T2 — Phase-completion review.** Per WORKFLOW.md §5
   "Phase completion review":

   ```bash
   PHASE=1
   claude -p "Review the Phase-${PHASE} completion of erebus..." \
     --allowedTools "Read,Grep,Glob,Bash(uv run pytest *),Bash(git log *),Bash(git diff *)" \
     --model claude-opus-4-7 \
     --output-format json \
     --max-turns 50 \
     > "docs/decisions/reviews/phase-${PHASE}-completion.json"
   ```

   Render the JSON to a companion `.md` for human readability.

3. **P9-T3 — Address phase-completion findings.** If the review
   flags MUST-fix items, they get their own PRs against `main`
   (not part of P9's PR). If only SHOULD/CONSIDER, log in
   NOTES.md as Phase-2 entries.

4. **P9-T4 — Write DONE.md.** Per EXECUTION-MODEL.md §"Done
   detection":
   - completion timestamp
   - cross-references to all checkpoints
   - tasks completed (count)
   - sessions consumed (count)
   - estimated token cost
   - pointers to merged PRs and the final lab clip
   - "Recommended next steps for the human" (Phase-2 scope)

5. **P9-T5 — Archive auto-execution state.** Move runtime
   files under `.planning/auto-execution/` to
   `.planning/auto-execution/archive/phase-1/`:
   - SESSION-LOG.md
   - ESCALATIONS.md (closed escalations only; any open ones
     are a P9 escalation themselves)
   - ARTIFACTS.md
   - CHECKPOINTS.md (kept at root; the archive only holds the
     phase-specific runtime files)
   - All session snapshots under `sessions/`
   - All resolved escalations under `escalations/`

   STATE.md stays at the root with `status: done`,
   `current_phase: DONE`, for any future Phase-2 reference.

6. **P9-T6 — Open the P9 PR.** Body summarizes the phase:
   PRs merged, REQ-IDs covered, lab clips reviewed, total
   sessions, deferred backlog status, the final lab-clip
   pointer. PR merges via the same monitor path.

## Postconditions

- `pytest -m phase1` and `pytest -m meta` both pass on `main`.
- `docs/decisions/reviews/phase-1-completion.{json,md}` exist.
- `.planning/auto-execution/DONE.md` exists.
- `.planning/auto-execution/archive/phase-1/` exists with the
  archived runtime state.
- The P9 PR is merged.
- Phase-2 begins as its own goal whenever Logan initiates it.

## Notes

- DONE means "Phase-1 is complete." Phase-2 (preset expansion +
  tunability per PROJECT.md §4 Phase 2) is a separate goal.
  This ADR and its planning surface do not pre-commit Phase-2.
- The phase-completion review (P9-T2) is the place where
  Phase-1's accumulated technical debt gets named explicitly.
  It's the input to whatever Phase-2 planning looks like.
