# Requirements

Formal requirements for `erebus`. Each requirement has a stable
identifier (`REQ-<DOMAIN>-<NUMBER>`) used by test anchors in
`TEST_SPEC.md` and by commit messages. The cross-reference between
REQ-IDs and test anchors is bidirectional: every MUST requirement
SHALL be referenced by at least one anchor in `TEST_SPEC.md`, and
every anchor SHALL cite at least one valid REQ-ID. SHOULD and MAY
requirements MAY be anchored but are not required to be. This
coverage contract is enforced by the docs-consistency check in CI.

Categories:
- **MUST** — hard requirement; violation means the goal is not done.
- **SHOULD** — strong default; deviation needs an ADR in
  `docs/decisions/`.
- **MAY** — affordance; included to make the design space explicit.

Each requirement carries a phase tag (`phase:1`, `phase:2`, …).
Phase-1 requirements are the binding contract for Goal 1.

---

## Architecture (REQ-ARCH)

### REQ-ARCH-001 [MUST, phase:1] — Two-track surface

The codebase MUST expose every operation through two surfaces:
1. A CLI command under the `erebus` entrypoint.
2. A typed Python function importable from `erebus.stages.*`.

Both surfaces MUST call the same underlying implementation. The CLI
SHALL be a thin wrapper that loads a preset, marshals arguments, and
calls the stage function.

### REQ-ARCH-002 [MUST, phase:1] — Stage isolation

Each stage MUST be runnable in isolation against arbitrary inputs
that satisfy its `StageInputs` schema. No stage MAY require that
another specific stage has run immediately before it; ordering is
the orchestrator's responsibility, not the stage's.

### REQ-ARCH-003 [MUST, phase:1] — File-based stage communication

Stages MUST communicate via files on disk (paths returned in the
`StageResult`), never via in-memory pipes. This permits any stage's
output to be inspected, cached, or fed to a different downstream
stage by an agent without re-running upstream stages.

### REQ-ARCH-004 [MUST, phase:1] — Visualizer dispatch

The `visualize` stage MUST dispatch on `type` to a per-type
sub-module under `erebus/visualizers/`. Each sub-module MUST
implement `build_filter(audio_path: Path, config: VisualizerConfig)
-> str`. Adding a new visualizer type SHALL require only a new
sub-module + a new entry in the dispatcher; no other stage may be
modified.

### REQ-ARCH-005 [MUST, phase:1] — Presets in TOML

All preset values MUST live in `presets/*.toml`. No preset values
MAY be hard-coded in Python source. Presets MAY use TOML's inheritance
via a top-level `extends = "<name>"` key (Phase 2).

---

## Ingest (REQ-INGEST)

### REQ-INGEST-001 [MUST, phase:1] — Playlist ingestion

Given a YouTube playlist URL, the `ingest` stage MUST:
- Download every video as mp4 (best video + best audio, merged).
- Place outputs in `cache/<kind>/<playlist-id>/<index>-<video-id>.mp4`
  where `<kind>` is `videos` or `music`.
- Write a sidecar manifest `cache/<kind>/<playlist-id>/manifest.json`
  per REQ-INGEST-003.

### REQ-INGEST-002 [MUST, phase:1] — Archive-based dedup

The `ingest` stage MUST use yt-dlp's `--download-archive` mechanism.
Re-running ingestion on the same playlist MUST skip videos already
present and SHOULD complete in O(1) per already-cached video.

### REQ-INGEST-003 [MUST, phase:1] — Manifest format

The manifest MUST be a JSON object with this schema:

```json
{
  "playlist_id": "PLB7y0B0P3XsrAvMFaYlriVs8VEIrmNw11",
  "playlist_url": "https://www.youtube.com/playlist?list=...",
  "ingested_at": "2026-05-24T18:42:11-04:00",
  "tracks": [
    {
      "index": 1,
      "video_id": "abc123",
      "title": "Cyberpsycho 1 — Demons of New Hope",
      "duration_seconds": 412.5,
      "path": "cache/videos/PLB7.../1-abc123.mp4",
      "audio_track": 0
    }
  ]
}
```

