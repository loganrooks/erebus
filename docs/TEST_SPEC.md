# Test specification

The concrete TDD anchors. Each anchor is a test that MUST exist in
`tests/` and MUST encode the listed assertions. Anchors are stable;
renaming or removing one requires an ADR.

Format per anchor:

```
test_<name> — REQ-<ID>[, REQ-<ID>...]
  Where: tests/<unit|integration|e2e>/<file>.py
  Inputs: <what fixtures or generated data>
  Behaviour under test: <one-sentence description>
  Assertions:
    - <falsifiable claim>
    - <falsifiable claim>
  Anti-tautology check: <why this can't be reverse-engineered from a
                        trivial implementation>
```

An anchor MAY cite multiple REQ-IDs when a single observable behaviour
satisfies more than one requirement (typical for integration anchors).
The coverage check counts the anchor against each cited REQ.

The docs-consistency meta-test (`tests/meta/test_anchors.py`) verifies
that every anchor here has a matching test function and every test
function tagged `@pytest.mark.anchor("...")` has a matching anchor here.

---

## Architecture anchors

### test_stage_callable_in_isolation — REQ-ARCH-002

- **Where:** `tests/unit/test_stage_protocol.py`
- **Inputs:** A synthetic `StageInputs` for each stage, built from
  hand-written fixtures (not from a previous stage's output).
- **Behaviour:** Each stage's `run()` succeeds when given valid
  isolated inputs without any other stage having run.
- **Assertions:**
  - For every stage `s` in `erebus.stages`, `s.run(...)` returns a
    `StageResult` with a non-None `output_path`.
  - The returned path exists on disk and is non-empty.
- **Anti-tautology:** Uses hand-crafted inputs that don't come from
  any other stage, so passing the test requires actual independence.

### test_cli_and_python_surfaces_share_implementation — REQ-ARCH-001

- **Where:** `tests/integration/test_dual_surface.py`
- **Inputs:** Same preset + same input clips, invoked both ways.
- **Behaviour:** Calling `erebus render` (CLI) and calling
  `erebus.stages.render(...)` (Python) with equivalent arguments
  produces byte-identical outputs.
- **Assertions:**
  - `sha256(cli_output) == sha256(python_output)`.
- **Anti-tautology:** A naïve implementation where CLI and Python
  diverge (e.g., different default encoding settings) fails this.

### test_stage_io_via_files_not_pipes — REQ-ARCH-003

- **Where:** `tests/unit/test_stage_protocol.py`
- **Inputs:** A stage invocation with a temp `work_dir`.
- **Behaviour:** After `s.run()` returns, the next stage can be
  invoked using only the returned `output_path`, with no in-memory
  state held over.
- **Assertions:**
  - The chain `s2.run(input_paths=[s1.run(...).output_path], ...)`
    succeeds.
  - No `StageResult` field is a file handle, BytesIO, or other
    in-memory representation.
- **Anti-tautology:** A stage that secretly relies on in-memory
  state would fail when the result is round-tripped through
  serialization.

### test_new_visualizer_type_requires_only_one_module — REQ-ARCH-004

- **Where:** `tests/integration/test_visualizer_dispatch.py`
- **Inputs:** A fake visualizer module registered at runtime.
- **Behaviour:** Adding a new visualizer type works without
  modifying any stage other than the dispatcher.
- **Assertions:**
  - After registering `erebus.visualizers.fake.build_filter`, a
    preset with `type = "fake"` round-trips through the visualize
    stage.
  - `git diff --name-only` on a hypothetical "add new visualizer"
    PR includes only `erebus/visualizers/<name>.py` and the
    dispatcher.
- **Anti-tautology:** Validates the dispatcher pattern, not the
  specific visualizers shipped.

### test_no_preset_values_hardcoded_in_source — REQ-ARCH-005

- **Where:** `tests/meta/test_no_hardcoded_presets.py`
- **Inputs:** The Python source tree of `erebus/`.
- **Behaviour:** No preset value (specifically: no float in the
  ranges that grade/visualize/etc. read from preset) appears as a
  literal in production source.
- **Assertions:**
  - AST scan finds no numeric literals in fields named
    `brightness`, `contrast`, `lowpass_hz`, `volume_db`, etc.
    outside of `tests/`, `presets/`, and explicit defaults in
    pydantic schemas.
- **Anti-tautology:** A hard-coded value would be detected
  regardless of whether the preset file also exists.

---

## Ingest anchors

### test_ingest_creates_manifest_with_required_fields — REQ-INGEST-001, REQ-INGEST-003

- **Where:** `tests/integration/test_ingest.py`
- **Inputs:** A local fake "playlist" (a directory of three test
  mp4s + a mock yt-dlp wrapper that returns them).
- **Behaviour:** After ingest, the manifest exists and matches the
  schema in REQUIREMENTS.md REQ-INGEST-003.
- **Assertions:**
  - `manifest.json` exists at the expected path.
  - It validates against the `Manifest` pydantic model.
  - `len(manifest.tracks) == 3`.
  - Each track's `path` resolves to an existing file.
  - Each track's `duration_seconds` matches `ffprobe` ±100ms.
- **Anti-tautology:** Requires the manifest to be derived from
  actual file probing, not from a constant.

### test_ingest_archive_dedup_skips_known_ids — REQ-INGEST-002

- **Where:** `tests/integration/test_ingest.py`
- **Inputs:** A playlist of three videos. Run ingest twice with the
  same archive file.
- **Behaviour:** The second run skips all three videos.
- **Assertions:**
  - On the second invocation, the mock yt-dlp wrapper is called
    with the videos already in the archive but exits without
    downloading.
  - File mtimes on the cached mp4s are unchanged between runs.
- **Anti-tautology:** A naïve "always re-download" implementation
  would change the mtimes.

### test_ingest_extracts_chapters_when_present — REQ-INGEST-004

- **Where:** `tests/integration/test_ingest.py`
- **Inputs:** A mock yt-dlp wrapper that returns a video whose
  `info.json` includes a `chapters` array.
- **Behaviour:** The chapters appear in the manifest's track entry.
- **Assertions:**
  - `manifest.tracks[0].chapters` is non-empty.
  - Each chapter has `start_seconds`, `end_seconds`, `title`.
- **Anti-tautology:** Tests the parsing of yt-dlp's actual chapter
  format, not a constructed shape.

---

## Concat anchors

### test_concat_lossless_when_inputs_match — REQ-CONCAT-001

- **Where:** `tests/integration/test_concat.py`
- **Inputs:** Three mp4 fixtures with identical codec, resolution,
  pixel format, framerate.
- **Behaviour:** The concat stage uses the demuxer (no re-encode),
  detectable by elapsed time + identical bitrate of output to inputs.
- **Assertions:**
  - Output bitrate is within 5% of input bitrate (re-encoding
    would change it more than that at default CRF).
  - Total elapsed time is less than would be required for full
    re-encode of the inputs (heuristic threshold).
- **Anti-tautology:** A re-encoding implementation fails the
  bitrate check.

### test_concat_preserves_total_duration — REQ-CONCAT-002

- **Where:** `tests/integration/test_concat.py`
- **Inputs:** Three fixtures with known durations summing to
  exactly 9.0s.
- **Behaviour:** The concat output's duration matches the sum.
- **Assertions:**
  - `ffprobe duration of output == 9.0s ± 100ms`.
- **Anti-tautology:** Off-by-one frame errors or muxing glitches
  would push the duration outside the tolerance.

### test_concat_default_order_matches_manifest — REQ-CONCAT-003

- **Where:** `tests/integration/test_concat.py`
- **Inputs:** Three fixtures distinguishable by their audio
  fingerprint (a unique tone in each).
- **Behaviour:** The concat output's audio sequence matches the
  manifest's `tracks[].index` order.
- **Assertions:**
  - At each expected boundary, the tone in the output transitions
    to the next manifest track's tone.
- **Anti-tautology:** Random or reverse ordering fails.

---

## Grade anchors

### test_grade_filter_built_via_builder_only — REQ-GRADE-002, REQ-SEC-002

- **Where:** `tests/meta/test_no_raw_filter_strings.py`
- **Inputs:** The Python source tree.
- **Behaviour:** AST scan finds no string literal containing
  filter syntax characters (`=`, `:`, `[`, `]`) being passed
  directly to `subprocess.run`'s arg list at indices known to be
  the `-vf`/`-filter_complex` argument.
- **Assertions:**
  - The only producer of filter graph strings is
    `erebus.ffmpeg.builder.Graph.serialize()`.
- **Anti-tautology:** A regression where someone hand-rolls a
  filter string would be detected statically.

### test_cyberpsycho_darkens_reference_clip — REQ-GRADE-003

- **Where:** `tests/integration/test_grade.py`
- **Inputs:** `tests/fixtures/video_3s.mp4` (known mean luminance
  ~0.55 in normalized 0-1 range, deliberately bright).
- **Behaviour:** The grade stage with `cyberpsycho.toml` produces
  an output whose mean luminance is materially lower.
- **Assertions:**
  - `mean_luminance(output) < mean_luminance(input) * 0.85`.
- **Anti-tautology:** An identity grade fails; a too-aggressive
  grade also fails the next anchor.

### test_cyberpsycho_preserves_chrominance_shape — REQ-GRADE-001

- **Where:** `tests/integration/test_grade.py`
- **Inputs:** Same fixture.
- **Behaviour:** The colour-channel-mixer push toward magenta/cyan
  shifts the chrominance histogram in the expected direction.
- **Assertions:**
  - Red channel mean is approximately preserved (±10%).
  - Blue channel mean shifts toward red-and-blue mixture per the
    mixer matrix.
  - Green channel mean shifts toward muted (matching the matrix).
- **Anti-tautology:** Random colour transforms fail; identity
  transforms fail; the specific matrix in the preset is required.

---

## Visualize anchors

### test_visualizer_opacity_within_tolerance — REQ-VIZ-001

- **Where:** `tests/integration/test_visualize.py`
- **Inputs:** A graded video with known per-pixel content + a
  short audio clip; preset opacity = 0.55.
- **Behaviour:** Pixels in the visualizer region show the expected
  blend ratio.
- **Assertions:**
  - In the visualizer region, sampled pixels are a weighted mix
    of background-graded and visualizer-foreground colours such
    that the inferred alpha is 0.55 ± 0.05.
- **Anti-tautology:** Wrong opacity is detectable in pixel values.

### test_visualizer_does_not_bleed_outside_region — REQ-VIZ-002

- **Where:** `tests/integration/test_visualize.py`
- **Inputs:** Same setup.
- **Behaviour:** Outside the configured visualizer region, the
  output equals the input.
- **Assertions:**
  - For pixels outside the region:
    `sha256(slice(output)) == sha256(slice(input_graded))`.
- **Anti-tautology:** A global overlay would touch outside-region
  pixels.

---

## Caption anchors

### test_caption_enable_expression_is_generated — REQ-CAPTION-002

- **Where:** `tests/unit/test_caption.py`
- **Inputs:** A manifest with three tracks (durations 100s, 200s,
  150s; total 450s).
- **Behaviour:** The caption stage produces a `drawtext enable=...`
  expression with three `between(t, ...)` clauses at the right
  intervals.
- **Assertions:**
  - The expression contains exactly three `between(...)` clauses.
  - The first clause's interval starts at 0 and ends at hold_ms +
    fade_ms after track 1's start.
  - The second clause starts at 100 (= duration of track 1).
  - The third starts at 300 (= 100 + 200).
- **Anti-tautology:** Wrong arithmetic on track boundaries would
  fail.

### test_caption_fade_timing — REQ-CAPTION-003

- **Where:** `tests/unit/test_caption.py`
- **Inputs:** A single-track manifest, preset specifies
  `fade_in_ms=800, hold_ms=6000, fade_out_ms=1200`.
- **Behaviour:** The caption appears with the correct fade
  envelope.
- **Assertions:**
  - The generated alpha envelope (extractable from the drawtext
    expression) has the three phases at the right boundaries.
- **Anti-tautology:** Hard-coding the values to wrong defaults
  fails.

### test_caption_track_start_times_from_manifest — REQ-CAPTION-001

- **Where:** `tests/unit/test_caption.py`
- **Inputs:** A 3-track manifest with known per-track durations.
- **Behaviour:** The caption stage derives start times exclusively
  from manifest fields; it does NOT call ffprobe or yt-dlp to
  re-derive them.
- **Assertions:**
  - The generated enable expression's interval boundaries equal the
    cumulative sums of manifest track durations exactly (no rounding
    drift).
  - With ffprobe monkeypatched to raise, the caption stage still
    produces correct output (proves no probe path is taken).
- **Anti-tautology:** A naïve implementation that re-probes input
  files would fail when ffprobe is mocked to raise.

---

## Mix anchors

### test_mix_video_audio_lowpassed — REQ-MIX-002

- **Where:** `tests/integration/test_mix.py`
- **Inputs:** A test video with a known broadband audio (white
  noise) + a silent music track.
- **Behaviour:** The mix stage applies the low-pass filter from
  the preset.
- **Assertions:**
  - Spectral analysis of the output shows energy below the
    lowpass cutoff preserved.
  - Energy at frequencies more than 2× the cutoff is attenuated
    by at least 20 dB relative to input.
- **Anti-tautology:** No filter, wrong cutoff, or wrong direction
  (high-pass) all fail.

### test_mix_music_louder_than_video_audio — REQ-MIX-004

- **Where:** `tests/integration/test_mix.py`
- **Inputs:** Test video + music track of comparable input
  loudness.
- **Behaviour:** After mixing, the music dominates.
- **Assertions:**
  - Measured via `ffmpeg ebur128`: the integrated loudness of the
    music-only stream in the output exceeds the video-audio-only
    stream by ≥ 8 dB.
- **Anti-tautology:** Wrong volume duck direction fails.

### test_mix_uses_two_stream_amix — REQ-MIX-001

- **Where:** `tests/integration/test_mix.py`
- **Inputs:** A test video clip + a test music clip.
- **Behaviour:** The mix stage's ffmpeg invocation uses
  `amix=inputs=2:...`, not concat or a different mixing approach.
- **Assertions:**
  - The constructed filter graph contains exactly one `amix` node
    with `inputs=2`.
  - Replacing one input with a silent track produces output where
    that stream's contribution is silent (proving the stream entered
    the mix).
