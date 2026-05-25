# 0004 — Pre-setup gap analysis (pass 2)

- **Status:** proposed
- **Date:** 2026-05-24
- **Author:** Claude Code (claude-opus-4-7) — second-pass audit
- **Related ADRs:** archive/0001 (pass-1 audit, resolved),
  0002 (resolution plan), 0003 (name + license)
- **Related REQ-IDs:** (none — this is meta)
- **Related anchors:** (none — this is meta)

## Context

Second-pass audit of the `erebus` documentation set, performed
without reading the archived pass-1 audit (0001) or its resolution
plan (0002). The intent is to read the current state of the docs
cold and surface any remaining gaps before the Goal-0 setup agent
executes the bootstrap.

Files reviewed in full: `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`,
`docs/REQUIREMENTS.md`, `docs/TESTING.md`, `docs/TEST_SPEC.md`,
`docs/WORKFLOW.md`, `docs/REPO_SETUP.md`, `README.md`, `NOTES.md`,
`docs/decisions/TEMPLATE.md`, `docs/decisions/0003-name-and-license.md`,
`docs/review-prompts/stage-review.md`, and
`docs/review-prompts/pre-setup-audit.md`.

The audit covers the ten axes from the pre-setup-audit prompt:
internal contradictions, REQ↔anchor coverage, requirement ambiguity,
anti-tautology, missing guardrails, workflow gaps, tool/dependency
assumptions, public-repo risks, scope creep, and free-form
impressions.

## Findings

### Finding 1 — REQ-SEC-006 has no citing anchor

- **Axis:** 2 (REQ ↔ anchor coverage)
- **Severity:** MUST-resolve
- **Evidence:** `docs/REQUIREMENTS.md` line 326 declares
  `### REQ-SEC-006 [MUST, phase:1] — Fixture provenance`. A scan of
  `docs/TEST_SPEC.md` for `SEC-006` returns no matches. The
  bootstrap meta-test in `docs/REPO_SETUP.md` §3.6.1 enforces:
  ```python
  assert not missing, f"MUST REQs without anchor: {sorted(missing)}"
  ```
  using `MUST_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[MUST", re.MULTILINE)`,
  which matches `REQ-SEC-006`'s heading.
- **Issue:** The Phase-1 MUST requirement REQ-SEC-006 (synthetic
  fixture provenance) is declared in `REQUIREMENTS.md` but cited by
  zero anchors in `TEST_SPEC.md`. The bootstrap docs-consistency
  test `test_every_must_req_has_anchor_citation` will fail at Goal 0,
  the `docs-consistency` CI job will go red, and the
  "Latest CI run on `main` is green" criterion in
  `docs/REPO_SETUP.md` §8 cannot be satisfied.
- **Suggested resolution:** Add an anchor to `TEST_SPEC.md` that
  cites REQ-SEC-006. Two candidates: (a) a meta-test
  `test_fixtures_match_generator_script_output` that runs
  `scripts/generate_fixtures.py` against a tmpdir and asserts byte
  equality with committed fixtures; (b) a simpler
  `test_fixture_directory_only_contains_generator_outputs` that
  checks every file under `tests/fixtures/` against a manifest the
  generator writes. Option (b) is easier at Goal 0 since the
  fixture directory is empty.

### Finding 2 — REPO_SETUP §2 and §3 disagree on commit strategy

- **Axis:** 1 (internal contradictions)
- **Severity:** MUST-resolve
- **Evidence:** `docs/REPO_SETUP.md` §2 (lines 48-69) instructs:
  ```bash
  git init -b main
  git add .
  git status
  git commit -m "chore: initial bootstrap (docs + skeleton)"
  gh repo create loganrooks/erebus --public ... --source=. --remote=origin --push
  ```
  This stages everything in the working directory and creates a
  single bootstrap commit before the GitHub repo is created.
  §3 then opens with:
  > "The initial commit creates these files in this order. Each
  > step is a separate commit on `main` so the history reads as a
  > setup walkthrough."

  Each `Step 3.N` subsection ends with `Commit: \`chore/docs/ci:
  add ...\``, implying eight separate commits (3.1 through 3.8).
