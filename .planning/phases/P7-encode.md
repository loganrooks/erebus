# P7 — Encode stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p7-encode`
- **Predecessor:** P6 merged + `CHECKPOINT-P6.md` written
- **Lab clip:** `lab/outputs/p7-encode-<ts>.mp4`
- **HUMAN-GATE:** HUMAN-GATE-3 (final encoded output quality)

## Scope

Build `erebus/stages/encode.py`: produce the final mp4 with the
encoder settings from the cyberpsycho preset (libx264 / aac /
crf 19 / preset slow / 30fps / 1920x1080).

## REQ-IDs in scope

- **REQ-ENCODE-001 [MUST]** — Container and codec (mp4 / libx264
  / aac per preset)
- **REQ-ENCODE-002 [MUST]** — Resolution and framerate (target
  resolution and target_fps per preset)
- **REQ-ENCODE-003 [SHOULD]** — Hardware-accelerated encoding
  (opt-in; macOS AVFoundation, Linux NVENC where available)

## Anchor tests (smallest-viable-first)

1. `test_encode_container_and_codec` (REQ-ENCODE-001) — **land
   first**. Probe the output mp4 via ffprobe; assert container
   format, video codec, audio codec match preset.
2. `test_encode_resolution_and_fps` (REQ-ENCODE-002) — assert
   width × height and framerate match preset.

## Task overview

1. **P7-T1 — Failing container/codec test.**
2. **P7-T2 — Implement `erebus/stages/encode.py`** via builder.
3. **P7-T3 — Resolution/framerate test + verification.**
4. **P7-T4 — (Optional, REQ-ENCODE-003)** Hardware-accelerated
   path behind a `--accel` CLI flag. Test only that the flag
   wires through; correctness assertions stay on the
   software path.
5. **P7-T5 — Lab clip + HUMAN-GATE-3.**
6. **P7-T6 — On approve: PR, review, merge.**

## Dependencies

- **Upstream:** P6 mix (mixed audio + visualized + captioned
  video stream)
- **Downstream:** P8 integration (the end-to-end `erebus render`
  invokes encode as the final stage)

## Postconditions

- All 2-3 P7 anchor tests pass.
- `erebus.stages.encode.run(...)` works.
- Lab clip approved.
- PR merged.

## Deferred backlog items folded in

- 0005 F-7 — Byte-identical CLI vs Python output (DEFER-PHASE-2;
  libx264 is non-deterministic in ways that can't be fixed
  without `-x264-params seed=0` and even that doesn't fully
  determinize. Phase-2 problem.)
- 0009 F-15 — Byte-identical mp4 anchor needs deterministic
  flags (DROP; duplicate of 0005 F-7)

## Notes

- macOS hardware acceleration (REQ-ENCODE-003) is SHOULD, not
  MUST. /goal may DROP it from Phase-1 if the implementation
  bumps against AVFoundation quirks; the software path is
  the acceptance path.
- The "framerate placement" deferred item (0005 F-16) — does
  framerate normalization happen here or in grade? — is a
  P3-or-P7 decision. If P3 didn't pick it up, P7 does.