- **Anti-tautology:** A single-stream pass-through would have no
  amix node; a three-stream amix would have wrong inputs count.

### test_mix_video_audio_volume_attenuated — REQ-MIX-003

- **Where:** `tests/integration/test_mix.py`
- **Inputs:** A test video with known RMS level + a silent music
  track.
- **Behaviour:** After mixing, the video audio's RMS in the output
  is attenuated by approximately the preset's `volume_db`.
- **Assertions:**
  - Measured RMS_output / RMS_video_input is within 1 dB of
    `10 ** (volume_db / 20)`.
- **Anti-tautology:** No attenuation, or wrong-direction
  attenuation, both fail. The tolerance is tight enough to detect
  off-by-one in the filter chain.

---

## Encode anchors

### test_encode_container_and_codec — REQ-ENCODE-001

- **Where:** `tests/integration/test_encode.py`
- **Inputs:** The output of an upstream stage.
- **Behaviour:** The encode stage produces an mp4 with libx264 +
  aac.
- **Assertions:**
  - `ffprobe -show_streams` reports `codec_name=h264` on the
    video stream and `codec_name=aac` on the audio stream.
  - `ffprobe -show_format` reports `format_name=mov,mp4,m4a,3gp,3g2,mj2`.
- **Anti-tautology:** Wrong codec or container fails detection.