- **Issue:** The instructions describe two incompatible flows. Under
  §2, `git add . && git commit` produces one commit containing every
  file already on disk. Under §3, each `Step 3.N` produces its own
  commit. An agent following both will either (a) make one bootstrap
  commit and skip §3's per-step commits as empty, or (b) make §3's
  per-step commits and find §2's `git add .` already staged
  everything, leaving the per-step `git add` calls as no-ops. The
  intended history (a walkthrough where `.gitignore` precedes
  `LICENSE` precedes `pyproject.toml`) is not reachable from the
  written instructions.
- **Suggested resolution:** Pick one of three resolutions and edit
  the doc:
  (a) §2 does only `git init -b main` and creates no commit; §3.1
      through §3.8 each create their own commit; `gh repo create
      --source=. --push` runs at the end of §3.
  (b) §2 makes a single bootstrap commit containing all files; §3's
      per-step "Commit:" lines are rewritten as
      "Contents of this commit's `.gitignore`/`pyproject.toml`/etc."
  (c) §3 explicitly notes that the bootstrap is the first commit and
      §3.N "commits" are the file groups inside it; subsequent
      additions land as separate commits on `main` only when made
      after the initial push.

### Finding 3 — `tests/conftest.py` fails mypy strict at Goal 0

- **Axis:** 1 (internal contradictions) / 5 (missing guardrails)
- **Severity:** MUST-resolve
- **Evidence:** `docs/REPO_SETUP.md` §3.6.1 lines 339-349:
  ```python
  """Pytest configuration for the erebus test suite."""


  def pytest_configure(config):
      """Reserved for future runtime config.
      ...
      """
  ```
  `docs/REPO_SETUP.md` §3.3 lines 190-195:
  ```toml
  [tool.mypy]
  python_version = "3.11"
  strict = true
  warn_return_any = true
  warn_unreachable = true
  disallow_untyped_defs = true
  ```
  CI workflow lint-and-type job runs `uv run mypy .` against the
  whole tree.
- **Issue:** The committed conftest has an untyped function
  parameter and missing return type. With `strict = true` and
  `disallow_untyped_defs = true`, mypy reports
  `Function is missing a type annotation` and exits non-zero. The
  `lint-and-type` job goes red, breaking the
  Goal-0 "CI green on `main`" completion criterion.
- **Suggested resolution:** Edit the bootstrap conftest in
  REPO_SETUP.md §3.6.1 to:
  ```python
  from typing import TYPE_CHECKING

  if TYPE_CHECKING:
      import pytest


  def pytest_configure(config: "pytest.Config") -> None:
      ...
  ```
  Or drop the hook entirely (markers are declared in pyproject.toml,
  the hook is purely aspirational at Goal 0).

### Finding 4 — End-to-end output duration semantics are undefined

- **Axis:** 3 (ambiguity) / 4 (anti-tautology)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md` line 437-438 asserts:
  > "Total duration matches
  > `min(sum(video_durations), sum(music_durations))` or matches
  > `--max-duration` when supplied."

  `PROJECT.md` §5 line 286-288 shows the audio mix chain:
  ```
  [video_audio][music]
    amix=inputs=2:duration=longest:weights=1 1 [aout];
  ```
  `REQ-MIX-001` requires `amix` with `inputs=2` but is silent on
  `duration=`. No REQ specifies what the orchestrator does when
  video and music durations differ.
- **Issue:** The anchor expects `min` of the two stream durations;
  the example chain produces `max` (via `duration=longest`). If the
  implementation follows the example, the e2e anchor will fail. If
  the implementation follows the anchor, the example is wrong.
  Beyond that, neither doc specifies whether the orchestrator loops
  the shorter input, trims the longer one, or accepts a silent
  tail. This is the kind of question that the Goal-1 agent will hit
  in its first hour of work.
- **Suggested resolution:** Add a new REQ (e.g. REQ-CLI-004 or
  REQ-MIX-005) that defines duration semantics. Three reasonable
  options:
  (1) `duration = min(sum_v, sum_m)` — trim concat output once
      music ends, never silent. Aligns with the existing anchor.
      Requires concat to know about music duration.
  (2) `duration = longest` — accept silent tail on the shorter
      side. Simplest implementation; aligns with the PROJECT.md
      example. Edit the anchor to match.
  (3) Loop the shorter stream until the longer one ends. Most
      "background mix" appropriate but expensive to implement and
      changes manifest semantics for captioning.

### Finding 5 — `test-e2e` CI trigger uses a push-only field for PRs

- **Axis:** 6 (workflow gaps) / 5 (missing guardrails)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REPO_SETUP.md` §3.7 lines 506-512:
  ```yaml
  test-e2e:
      runs-on: ubuntu-latest
      if: |
        contains(github.event.pull_request.labels.*.name, 'e2e') ||
        contains(github.event.head_commit.modified, 'erebus/') ||
        contains(github.event.head_commit.modified, 'presets/') ||
        contains(github.event.head_commit.modified, 'tests/e2e/')
  ```
  `WORKFLOW.md` §3 line 165: "test-e2e runs conditionally (on PRs
  touching `erebus/`, `presets/`, or `tests/e2e/`)".
