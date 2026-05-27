# P4 — Visualize stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p4-visualize`
- **Predecessor:** P3 merged + `CHECKPOINT-P3.md` written
- **Lab clip:** `lab/outputs/p4-visualize-<ts>.mp4`
- **HUMAN-GATE:** HUMAN-GATE-3 (creative review: opacity, position, energy)

## Scope

Build `erebus/stages/visualize.py` and the `showcqt` visualizer
in `erebus/visualizers/showcqt.py`. Overlay the audio-driven
visualizer on the graded video stream at the configured opacity
and bounded region.

## REQ-IDs in scope

- **REQ-VIZ-001 [MUST]** — Overlay at configured opacity
- **REQ-VIZ-002 [MUST]** — Bounded region (no bleed outside the
  rect)
- **REQ-VIZ-003 [SHOULD]** — Type dispatch fidelity (the
  `visualizer.type` key in preset selects the implementation)
- **REQ-ARCH-004 [MUST]** — Visualizer dispatch via a single
  module per type

## Anchor tests (smallest-viable-first)

1. `test_visualizer_opacity_within_tolerance` (REQ-VIZ-001) —
   **land first**. Render reference clip with `opacity=0.55`;
   sample pixels in the overlay region; assert blend matches
   target within ±0.05.
2. `test_visualizer_does_not_bleed_outside_region` (REQ-VIZ-002)
   — sample pixels outside the configured rect; assert
   unchanged from input.
3. `test_new_visualizer_type_requires_only_one_module`
   (REQ-ARCH-004) — meta-test: add a stub `avectorscope` type
   and assert dispatch routes correctly.

## Task overview

1. **P4-T1 — Failing opacity test.**
2. **P4-T2 — Implement `erebus/visualizers/showcqt.py`** with
   the parameters from the cyberpsycho preset (basefreq, endfreq,
   bar_g, sono_g, font, font_size).
3. **P4-T3 — Implement `erebus/stages/visualize.py`** that
   dispatches by `visualizer.type` and composes the overlay
   via the builder.
4. **P4-T4 — Bleed test + verify bounded region.**
5. **P4-T5 — Dispatch meta-test + verify type fidelity.**
6. **P4-T6 — Lab clip + HUMAN-GATE-3.**
7. **P4-T7 — On approve: open PR, address review, signal merge.**

## Dependencies

- **Upstream:** P3 grade (graded video stream + cyberpsycho
  preset's `[visualizer]` block)
- **Downstream:** P5 caption (caption overlays on top of the
  visualizer-applied frames)

## Postconditions

- All 3 P4 anchor tests pass.
- `erebus.stages.visualize.run(...)` works.
- `erebus.visualizers.showcqt.build(...)` returns a builder
  fragment.
- Lab clip approved.
- PR merged.

## Deferred backlog items folded in

- None directly. P4 picks up the dispatch test which is
  cross-cutting; backlog items relating to other visualizer
  types defer to Phase-2 (Phase-1 ships only `showcqt`).

## Notes

- `showcqt` is ffmpeg's `showcqt` filter; documentation at
  https://ffmpeg.org/ffmpeg-filters.html#showcqt. The cyberpsycho
  preset's values come from PROJECT.md §5.
- The Rajdhani font (REQ-CAPTION fonts) is also referenced by
  `showcqt` for axis labels. P4 may need to pull in the font
  before P5 ships — coordinate with HUMAN-GATE-3 review.