### test_encode_resolution_and_fps — REQ-ENCODE-002

- **Where:** `tests/integration/test_encode.py`
- **Inputs:** A higher-resolution upstream output + preset
  specifying 1920x1080@30fps.
- **Behaviour:** The encode stage produces output at the preset
  dimensions and framerate.
- **Assertions:**
  - `ffprobe` reports `width=1920, height=1080, r_frame_rate=30/1`.
- **Anti-tautology:** Pass-through encoding without rescaling
  fails.

---

## Lab anchors

### test_lab_apply_writes_deterministic_filename — REQ-LAB-001, REQ-LAB-002

- **Where:** `tests/integration/test_lab.py`
- **Inputs:** A stage + params + clip pair.
- **Behaviour:** Two invocations with identical params produce
  outputs whose filenames share the same `params-hash` suffix.
- **Assertions:**
  - `output_1_basename.split("__")[2] == output_2_basename.split("__")[2]`.
  - Two invocations with one differing param produce different
    hash suffixes.
- **Anti-tautology:** Random hashing fails; deterministic hashing
  on params-only passes.

---

## CLI anchors

### test_render_command_end_to_end — REQ-CLI-001

- **Where:** `tests/e2e/test_render.py` (gated by `--run-e2e`).
- **Inputs:** A local fake video playlist (3 small mp4s) + local
  fake music playlist (2 small mp3s). NOT a real YouTube call.