- **Issue:** The `github.event.head_commit.modified` field is
  populated on `push` events; it is empty or undefined on
  `pull_request` events. PRs that touch `erebus/`, `presets/`, or
  `tests/e2e/` will not trigger test-e2e unless the PR carries the
  `e2e` label. The job skips silently. This goes undetected because
  a skipped job appears as a checkmark on the PR.
- **Suggested resolution:** Use `dorny/paths-filter@v3` or
  GitHub's `paths:` filter on the workflow trigger. Example:
  ```yaml
  on:
    pull_request:
      branches: [main]
      paths:
        - 'erebus/**'
        - 'presets/**'
        - 'tests/e2e/**'
  ```
  applied to a separate workflow file, or use
  `tj-actions/changed-files` action inside the existing workflow.

### Finding 6 — REQ-MIX-004 measurement isolation method unspecified

- **Axis:** 3 (ambiguity) / 4 (anti-tautology)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REQUIREMENTS.md` REQ-MIX-004:
  > "the music stream's perceived loudness MUST be at least 8 dB
  > higher than the video audio's. (Tested via `ffmpeg ebur128`
  > measurement on the test integration output.)"

  `docs/TEST_SPEC.md` `test_mix_music_louder_than_video_audio`:
  > "Measured via `ffmpeg ebur128`: the integrated loudness of the
  > music-only stream in the output exceeds the video-audio-only
  > stream by ≥ 8 dB."
- **Issue:** `ebur128` measures loudness of an audio stream. The
  mix output is one stream that combines both sources. To compare
  "music-only loudness in the output" against "video-audio-only
  loudness in the output," the test must either (a) run the mix
  twice with one side muted each time, (b) measure the inputs
  pre-mix and account for the mixing math, or (c) work with stems
  that the mix stage doesn't emit. The doc does not pick one.
- **Suggested resolution:** Specify the measurement procedure in
  the anchor. Option (a) is the cleanest: run the mix stage twice
  with `video_audio` and `music` alternately replaced by silence,
  measure each output's loudness, compare. Add a helper in
  `tests/integration/test_mix.py` that does the two passes.

### Finding 7 — `test_cli_and_python_surfaces_share_implementation` asserts byte-identical output

- **Axis:** 4 (anti-tautology) / 3 (ambiguity)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md` lines 48-58:
  > "Calling `erebus render` (CLI) and calling
  > `erebus.stages.render(...)` (Python) with equivalent arguments
  > produces byte-identical outputs."

  > Assertions:
  > - `sha256(cli_output) == sha256(python_output)`.
- **Issue:** libx264 plus the mp4 muxer are not byte-deterministic
  by default — timestamps, thread scheduling, and rate-control
  state vary across runs. Adding `-flags +bitexact -threads 1` and
  using `-fflags +bitexact` for the muxer mitigates this for
  mp4-out-of-mp4, but a freshly encoded h264 from raw frames will
  still drift run-to-run on some hosts. The anchor as written may
  fail intermittently even when CLI and Python are sharing the same
  implementation.
- **Suggested resolution:** Replace byte-equality with a semantic
  equivalence check: same duration (`±50ms`), same frame count,
  same audio sample count, frame-by-frame decoded SHA256 (after
  decode-then-rehash), and identical filter graph (extractable
  from a JSON manifest the implementation writes). The point of
  the anchor is "same implementation underneath," not "same
  bit-pattern."

### Finding 8 — `erebus.stages.render` is referenced by an anchor but absent from the skeleton

