# P1 — Ingest stage

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p1-ingest`
- **Predecessor:** P0 merged + `CHECKPOINT-P0.md` written
- **Lab clip:** `lab/outputs/p1-ingest-<ts>.json` (manifest sample)
- **HUMAN-GATE:** HUMAN-GATE-3 (lab review of manifest correctness)

## Scope

Build `erebus/stages/ingest.py`: the `yt-dlp`-backed playlist
ingestion that downloads videos, dedups against an archive, and
writes a typed manifest the rest of the pipeline consumes.

## REQ-IDs in scope

- **REQ-INGEST-001 [MUST]** — Playlist ingestion (mp4 output from
  a playlist URL)
- **REQ-INGEST-002 [MUST]** — Archive-based dedup (skip videos
  already in the archive)
- **REQ-INGEST-003 [MUST]** — Manifest format (typed schema with
  required fields: id, title, duration, source_url, chapters?)
- **REQ-INGEST-004 [MUST]** — Chapter extraction (opportunistic;
  parse yt-dlp's chapter data if present)
- **REQ-INGEST-005 [SHOULD]** — Format selector configurable

## Anchor tests (smallest-viable-first)

1. `test_ingest_creates_manifest_with_required_fields`
   (REQ-INGEST-001, -003) — **land first**. Smallest unit test:
   feed a synthetic fixture; assert manifest schema.
2. `test_ingest_archive_dedup_skips_known_ids` (REQ-INGEST-002)
3. `test_ingest_extracts_chapters_when_present` (REQ-INGEST-004)
4. `test_ingest_respects_format_selector` (REQ-INGEST-005)

## Task overview

1. **P1-T1 — Write failing `test_ingest_creates_manifest_with_required_fields`** in `tests/unit/test_ingest.py` per TEST_SPEC.md.
   Push; verify it fails red. Postcondition: anchor exists, pytest
   reports it as failing.
2. **P1-T2 — Implement minimum `erebus/stages/ingest.py`** until
   the test is green. Use the `yt-dlp` Python API via the typed
   wrapper (per AGENTS.md hard rule: no raw subprocess). Build
   the manifest via a `pydantic` v2 model so the schema is
   typed.
3. **P1-T3 — Add dedup test + implementation** (REQ-INGEST-002).
4. **P1-T4 — Add chapter-extraction test + implementation**
   (REQ-INGEST-004).
5. **P1-T5 — Add format-selector test + implementation**
   (REQ-INGEST-005).
6. **P1-T6 — Render a lab clip** via `erebus lab apply --stage
   ingest ...` and commit to `lab/outputs/`. Update PR body to
   reference the file.
7. **P1-T7 — Open PR, address codex bot review, signal merge.**

## Dependencies

- **Upstream:** none (ingest is the first pipeline stage)
- **Downstream:** P2 (concat) consumes the manifest + downloaded
  mp4 files

## Postconditions

- All 4 P1 anchor tests pass.
- `erebus.stages.ingest.run(playlist_url, archive_path) -> Manifest`
  is the public entry point (REQ-ARCH-002 stage isolation).
- `erebus lab apply --stage ingest --params <json>` works on a
  synthetic 30-second playlist fixture.
- Lab clip committed at `lab/outputs/p1-ingest-*.json`.
- PR merged with all 7 CI checks green.

## Deferred backlog items folded in

From the 39-item triage (P0-T3 produces the authoritative list):

- 0009 F-2 — yt-dlp host/venv resolution (KEEP; addressed in P1-T2)
- 0009 F-7 — REQ-INGEST-001/-005 carve-out (KEEP; resolved by
  the format-selector test in P1-T5)

## Notes

- Fixtures must come from `scripts/generate_fixtures.py`
  (REQ-SEC-006). No real yt-dlp downloads in tests; synthetic mp4
  files generated locally and discarded.
- Secrets prohibition (REQ-SEC-003): if a future yt-dlp version
  needs an API key for a particular source, the key goes in
  GitHub Secrets, never in test fixtures.