- **Behaviour:** `erebus render --preset cyberpsycho ...` exits 0
  and produces a playable file.
- **Assertions:**
  - Exit code 0.
  - Output file exists.
  - `ffprobe` reports a single video + single audio stream.
  - Total duration matches `min(sum(video_durations), sum(music_durations))`
    or matches `--max-duration` when supplied.
- **Anti-tautology:** Any pipeline-breaking change surfaces here.

### test_render_max_duration_caps_output — REQ-CLI-002

- **Where:** `tests/e2e/test_render.py`
- **Inputs:** Same as previous but with `--max-duration 30`.
- **Behaviour:** Output is 30 seconds.
- **Assertions:**
  - `ffprobe duration == 30.0 ± 0.5s`.
- **Anti-tautology:** Ignoring the flag fails.

---

## Security anchors

### test_no_shell_invocation — REQ-SEC-001

- **Where:** `tests/meta/test_no_shell.py`
- **Inputs:** Python source tree.
- **Behaviour:** No `subprocess` call uses `shell=True`.
- **Assertions:**
  - AST scan finds zero `subprocess.{run,Popen,call}(...)` calls
    with `shell=True`.
- **Anti-tautology:** A regression to `shell=True` is detected
  before runtime.

### test_path_containment — REQ-SEC-004

