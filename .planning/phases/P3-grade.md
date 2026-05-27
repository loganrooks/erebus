# P3 — Grade stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p3-grade`
- **Predecessor:** P2 merged + `CHECKPOINT-P2.md` written
- **Lab clip:** `lab/outputs/p3-grade-<ts>.mp4`
- **HUMAN-GATE:** HUMAN-GATE-3 (creative direction: does it look cyberpunk?)

## Scope

Build `erebus/stages/grade.py`: apply the cyberpsycho colour
grading to the concatenated video. Driven by preset values from
`presets/cyberpsycho.toml` (which P3 also lands).

This is the **first creative-direction phase**. Logan's lab-clip
review is load-bearing; the anchor tests verify mechanics, not
aesthetics.

## REQ-IDs in scope

- **REQ-GRADE-001 [MUST]** — Preset-driven filter chain (no
  hardcoded values in source)
- **REQ-GRADE-002 [MUST]** — Builder-only ffmpeg invocation
- **REQ-GRADE-003 [MUST]** — Measurable darkening (assertable
  from frame samples)

## Anchor tests (smallest-viable-first)

1. `test_grade_filter_built_via_builder_only` (REQ-GRADE-002,
   REQ-SEC-002) — **land first**. Meta-test: introspect the
   ffmpeg invocation; assert it came through `erebus/ffmpeg/builder.py`.
2. `test_cyberpsycho_darkens_reference_clip` (REQ-GRADE-003) —
   render the reference clip through grade; assert mean
   brightness drops by ≥15%.
3. `test_cyberpsycho_preserves_chrominance_shape` (REQ-GRADE-001)
   — assert chrominance histogram retains expected cyberpunk
   skew (heavy magenta/cyan).

## Task overview

1. **P3-T1 — Write `presets/cyberpsycho.toml`** with the values
   from `PROJECT.md` §5 (verbatim starting points). Schema
   validation via `pydantic` v2.
2. **P3-T2 — Failing test for builder-only invocation.**
3. **P3-T3 — Implement `erebus/stages/grade.py`** producing
   the cyberpsycho filter chain via the builder.
4. **P3-T4 — Add darkening test + verify against reference clip.**
5. **P3-T5 — Add chrominance test + verify.**
6. **P3-T6 — Render lab clip; escalate HUMAN-GATE-3 for
   creative review.**
7. **P3-T7 — On Logan's signal: either accept (write
   checkpoint) or tune (loop back to P3-T6 with adjusted
   preset values via the HUMAN-GATE-3 RESOLVED line).**
8. **P3-T8 — Open PR, address review, signal merge.**

## Dependencies

- **Upstream:** P2 concat (consumes the concatenated stream)
- **Downstream:** P4 visualize (consumes the graded video frame
  stream), P6 mix (consumes the graded video's audio track)

## Postconditions

- All 3 P3 anchor tests pass.
- `presets/cyberpsycho.toml` exists, validates against the
  preset schema, and matches PROJECT.md §5 (modulo any
  HUMAN-GATE-3 tuning).
- `erebus.stages.grade.run(input_path, preset, output_path) -> Path`
  works.
- Lab clip committed and approved.
- PR merged.

## Deferred backlog items folded in

- 0005 F-16 — REQ-ENCODE-002 framerate placement (P3 or P7?)
  (KEEP; resolved here if grade owns framerate normalization, or
  deferred to P7 if encode owns it. /goal decides in expanded task
  spec.)
- 0007 F-14 — mypy strict redundant sub-flags (DROP; cosmetic)

## Notes

- Preset tuning is iterative. The HUMAN-GATE-3 loop may take 3-5
  passes before Logan approves. Each pass: tune values, re-render,
  re-escalate. The dormancy contract holds throughout — no
  token churn between iterations.
- The cyberpsycho preset's chrominance balance is the most
  subjective dimension. If Logan can't articulate the tuning
  delta in words, the escalation gets `kind: creative-direction`
  and Logan adjusts the TOML directly.