Downstream stages (concat, caption, mix) read this manifest; they
MUST NOT call `ffprobe` or `yt-dlp` directly to re-derive metadata.

### REQ-INGEST-004 [MUST, phase:1] — Chapter extraction (opportunistic)

When `--write-info-json` reveals chapter markers for a downloaded
video, the manifest entry SHALL include a `chapters` array with
`start_seconds`, `end_seconds`, `title`. This is the foundation for
Phase-4 song detection.

### REQ-INGEST-005 [SHOULD, phase:1] — Format selector configurable

The format selector string passed to yt-dlp SHOULD be configurable
via preset (default `bv*[height<=1080]+ba`), to enable lower-quality
downloads for testing or higher for archival.

---

## Concat (REQ-CONCAT)

### REQ-CONCAT-001 [MUST, phase:1] — Lossless concat when possible

The `concat` stage MUST use the ffmpeg concat demuxer for inputs that
share codec, resolution, and pixel format. It MAY fall back to a
re-encoding concat when inputs differ; the fallback path SHALL be
logged at WARNING level.

### REQ-CONCAT-002 [MUST, phase:1] — Duration preservation

The total duration of the concatenated output MUST equal the sum of
input durations to within 100 ms.

### REQ-CONCAT-003 [SHOULD, phase:1] — Deterministic ordering

The default order MUST be the order in the manifest (playlist
order). The stage SHOULD accept a `--shuffle` flag with an optional
`--seed` for reproducibility.

---

## Grade (REQ-GRADE)

### REQ-GRADE-001 [MUST, phase:1] — Preset-driven filter chain

The `grade` stage MUST construct its ffmpeg filter chain from the
`[grade]` and `[grade.edges]` sections of the active preset.
Hard-coding filter parameters in Python is a violation.

### REQ-GRADE-002 [MUST, phase:1] — Builder-only ffmpeg invocation

The filter graph MUST be assembled via `erebus.ffmpeg.builder`. No
stage SHALL pass a hand-written filter string directly to
`subprocess.run`. (Tested by `test_grade_filter_built_via_builder_only`.)

### REQ-GRADE-003 [MUST, phase:1] — Measurable darkening

When the `cyberpsycho` preset is applied to a known-bright reference
clip, the mean luminance of the output MUST be lower than the input
by at least 15%. (Tested by
`test_cyberpsycho_darkens_reference_clip`.)

---

## Visualize (REQ-VIZ)

### REQ-VIZ-001 [MUST, phase:1] — Overlay at configured opacity

The visualizer overlay MUST be applied at the opacity specified in
the preset, with a tolerance of ±0.05.

### REQ-VIZ-002 [MUST, phase:1] — Bounded region

The visualizer overlay MUST occupy only the region defined by
`position`, `width`, and `height` in the preset. It MUST NOT bleed
into the visible video area beyond that region.

### REQ-VIZ-003 [SHOULD, phase:1] — Type dispatch fidelity

Each visualizer type MUST be selectable via `[visualizer] type = "..."`
and SHALL produce a filter chain valid in ffmpeg ≥ 6.

---

## Caption (REQ-CAPTION)

### REQ-CAPTION-001 [MUST, phase:1] — Track timing from manifest

Caption start times MUST be derived from the manifest produced by
the `ingest` stage, not from re-probing or hand-editing.

### REQ-CAPTION-002 [MUST, phase:1] — Mechanically generated enable expression

The `drawtext enable=...` expression MUST be generated by the
caption stage from the per-track start times, never hand-written
into a preset or source file. (Tested by
`test_caption_enable_expression_is_generated`.)

### REQ-CAPTION-003 [MUST, phase:1] — Fade timing