- **Where:** `tests/unit/test_path_validation.py`
- **Inputs:** Path-traversal strings (`../../etc/passwd`,
  symlinks pointing outside, absolute paths to system locations).
- **Behaviour:** The path validator rejects them.
- **Assertions:**
  - For each malicious input, the validator raises
    `PathContainmentError`.
- **Anti-tautology:** A pass-through validator fails.

### test_no_secrets_in_repo — REQ-SEC-003

- **Where:** `tests/meta/test_no_secrets.py` (shells out to
  pre-commit; treat as integration-grade though fast).
- **Inputs:** The repo tree.
- **Behaviour:** Common secret patterns (`AKIA[0-9A-Z]{16}`,
  `gh[ps]_[A-Za-z0-9]{36}`, `sk-[A-Za-z0-9]{20,}`, etc.) appear in
  no tracked file. Gitleaks is invoked via the pre-commit framework
  so no separate `gitleaks` binary on PATH is required.
- **Assertions:**
  - `uv run pre-commit run --hook-stage manual gitleaks --all-files`
    exits 0.
- **Anti-tautology:** Real leaks would be caught by the canonical
  scanner.

---

## Observability anchors

### test_stage_logs_are_structured — REQ-OBS-001

- **Where:** `tests/unit/test_logging.py`
- **Inputs:** Each stage invoked with a captured logger.
- **Behaviour:** Each emits records with the required fields.
- **Assertions:**
  - For each stage, the emitted records (as JSON lines) include
    `stage`, `input_paths`, `params_hash`, `elapsed_ms`.
- **Anti-tautology:** Unstructured `print` statements wouldn't
  pass.

### test_exit_codes_distinct_per_failure_class — REQ-OBS-002

- **Where:** `tests/integration/test_cli_exit_codes.py`
- **Inputs:** Synthetic failures for each class (invalid input,
  ffmpeg fail, config error, KeyboardInterrupt).
- **Behaviour:** CLI exits with the documented code.
- **Assertions:**
  - Invalid input → 2.
  - Mocked ffmpeg non-zero exit → 3.
  - Malformed preset → 4.
  - SIGINT → 130.
- **Anti-tautology:** Returning 1 for everything fails.

---

## Meta anchors

### test_every_req_id_has_test_anchor — REQ-DOC-001

- **Where:** `tests/meta/test_anchors.py`
- **Inputs:** Parsed `REQUIREMENTS.md` and `TEST_SPEC.md`.
- **Behaviour:** Every REQ-ID is referenced by at least one anchor.
- **Assertions:**
  - `set(req_ids) - set(req_ids_referenced_by_anchors) == set()`.
- **Anti-tautology:** Adding a new REQ without an anchor fails CI.

### test_every_anchor_has_test_function — REQ-DOC-001

