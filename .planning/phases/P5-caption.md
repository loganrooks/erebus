# P5 — Caption stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p5-caption`
- **Predecessor:** P4 merged + `CHECKPOINT-P4.md` written
- **Lab clip:** `lab/outputs/p5-caption-<ts>.mp4`
- **HUMAN-GATE:** HUMAN-GATE-3 (creative review: typography, fade, timing)

## Scope

Build `erebus/stages/caption.py`: overlay the current track title
on the visualized frames, with the cyberpsycho font / fade / hold
parameters from the preset. Caption timing is driven by the
manifest produced in P1 ingest.

## REQ-IDs in scope

- **REQ-CAPTION-001 [MUST]** — Track timing from manifest
- **REQ-CAPTION-002 [MUST]** — Mechanically generated enable
  expression (drawtext `enable=between(...)` per track)
- **REQ-CAPTION-003 [MUST]** — Fade timing (in/out durations
  from preset)

## Anchor tests (smallest-viable-first)

1. `test_caption_track_start_times_from_manifest`
   (REQ-CAPTION-001) — **land first**. Unit test: pass a
   manifest with 3 tracks; assert the generated drawtext
   filter has 3 `enable=between(...)` clauses with the right
   `t1,t2` ranges.
2. `test_caption_enable_expression_is_generated`
   (REQ-CAPTION-002) — assert the enable expression is built
   from the manifest, not hardcoded.
3. `test_caption_fade_timing` (REQ-CAPTION-003) — extract the
   drawtext alpha envelope; assert in/out durations match
   `fade_in_ms` / `fade_out_ms` from the preset.

## Task overview

1. **P5-T1 — Failing track-start test.**
2. **P5-T2 — Implement `erebus/stages/caption.py`** that reads
   manifest, builds drawtext per track, composes via builder.
3. **P5-T3 — Enable-expression test + implementation refinement.**
4. **P5-T4 — Fade-timing test + alpha-envelope verification.**
   Implementation strategy here is one of the deferred items;
   /goal picks an extraction method when it expands this task.
5. **P5-T5 — Lab clip + HUMAN-GATE-3.**
6. **P5-T6 — On approve: PR, review, merge.**

## Dependencies

- **Upstream:** P1 manifest (track timings) + P4 visualizer
  (frames to overlay on top of)
- **Downstream:** P6 mix (caption-overlaid frames go into mix),
  P7 encode (final mp4)

## Postconditions

- All 3 P5 anchor tests pass.
- `erebus.stages.caption.run(...)` works.
- Lab clip approved.
- PR merged.

## Deferred backlog items folded in

- 0007 F-7 — `test_caption_fade_timing` extraction method
  unstated (KEEP; resolved by P5-T4)
- 0009 F-6 — Rajdhani font provenance / licensing (KEEP;
  resolved by committing the OFL license alongside the font
  in `fonts/` with a `LICENSE-RAJDHANI` file)
- 0009 F-8 — REQ-CAPTION-003 fade implementation surface
  (KEEP; resolved by P5-T4)

## Notes

- The Rajdhani font's OFL license requires the font's
  copyright notice + the OFL text to ship alongside. The
  font file goes in `fonts/Rajdhani-Medium.ttf` and
  `fonts/Rajdhani-SemiBold.ttf`; the license goes in
  `fonts/LICENSE-RAJDHANI`.
- The mechanically-generated enable expression is the
  anti-hardcoding check. If a test hardcodes the expected
  expression it becomes tautological (TESTING.md §1) —
  /goal must derive the expected expression from the
  manifest fixture, not write it literally.