- **Axis:** 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md` anchor
  `test_cli_and_python_surfaces_share_implementation` calls
  `erebus.stages.render(...)`. `docs/REPO_SETUP.md` §3.6 source-tree
  skeleton creates individual stage files under `erebus/stages/`
  (`ingest.py`, `concat.py`, `grade.py`, etc.) plus `erebus/cli.py`,
  but no `erebus/stages/render.py` or top-level `render` function
  exposed at `erebus.stages.render`.
- **Issue:** The anchor's Python surface call resolves to nothing in
  the bootstrap skeleton. At Phase 1 the implementer will have to
  invent a `render` orchestrator and decide whether it lives in
  `erebus/stages/render.py`, `erebus/stages/__init__.py`, or
  `erebus/orchestrator.py`. The architecture doc (PROJECT.md §2)
  says "Agents call stages directly," which suggests stages are
  the agent surface — so an `erebus.stages.render` orchestrator is
  the wrong agent-facing API. The two-track contract may need a
  different shape (e.g. `erebus.render` as the orchestrator,
  `erebus.stages.*` as individual stages).
- **Suggested resolution:** Either (a) add `render.py` to the
  skeleton and clarify that `erebus.stages.render` is the
  orchestrator that calls each stage in sequence, or (b) move the
  orchestrator to `erebus.render` and update the anchor to
  `erebus.render(...)`. Choice (b) better matches REQ-ARCH-002's
  "stages are isolated" framing.

### Finding 9 — `loudnorm` parameters in PROJECT.md §5 are not in the preset

- **Axis:** 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `PROJECT.md` §5 line 286:
  ```
  [1:a] loudnorm=I=-16:LRA=11:TP=-1.5 [music];
  ```
  `presets/cyberpsycho.toml` (defined inline in PROJECT.md §5
  earlier) has no `loudnorm_i`, `loudnorm_lra`, or `loudnorm_tp`
  keys. `REQ-ARCH-005`: "No preset values MAY be hard-coded in
  Python source." `test_no_preset_values_hardcoded_in_source`
  scans for "no numeric literals in fields named `brightness`,
  `contrast`, `lowpass_hz`, `volume_db`, etc."
- **Issue:** The PROJECT.md example chain hard-codes loudnorm
  parameters that are not preset-driven. If the implementation
  follows the example literally, the values live in Python source.
  The anchor `test_no_preset_values_hardcoded_in_source` only
  scans field names it knows about (the parenthetical "etc." is
  not extensible) and would likely not catch this regression. But
  the spirit of REQ-ARCH-005 is violated.
- **Suggested resolution:** Add `loudnorm_i`, `loudnorm_lra`,
  `loudnorm_tp` to the `[audio.music_track]` section of the
  cyberpsycho preset, declare them in the pydantic schema with
  defaults, and update the anchor's scan list to include them.

### Finding 10 — REQ-CLI-002 cap path conflicts with REQ-CONCAT-001

- **Axis:** 3 (ambiguity) / 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REQUIREMENTS.md` REQ-CLI-002:
  > "The `--max-duration <seconds>` flag MUST cap the output's
  > duration without re-running ingestion (use `concat` trimming)."

  `docs/REQUIREMENTS.md` REQ-CONCAT-001:
  > "The `concat` stage MUST use the ffmpeg concat demuxer for
  > inputs that share codec, resolution, and pixel format."
- **Issue:** The ffmpeg concat demuxer (`-f concat`) does not
  trim — it copies streams end-to-end. Trimming requires either a
  re-encode path (`-ss` / `-t` on the output) or a pre-concat
  trimming step on the last input file. Neither is specified. The
  Phase-1 implementer has to decide where the cap logic lives and
  how it interacts with the lossless-when-possible rule.
- **Suggested resolution:** Either (a) clarify REQ-CONCAT-001 with
  a "lossless concat unless trimming is required" carve-out, or
  (b) move the cap logic to a separate trim stage that runs
  between concat and grade, or (c) implement the cap by trimming
  the manifest itself (drop tracks past the cap, partial-trim the
  final track) before concat runs.

### Finding 11 — REQ-SEC-005 vs pyproject.toml: yt-dlp is unpinned