Each caption MUST fade in over `fade_in_ms`, hold for `hold_ms`,
and fade out over `fade_out_ms` from the start of its track.

---

## Mix (REQ-MIX)

### REQ-MIX-001 [MUST, phase:1] — Two-stream amix

The `mix` stage MUST combine exactly two audio streams (graded
video audio + music) using ffmpeg `amix` with `inputs=2`.

### REQ-MIX-002 [MUST, phase:1] — Low-pass on video audio

The video audio stream MUST be filtered with `lowpass=f=<lowpass_hz>`
when `lowpass_hz > 0`, before mixing.

### REQ-MIX-003 [MUST, phase:1] — Volume duck

The video audio stream MUST be attenuated by `volume_db` dB before
mixing. The music stream SHALL be passed through `loudnorm` when
`normalize = true`, then mixed without further attenuation.

### REQ-MIX-004 [MUST, phase:1] — Music dominance

In the final output, the music stream's perceived loudness MUST be
at least 8 dB higher than the video audio's. (Tested via `ffmpeg
ebur128` measurement on the test integration output.)

---

## Encode (REQ-ENCODE)

### REQ-ENCODE-001 [MUST, phase:1] — Container and codec

The final output MUST be an mp4 container with `libx264` video and
`aac` audio, unless the preset specifies otherwise.

### REQ-ENCODE-002 [MUST, phase:1] — Resolution and framerate

The output resolution and framerate MUST match `target_res` and
`target_fps` from the `[encode]` section.

### REQ-ENCODE-003 [SHOULD, phase:1] — Hardware-accelerated encoding (opt-in)

When the host has `h264_videotoolbox` (macOS) or `h264_nvenc`
(Linux+NVIDIA) and the preset sets `codec_v` to one of those, the
stage SHALL use it. Falling back to `libx264` SHALL be logged.

---

## Lab (REQ-LAB)

### REQ-LAB-001 [MUST, phase:1] — Single-stage application

`erebus lab apply --stage <name> --params <json> --clip <path>
--audio <path>` MUST run that stage on the supplied 30-second clip
pair and write a deterministically-named output to `lab/outputs/`.

### REQ-LAB-002 [MUST, phase:1] — Filename determinism

Lab output filenames MUST encode `(stage, params-hash)` in the basename
so identical invocations with different params hash differently.
Format: `<timestamp>__<stage>__<short-hash>.<ext>`.

### REQ-LAB-003 [SHOULD, phase:1] — Diff and contact-sheet

`erebus lab compare` SHALL render two output files side-by-side.
`erebus lab thumbs` SHALL produce a contact-sheet of frames.

---

## CLI (REQ-CLI)

### REQ-CLI-001 [MUST, phase:1] — `erebus render` end-to-end

`erebus render --preset <name> --videos <source> --music <source>
--out <path>` MUST execute the full pipeline end-to-end and exit 0
on success.

### REQ-CLI-002 [MUST, phase:1] — `--max-duration` cap

The `--max-duration <seconds>` flag MUST cap the output's duration
without re-running ingestion (use `concat` trimming).

### REQ-CLI-003 [SHOULD, phase:1] — Helpful errors

Errors MUST identify the failing stage, the inputs that triggered
the failure, and a suggested next action. No bare ffmpeg tracebacks.

---

## Security (REQ-SEC)

### REQ-SEC-001 [MUST, phase:1] — No shell injection

No subprocess call MAY interpolate user-controlled strings into a
shell command. All subprocess invocations SHALL use `shlex.quote`
or, preferably, the list form (`subprocess.run([...], shell=False)`).

### REQ-SEC-002 [MUST, phase:1] — Filter graphs built, not strung

All ffmpeg filter graphs MUST be constructed via
`erebus.ffmpeg.builder`. The builder API takes typed parameters
and returns a validated graph object; only the final serialization
crosses the subprocess boundary.

### REQ-SEC-003 [MUST, phase:1] — No secrets in code

API keys, tokens, OAuth credentials, and similar secrets MUST be
read from environment variables or a gitignored `.env` file. No
secret SHALL appear in committed source, in test fixtures, or in
commit messages. CI SHALL run `gitleaks` or equivalent on every PR.

### REQ-SEC-004 [MUST, phase:1] — Path containment

Stages MUST refuse to read from or write to paths outside the
configured `cache/` and `lab/` directories (except for the explicit
`--out` argument). Path-traversal inputs (`../../etc/passwd`) MUST
be rejected at the validation layer.

### REQ-SEC-005 [SHOULD, phase:1] — yt-dlp version pinning

The minimum supported `yt-dlp` version SHALL be declared in
`pyproject.toml`. The exact resolved version SHALL be locked in
`uv.lock` (committed). The host pre-flight check in
`docs/REPO_SETUP.md` §1 SHALL verify that the installed `yt-dlp`
binary meets the declared minimum. A user-supplied environment
variable `EREBUS_YT_DLP_BIN` MAY override the binary path; if set,
the stage SHALL log the override.

---

## Observability (REQ-OBS)

### REQ-OBS-001 [MUST, phase:1] — Structured logs

Every stage MUST emit structured logs (JSON lines on stderr by
default, human-readable on stdout when a TTY is attached). Log
records MUST include the stage name, the input paths, the params
hash, and the elapsed time.

### REQ-OBS-002 [MUST, phase:1] — Exit codes

Every stage and the top-level CLI MUST exit non-zero on failure.
Exit codes SHOULD be distinct per failure class:
- 1: general error
- 2: input validation
- 3: external tool failure (ffmpeg, yt-dlp)
- 4: configuration error
- 130: interrupted (per shell convention)

### REQ-OBS-003 [SHOULD, phase:1] — Progress for long stages

`ingest`, `concat`, and `encode` SHOULD emit progress to stderr (via
`rich` when a TTY is attached) so users can tell renders aren't
hung.

---

## Documentation (REQ-DOC)

### REQ-DOC-001 [MUST, phase:1] — Docs-consistency CI check

A CI job MUST verify that every REQ-ID in this document is
referenced by at least one test anchor in `TEST_SPEC.md`, and that
every test anchor's REQ-ID exists in this document. Violations fail
CI.

### REQ-DOC-002 [MUST, phase:1] — Public README

`README.md` MUST exist and MUST include: a one-paragraph project
description, the install command, a minimal runnable example, the
copyright/use-with-content-you-own disclaimer, and a link to
`PROJECT.md` for contributors.

### REQ-DOC-003 [MUST, phase:1] — ADRs for decisions

Significant architectural or scope decisions MUST be recorded as
ADRs (Architecture Decision Records) under `docs/decisions/`
numbered sequentially: `NNNN-short-title.md`. Use the template in
`docs/decisions/TEMPLATE.md`.

---

## Out-of-scope for Phase 1

Explicitly excluded from Phase 1 (and from any goal that doesn't
re-include them):

- ML-based audio analysis (librosa, torch, numpy for analysis)
- AcoustID / Chromaprint integration (Phase 4)
- ACRCloud integration (Phase 4)
- projectM visualizer (Phase 3)
- Shader-based grading (Phase 3+)
- preset inheritance via `extends` (Phase 2)
- `erebus inspect preset` (Phase 2)
- `erebus render --tune` overrides (Phase 2)
- Multiple presets beyond `cyberpsycho` (Phase 2)
- GUI of any kind

If you find yourself needing one of these in Phase 1, stop and
report — the work likely belongs in a later phase.

---

## Change log

Material changes to this document MUST come with an ADR and a
corresponding PR. The setup goal's docs-consistency check enforces
that no REQ-ID is added or removed without TEST_SPEC.md being
updated in the same PR.
