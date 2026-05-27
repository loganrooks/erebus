# P2 — Concat stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p2-concat`
- **Predecessor:** P1 merged + `CHECKPOINT-P1.md` written
- **Lab clip:** `lab/outputs/p2-concat-<ts>.mp4`
- **HUMAN-GATE:** HUMAN-GATE-3 (lab review of transition cleanliness)

## Scope

Build `erebus/stages/concat.py`: concatenate the ingested mp4
files into a single stream. Use lossless `-c copy` when the input
streams are compatible; fall back to re-encode when they are not.

## REQ-IDs in scope

- **REQ-CONCAT-001 [MUST]** — Lossless concat when possible
- **REQ-CONCAT-002 [MUST]** — Duration preservation
- **REQ-CONCAT-003 [SHOULD]** — Deterministic ordering (default
  matches manifest order)

## Anchor tests (smallest-viable-first)

1. `test_concat_lossless_when_inputs_match` (REQ-CONCAT-001) —
   **land first**. Feed two synthetic mp4s with matching codec;
   assert the output's bitrate / codec match input (proxy for
   lossless).
2. `test_concat_preserves_total_duration` (REQ-CONCAT-002)
3. `test_concat_default_order_matches_manifest` (REQ-CONCAT-003)

## Task overview

1. **P2-T1 — Failing test for lossless concat.** Anchor in
   `tests/unit/test_concat.py`.
2. **P2-T2 — Implement concat via `erebus/ffmpeg/builder.py`**
   (REQ-GRADE-002 builder-only rule applies). Use ffmpeg's
   `concat` demuxer for the lossless path.
3. **P2-T3 — Duration-preservation test + implementation.**
4. **P2-T4 — Ordering test + implementation.**
5. **P2-T5 — Lab clip.** Render `lab/outputs/p2-concat-*.mp4` on
   the synthetic two-clip fixture.
6. **P2-T6 — Open PR, address review, signal merge.**

## Dependencies

- **Upstream:** P1 ingest (consumes the manifest + mp4 files)
- **Downstream:** P3 grade (consumes the concatenated stream)

## Postconditions

- All 3 P2 anchor tests pass.
- `erebus.stages.concat.run(manifest, output_path) -> Path` is
  the public entry point.
- `erebus lab apply --stage concat ...` works.
- Lab clip committed.
- PR merged.

## Deferred backlog items folded in

- 0005 F-10 — REQ-CLI-002 cap vs concat-demuxer (KEEP; resolved
  by choosing the demuxer + `--max-duration` cap in P2-T2)
- 0007 F-10 — `test_concat_lossless_when_inputs_match`
  heuristic refinement (KEEP; defined by P2-T1 specifically)
- 0009 F-16 — Concat-lossless bitrate proxy is weak (KEEP;
  refined alongside P2-T1's test)
- 0010 F-8 — REQ-CLI-002 names concat trim but no REQ-CONCAT
  contract (DEFER-PHASE-2 or DROP; trim happens at the CLI
  edge, not in concat itself)

## Notes

- The lossless heuristic is the load-bearing design decision
  here. If it's wrong, P3+ either lose quality (over-eager
  lossless) or burn CPU (over-cautious re-encode). May warrant
  a `claude -p` deep-reasoning escalation.