- **Axis:** 1 (internal contradictions) / 7 (tool assumptions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REQUIREMENTS.md` REQ-SEC-005:
  > "The minimum supported `yt-dlp` version SHALL be declared in
  > `pyproject.toml`. The exact resolved version SHALL be locked
  > in `uv.lock` (committed)."

  `docs/REPO_SETUP.md` §3.3 pyproject.toml lists `typer`,
  `pydantic`, `rich`, `tomli` — no `yt-dlp`. CI workflow steps run
  `uv pip install yt-dlp` without a version pin (lines 492, 503,
  519).
- **Issue:** REQ-SEC-005 is `SHOULD` not `MUST`, so this does not
  block the docs-consistency check. But the rest of the doc set
  treats yt-dlp pinning as a real requirement (pre-flight check in
  REPO_SETUP §1 validates a minimum version threshold). The
  bootstrap pyproject.toml does not declare yt-dlp at all, so the
  pre-flight's "version recorded in pyproject.toml at bootstrap
  time (placeholder: 2024.07)" is checking against a placeholder
  the doc explicitly calls a placeholder. CI installs whatever
  yt-dlp is current at run-time.
- **Suggested resolution:** Add `"yt-dlp >= 2024.7.16"` (or
  whichever is the audited current minimum) to
  `[project.dependencies]` in pyproject.toml. Replace
  `uv pip install yt-dlp` in CI with `uv sync --extra dev` (which
  picks it up via the lock). Update the pre-flight check to read
  the minimum from pyproject.toml rather than hard-code a
  placeholder.

### Finding 12 — Pre-commit scope inconsistency across docs

- **Axis:** 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:**
  `docs/TESTING.md` §7 line 226:
  > "Pre-commit runs `pytest tests/unit tests/meta -m phase1
  > --quiet --no-header` on every commit"

  `docs/WORKFLOW.md` §2 line 80:
  > `pytest tests/unit tests/meta -m "phase1 or meta" --quiet --no-header`

  `docs/REPO_SETUP.md` §3.4 line 258:
  > `entry: uv run pytest tests/unit tests/meta -m "phase1 or meta" --quiet --no-header`
- **Issue:** TESTING.md says `-m phase1`; the other two say
  `-m "phase1 or meta"`. Functionally equivalent in the bootstrap
  set since every meta test also carries `@pytest.mark.phase1`,
  but the discrepancy will mislead future readers and may bite
  when a future meta test is added without the phase1 marker
  (which the marker description in pyproject.toml explicitly
  encourages — "meta tests should also carry the relevant phase
  marker" is a SHOULD, not enforced).
- **Suggested resolution:** Pick the form
  `-m "phase1 or meta"` (more explicit, covers the case where a
  future meta test forgets the phase marker) and edit TESTING.md
  §7 to match.

### Finding 13 — `review-artifact-exists` only matches `.json`, but docs allow `.md`

- **Axis:** 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/WORKFLOW.md` §5 line 217-218:
  > "A CI job `review-artifact-exists` verifies that a review file
  > exists at `docs/decisions/reviews/<PR-NUMBER>-*.{json,md}` and
  > is non-empty before the PR can merge."

  `docs/REPO_SETUP.md` §3.7 lines 549-555:
  ```bash
  PR="${{ github.event.pull_request.number }}"
  if compgen -G "docs/decisions/reviews/${PR}-*.json" > /dev/null; then
    echo "Review artifact found."
  else
    echo "::error::No review artifact at docs/decisions/reviews/${PR}-*.json"
    ...
  fi
  ```
- **Issue:** The CI check only matches `.json`. A reviewer
  producing `<PR>-stage.md` (the human-friendly markdown form that
  WORKFLOW.md §5 explicitly mentions as part of the artifact
  workflow) would not satisfy the check. The
  `non-empty` requirement WORKFLOW.md mentions is also not
  implemented in the bash check.
- **Suggested resolution:** Change the compgen glob to
  `"docs/decisions/reviews/${PR}-*"` and add a non-empty file
  check:
  ```bash
  if find "docs/decisions/reviews" -name "${PR}-*" -type f -size +0c | grep -q .; then
    echo "Review artifact found."
  else
    echo "::error::..."
    exit 1
  fi
  ```

### Finding 14 — "CI green on Ubuntu and macOS" overstates cross-platform coverage

- **Axis:** 7 (tool/dependency assumptions) / 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `PROJECT.md` §4 verification surface point 5:
  > "All Phase-1 TDD anchors green; CI green on Ubuntu and macOS."

  `docs/REPO_SETUP.md` §3.7 workflow:
  - `test-unit-meta` runs on `[ubuntu-latest, macos-latest]`
  - `test-integration` runs on `ubuntu-latest` only
  - `test-e2e` runs on `ubuntu-latest` only (conditionally, per
    Finding 5)
  - `gitleaks`, `docs-consistency`, `review-artifact-exists` all
    `ubuntu-latest` only.
- **Issue:** Only the unit and meta layers run on macOS. Phase-1
  integration anchors (`test_concat_*`, `test_grade_*`,
  `test_visualizer_*`, `test_mix_*`, `test_encode_*`) and the e2e
  anchor (`test_phase1_integration`) never run on macOS. macOS-
  specific issues (Homebrew's ffmpeg codec set, AVFoundation
  hardware encoders per REQ-ENCODE-003, Apple Silicon ABI
  differences in `cv2` or similar) won't be caught in CI. The
  verification statement is technically true (the jobs that run on
  both go green on both) but implies more than is delivered.
- **Suggested resolution:** Either (a) add `macos-latest` to the
  matrix for `test-integration` (cost: 2-3× CI minutes) and
  document the trade-off; or (b) reword PROJECT.md §4 point 5 to
  "Unit and meta tests green on Ubuntu and macOS; integration and
  e2e green on Ubuntu."

### Finding 15 — `tomli` conditional dependency is dead

- **Axis:** 1 (internal contradictions) / 7 (tool assumptions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REPO_SETUP.md` §3.3:
  ```toml
  requires-python = ">=3.11"
  dependencies = [
    ...
    "tomli >= 2.0; python_version < '3.11'",
  ]
  ```
  `AGENTS.md` line 20: "Python ≥ 3.11". `PROJECT.md` §11:
  "`tomli`/`tomllib`".
- **Issue:** `requires-python = ">=3.11"` prevents Python 3.10 or
  lower from installing the package. The conditional dependency
  `tomli; python_version < '3.11'` therefore never activates. It is
  dead weight in the lock file and signals to readers that 3.10
  support might be intended.
- **Suggested resolution:** Remove the `tomli` entry from
  `[project.dependencies]`. Update PROJECT.md §11 to say `tomllib`
  (stdlib) only.

### Finding 16 — REQ-ENCODE-002 framerate normalization is implicit

- **Axis:** 3 (ambiguity)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REQUIREMENTS.md` REQ-ENCODE-002:
  > "The output resolution and framerate MUST match `target_res`
  > and `target_fps` from the `[encode]` section."

  `PROJECT.md` §5 grade filter chain (lines 234-253) shows
  `scale=1920:1080:...` and `pad=1920:1080:...` but no `fps=` filter.
  Encode chain not shown in PROJECT.md §5.
- **Issue:** Source playlists routinely contain 24fps, 25fps,
  29.97fps, 30fps, and 60fps inputs. The grade stage's scale+pad
  handles resolution but the chain never sets framerate. The
  encode stage must include `fps=<target_fps>` somewhere to
  satisfy the REQ, but the docs don't say where. The anchor
  `test_encode_resolution_and_fps` will fail on any non-30fps
  input unless the encode stage handles fps normalization.
- **Suggested resolution:** Add an `fps=<target_fps>` filter to
  the encode stage's chain (or insert it at the end of grade).
  Document the placement in REQ-ENCODE-002's body.

### Finding 17 — REQ-CAPTION-003 fade phase boundaries are ambiguous

- **Axis:** 3 (ambiguity)
- **Severity:** CONSIDER
- **Evidence:** `docs/TEST_SPEC.md` `test_caption_enable_expression_is_generated`:
  > "The first clause's interval starts at 0 and ends at hold_ms +
  > fade_ms after track 1's start."

  Preset has `fade_in_ms = 800`, `hold_ms = 6000`,
  `fade_out_ms = 1200`.
- **Issue:** "fade_ms" is undefined — fade_in_ms, fade_out_ms, or
  both summed? Reading literally, the visible time per caption is
  `fade_in_ms + hold_ms + fade_out_ms` = 8000ms. The anchor's
  arithmetic should be explicit.
- **Suggested resolution:** Rewrite the anchor as:
  > "ends at `fade_in_ms + hold_ms + fade_out_ms` after track 1's start"

  ...or whichever interval the implementation should produce.

### Finding 18 — REQ-LAB-002 filename can collide within one second

- **Axis:** 6 (workflow gaps)
- **Severity:** CONSIDER
- **Evidence:** `docs/REQUIREMENTS.md` REQ-LAB-002:
  > "Format: `<timestamp>__<stage>__<short-hash>.<ext>`."

  `docs/TEST_SPEC.md` `test_lab_apply_writes_deterministic_filename`
  expects identical params → identical hash.
- **Issue:** If two invocations with identical params occur within
  the same timestamp resolution (typical: 1-second precision), the
  filenames are identical and the second overwrites the first
  silently. The anchor's "Two invocations with identical params
  produce outputs whose filenames share the same `params-hash`
  suffix" intentionally permits this. But the lab is designed for
  iteration; overwriting a known-good output during a scripted
  sweep is a real failure mode.
- **Suggested resolution:** Either use millisecond-resolution
  timestamps in the filename, or treat the lab output filename as
  `<params-hash>` only (timestamps go in a sidecar log). The
  current spec implies the timestamp is for ordering, not
  uniqueness.

### Finding 19 — AGENTS.md self-audit instruction still names `0001`

- **Axis:** 10 (anything else) / 1 (internal contradictions)
- **Severity:** CONSIDER
- **Evidence:** `AGENTS.md` §"Self-audit before setup work" line 173:
  > "produce `docs/decisions/0001-pre-setup-gap-analysis.md`"

  The pass-1 gap analysis (0001) has been archived
  (`docs/decisions/archive/0001-...`); pass-2 is being written to
  `0004-pre-setup-gap-analysis-pass-2.md`.
- **Issue:** A future agent reading AGENTS.md for the first time
  will look for `docs/decisions/0001-pre-setup-gap-analysis.md`,
  find it in `archive/`, and either re-run the pass-1 audit
  redundantly or be confused about which audit is current. Same
  issue with REPO_SETUP.md §3.5's commit list, which still names
  `0001-pre-setup-gap-analysis.md`.
- **Suggested resolution:** Update both references. AGENTS.md
  should say "produce the next-numbered
  `docs/decisions/NNNN-pre-setup-gap-analysis-pass-N.md`" with
  pointers to prior passes. REPO_SETUP.md §3.5 should reference
  the current pass file or describe the audit output abstractly.

### Finding 20 — REPO_SETUP.md §3.2 still mentions `gh repo create` generating LICENSE

- **Axis:** 1 (internal contradictions)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §2 line 60-62:
  > "Drop --license=mit here: the local LICENSE generated in step
  > 3.2 is the canonical one"

  `docs/REPO_SETUP.md` §3.2 line 133-134:
  > "The MIT LICENSE generated by `gh repo create`. If it isn't
  > there, generate it with: `gh api /licenses/mit ...`"
- **Issue:** Since §2 explicitly drops `--license=mit`, `gh repo
  create` won't generate the LICENSE. §3.2's "if it isn't there"
  branch is the always-taken branch; the conditional is misleading.
- **Suggested resolution:** Edit §3.2 to unconditionally generate
  the LICENSE via `gh api /licenses/mit`.

### Finding 21 — GitHub Actions are major-version tagged, not SHA-pinned

- **Axis:** 7 (tool/dependency assumptions) / 8 (public-repo risk)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §3.7:
  - `actions/checkout@v4`
  - `astral-sh/setup-uv@v3`
- **Issue:** Major-version tags can be updated by the upstream
  (e.g. via a new `v4.1.7` that the `v4` tag points at). For a
  public repo with permissioned secrets, GitHub's hardening guide
  recommends SHA-pinning third-party actions. Lower priority here
  because no Phase-1 secrets exist, but it's a reasonable
  hardening step before any secret is added.
- **Suggested resolution:** Replace tag references with SHAs and
  add a Dependabot config to bump them. Example:
  ```yaml
  uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
  ```

### Finding 22 — Lab clips are referenced by name but gitignored

- **Axis:** 6 (workflow gaps)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §3.1 `.gitignore` line 110-113:
  ```
  lab/clips/
  ...
  !lab/clips/.gitkeep
  ```
  `PROJECT.md` §7 references `lab/clips/cyberpsycho_30s.mp4` and
  `lab/clips/synthwave_30s.opus`. `AGENTS.md` "non-negotiable rule
  8" requires lab runs against 30-second reference clips before
  changing filter chains.
- **Issue:** The lab clips are gitignored (per REQ-SEC-006's
  exclusion of unverified provenance) but are required by the
  workflow. A fresh agent has no way to obtain them unless the
  human supplies them out-of-band. This is intentional (the clips
  are not distributable) but the documentation doesn't tell the
  agent what to do at the moment the workflow says "render a lab
  clip." Cross-vendor reviewers will flag the missing clip link in
  PRs (per stage-review.md Check 8).
- **Suggested resolution:** Add a short subsection to PROJECT.md
  §9 explaining how Logan obtains the lab clips and how the agent
  should request them when missing (e.g. "skip lab verification
  and flag the missing clip in NOTES.md").

### Finding 23 — `--run-e2e` flag has no implementing pytest hook in the bootstrap

- **Axis:** 10 (anything else)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §3.7 CI workflow:
  ```yaml
  - run: uv run pytest tests/e2e -m phase1 --run-e2e
  ```
  `docs/TESTING.md` §7 line 215:
  ```bash
  uv run pytest tests/e2e -m phase1 --run-e2e
  ```
  No conftest hook adds `--run-e2e` as an argparse option in the
  bootstrap.
- **Issue:** `pytest --run-e2e` will fail with "unrecognized
  argument" until a `pytest_addoption` hook is added. The Phase-1
  agent will hit this on first e2e test creation. Not a Goal-0
  blocker but worth noting; the conftest in §3.6.1 already exists
  and could include the option upfront.
- **Suggested resolution:** Add to the bootstrap conftest:
  ```python
  def pytest_addoption(parser: "pytest.Parser") -> None:
      parser.addoption(
          "--run-e2e",
          action="store_true",
          default=False,
          help="Run end-to-end tests (slow).",
      )
  ```

## Summary

23 findings total: 3 MUST-resolve, 13 SHOULD-resolve, 7 CONSIDER.

Setup work blocks until each MUST-resolve item has a resolution
recorded:

- **Finding 1** (REQ-SEC-006 has no citing anchor — bootstrap
  meta-test fails at Goal 0)
- **Finding 2** (REPO_SETUP §2 vs §3 commit-strategy contradiction
  — agent has no executable flow)
- **Finding 3** (tests/conftest.py untyped function — fails mypy
  strict at the lint-and-type CI job)

The SHOULD-resolve findings cluster around Phase-1 ambiguities
(duration semantics, mix isolation, framerate normalization), CI
gaps that don't break Goal 0 but will bite Phase 1 (test-e2e
trigger, review-artifact glob), and dead/inconsistent dependency
declarations.

## Resolution log

- Finding 1: resolved per 0005 §Finding-1; added meta-anchor
  `test_fixtures_reproducible_from_generator` to TEST_SPEC.md
  citing REQ-SEC-006. Vacuously passes at Goal-0 (empty fixture
  dir); activates as Phase-1 fixtures are added.
- Finding 2: resolved per 0005 §Finding-2; rewrote REPO_SETUP.md
  §3 intro to describe the section as a content walkthrough of
  the §2 bootstrap commit (auditor option b); changed each Step
  3.N's closing `Commit:` label to `Section of bootstrap commit:`
  so the contradiction with §2's single `git add . && git commit`
  is gone.
- Finding 3: resolved per 0005 §Finding-3; dropped the untyped
  `pytest_configure(config):` stub from REPO_SETUP.md §3.6.1
  `tests/conftest.py`; replaced with a docstring-only module so
  `mypy --strict` has nothing to flag. Finding 23 will add a
  type-annotated `pytest_addoption` to the same file.
- Finding 12: resolved per 0005 §Finding-12; aligned TESTING.md
  §7's pre-commit description to use `-m "phase1 or meta"`,
  matching WORKFLOW.md §2 and REPO_SETUP.md §3.4.
- Finding 15: resolved per 0005 §Finding-15; removed the
  conditional `tomli >= 2.0; python_version < '3.11'` dependency
  from REPO_SETUP.md §3.3 (dead because `requires-python >= 3.11`
  blocks 3.10); rewrote PROJECT.md §11 to name `tomllib` (stdlib)
  with explicit rationale.
- Finding 19: resolved per 0005 §Finding-19; rewrote AGENTS.md
  §"Self-audit before setup work" to use `NNNN-` placeholders with
  a `-pass-N` suffix convention, and added explicit guidance to
  read prior passes from `docs/decisions/archive/` before
  producing new findings. Updated REPO_SETUP.md §3.5 doc list and
  §8 done-list to use the same path-abstract form.
- Finding 20: resolved per 0005 §Finding-20; rewrote REPO_SETUP.md
  §3.2 to unconditionally generate the MIT LICENSE via
  `gh api /licenses/mit`. The prior "if it isn't there" conditional
  was inherited from a flow that passed `--license=mit` to
  `gh repo create`; §2 now explicitly omits that flag, so the
  conditional was an always-taken branch.