- **Where:** `tests/meta/test_anchors.py`
- **Inputs:** Parsed `TEST_SPEC.md` + pytest test collection.
- **Behaviour:** Every anchor in this document corresponds to a
  test function decorated with `@pytest.mark.anchor("<name>")`.
- **Assertions:**
  - `set(anchor_names) == set(anchor_marks_in_pytest)`.
- **Anti-tautology:** Removing a test for an anchor or skipping
  an anchor fails CI.

### test_readme_examples_parse — REQ-DOC-002

- **Where:** `tests/meta/test_readme.py`
- **Inputs:** `README.md`.
- **Behaviour:** Every fenced `bash` block in the README parses as
  valid shell and every `erebus ...` invocation matches the CLI's
  current argument parser.
- **Assertions:**
  - `shlex.split` succeeds on each block.
  - The CLI accepts each invocation under `--help`.
- **Anti-tautology:** A README example that drifts from the CLI
  fails.

### test_adr_files_match_template — REQ-DOC-003

- **Where:** `tests/meta/test_adrs.py`
- **Inputs:** Every file under `docs/decisions/` matching
  `NNNN-*.md`.
- **Behaviour:** Each ADR contains the required sections from
  `TEMPLATE.md`.
- **Assertions:**
  - Each ADR has a level-1 heading matching the pattern
    `# NNNN — <title>`.
  - Each ADR contains a `Status:`, `Date:`, `Author(s):` line.
  - Each ADR has level-2 sections "Context", "Decision",
    "Consequences".
- **Anti-tautology:** A free-form markdown file lacking these
  sections would fail; an ADR genuinely matching the template
  passes.

### test_fixtures_reproducible_from_generator — REQ-SEC-006

- **Where:** `tests/meta/test_fixtures_provenance.py`
- **Inputs:** The contents of `tests/fixtures/` plus the output of
  `scripts/generate_fixtures.py` run against a pytest tmpdir.
- **Behaviour:** Every committed fixture is byte-equal to what the
  generator produces, and the generator produces nothing the
  committed set lacks. This enforces REQ-SEC-006 (synthetic-only
  fixtures) mechanically; a hand-edited or third-party-sourced
  fixture file will fail.
- **Assertions:**
  - For every file under `tests/fixtures/`, an identically-named
    file exists in the generator's tmpdir output.
  - Their SHA-256 hashes are equal.
  - The set of relative paths in `tests/fixtures/` is exactly the
    set written by the generator (no orphans, no extras).
- **Anti-tautology:** Skipping the generator step and just
  comparing fixtures to themselves trivially passes — the
  generator invocation is what makes the assertion falsifiable.
  At Goal 0 the fixture directory is empty and the generator
  produces nothing, so the test passes vacuously; the assertion
  activates as fixtures are added in Phase 1.

---

## End-to-end integration

These tests provide the final verification surface for Phase 1.
They run on CI in a dedicated job with `--run-e2e`.

### test_phase1_integration — REQ-INTEG-001

(Cross-references: REQ-CLI-001, REQ-CLI-002, REQ-CONCAT-002,
REQ-GRADE-003, REQ-VIZ-001, REQ-CAPTION-002, REQ-MIX-004,
REQ-ENCODE-001, REQ-ENCODE-002 — all verified individually by their
own anchors; this anchor verifies the composition.)

- **Where:** `tests/e2e/test_phase1.py`
- **Inputs:** Local fake playlists (no network).
- **Behaviour:** The full `erebus render` pipeline produces an
  output satisfying every Phase-1 acceptance criterion.
- **Assertions:** (all must hold simultaneously)
  - Exit code 0.
  - Output file exists and is playable (`ffprobe` reports valid
    streams).
  - Total duration matches expected within ±200ms.
  - At least one frame in the visualizer region differs
    significantly from the corresponding frame in the input
    (visualizer was applied).
  - Mean luminance below input by ≥15% (grade was applied).
  - At least one frame contains drawtext glyphs in the caption
    region (caption was applied).
  - Audio loudness analysis: music ≥ video-audio + 8 dB.
- **Anti-tautology:** Each assertion targets a different stage's
  contribution; passing requires all of them to actually run.

---

## Change log

This document changes with `REQUIREMENTS.md`. The two are kept in
lockstep by the docs-consistency check.
