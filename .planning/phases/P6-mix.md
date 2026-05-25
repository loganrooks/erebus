# P6 — Mix stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p6-mix`
- **Predecessor:** P5 merged + `CHECKPOINT-P5.md` written
- **Lab clip:** `lab/outputs/p6-mix-<ts>.mp4`
- **HUMAN-GATE:** HUMAN-GATE-3 (audio mix: dominance, lowpass clarity)

## Scope

Build `erebus/stages/mix.py`: combine the graded video's audio
track with the externally-supplied music track. Apply lowpass +
volume ducking to the video audio so the music sits on top.

## REQ-IDs in scope

- **REQ-MIX-001 [MUST]** — Two-stream amix (video audio + music)
- **REQ-MIX-002 [MUST]** — Low-pass filter applied to video audio
- **REQ-MIX-003 [MUST]** — Volume duck on video audio
- **REQ-MIX-004 [MUST]** — Music dominance (music is audibly the
  primary signal)

## Anchor tests (smallest-viable-first)

1. `test_mix_uses_two_stream_amix` (REQ-MIX-001) — **land first**.
   Meta-test: introspect the ffmpeg invocation; assert it uses
   the `amix` filter with 2 input streams.
2. `test_mix_video_audio_lowpassed` (REQ-MIX-002) — render
   mix; FFT-analyze the output; assert energy above
   `lowpass_hz` is attenuated.
3. `test_mix_video_audio_volume_attenuated` (REQ-MIX-003) —
   compare video-audio RMS in mix vs source; assert
   attenuation matches `volume_db`.
4. `test_mix_music_louder_than_video_audio` (REQ-MIX-004) —
   isolate music and video-audio frequencies via separable
   test fixture; assert music RMS > video-audio RMS by ≥6dB.

## Task overview

1. **P6-T1 — Failing two-stream amix test.**
2. **P6-T2 — Implement `erebus/stages/mix.py`** via builder.
3. **P6-T3 — Lowpass test + filter implementation.**
4. **P6-T4 — Volume-duck test + implementation.**
5. **P6-T5 — Music-dominance test + verification.** This is
   the most subjective measurement — strategy decided in
   the expanded task spec, possibly via `claude -p` if the
   loudness measurement procedure is contentious.
6. **P6-T6 — Lab clip + HUMAN-GATE-3.**
7. **P6-T7 — On approve: PR, review, merge.**

## Dependencies

- **Upstream:** P3 grade (graded video's audio track) +
  external music input (passed via CLI argument)
- **Downstream:** P7 encode (final mp4)

## Postconditions

- All 4 P6 anchor tests pass.
- `erebus.stages.mix.run(...)` works.
- Lab clip approved.
- PR merged.

## Deferred backlog items folded in

- 0005 F-4 — Output duration semantics (min vs longest)
  (KEEP; /goal picks one in P6-T2 expanded spec; likely
  `longest` to preserve full music track)
- 0005 F-6 — REQ-MIX-004 loudness measurement procedure
  (KEEP; resolved by P6-T5; may warrant `claude -p`)
- 0005 F-9 — `loudnorm` parameters hard-coded in example
  (KEEP; resolved by moving to preset schema in P6-T2)
- 0009 F-4 — `test_mix_video_audio_lowpassed` infeasible
  with single biquad (KEEP; resolved by P6-T3 — likely
  needs a second-order or multi-pass filter)
- 0009 F-14 — REQ-MIX-004 loudness measurement strategy
  (DROP; duplicate of 0005 F-6)

## Notes

- The mix stage is where the cyberpsycho preset's audio
  feel comes together. Lab-clip review may iterate on
  `lowpass_hz` (1800), `volume_db` (-14), and the echo
  parameters (`echo_delay_ms`, `echo_decay`).
- The music-dominance assertion is load-bearing for the
  Phase-1 acceptance criterion ("audible music with
  low-passed video audio underneath"). If the test passes
  but Logan judges the mix wrong on lab review, the
  test's threshold is the thing to revisit.
