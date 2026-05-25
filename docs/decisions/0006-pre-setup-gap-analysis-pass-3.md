# 0006 — Pre-setup gap analysis (pass 3)

- **Status:** proposed
- **Date:** 2026-05-24
- **Author:** Claude Code (claude-opus-4-7) — third-pass audit
- **Related ADRs:** archive/0001 (pass-1 audit, resolved),
  0002 (pass-1 resolution plan),
  0003 (name + license),
  archive/0004 (pass-2 audit, resolved),
  0005 (pass-2 resolution plan)
- **Related REQ-IDs:** (none — this is meta)
- **Related anchors:** (none — this is meta)

## Context

Third independent read of the full documentation set prior to Goal 0
execution. Per the pass-3 invocation, I did not read the archived
gap analyses (0001, 0004) or their resolution ADRs (0002, 0005);
the goal is a cold review uncoloured by prior framings.

Files read in full: `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`,
`docs/REQUIREMENTS.md`, `docs/TESTING.md`, `docs/TEST_SPEC.md`,
`docs/WORKFLOW.md`, `docs/REPO_SETUP.md`, `README.md`, `NOTES.md`,
`docs/decisions/TEMPLATE.md`, `docs/decisions/0003-name-and-license.md`.

I also checked the live working tree state to confirm pre-Goal-0
conditions (no `pyproject.toml`, no `erebus/`, no `tests/`, no
`.github/`, no `scripts/`).

## Findings

### Finding 1 — Pre-commit `mypy` hook will fail on `tests/conftest.py` at the very first bootstrap commit

- **Axis:** 1 (internal contradictions), 7 (tool assumptions)
- **Severity:** MUST-resolve
- **Evidence:** `docs/REPO_SETUP.md` §3.4 declares the mypy hook as

  ```yaml
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.10.0
    hooks:
      - id: mypy
        additional_dependencies:
          - pydantic >= 2.7
          - typer >= 0.12
        args: [--strict]
  ```

  `docs/REPO_SETUP.md` §3.6.1 commits `tests/conftest.py`:

  ```python
  if TYPE_CHECKING:
      import pytest

  def pytest_addoption(parser: pytest.Parser) -> None:
      ...
  ```

  `pyproject.toml` §3.3 sets `strict = true` and does not exclude
  `tests/` from mypy's purview.

- **Issue:** `mirrors-mypy` runs in an isolated environment populated
  only by `additional_dependencies`. `pytest` is not listed, so mypy
  cannot resolve the `import pytest` (TYPE_CHECKING is a runtime
  guard; mypy still evaluates the branch). Under `--strict`, this
  raises `Cannot find implementation or library stub for module
  named "pytest"` and the hook exits non-zero. The first
  `git commit -m "chore: initial bootstrap"` is blocked. Per
  `AGENTS.md` §"No `--no-verify` on commits" the agent may not bypass
  it. The bootstrap stalls before producing any commit.

  The CI `lint-and-type` job does not hit this because `uv sync
  --extra dev` puts `pytest` in the venv that `uv run mypy .` uses.
  Pre-commit and CI disagree.

- **Suggested resolution:** Add `pytest >= 8.0` to the mypy hook's
  `additional_dependencies` in `.pre-commit-config.yaml`. Or, set
  `ignore_missing_imports = true` for the `pytest` module in
  `pyproject.toml [[tool.mypy.overrides]]`. The first option is
  preferred because it keeps strict checking on `pytest.Parser`
  calls.

### Finding 2 — `test-integration` CI job exits 5 (no tests collected) at bootstrap and turns `main` red on day one

- **Axis:** 1 (internal contradictions), 6 (workflow gaps)
- **Severity:** MUST-resolve
- **Evidence:** `docs/REPO_SETUP.md` §3.7 defines:

  ```yaml
  test-integration:
    runs-on: ubuntu-latest
    steps:
      ...
      - run: uv run pytest tests/integration -m phase1
  ```

  §3.6 creates `tests/integration/` via `mkdir -p` but §3.6.1 places
  no test files inside it; the only bootstrap tests are
  `tests/unit/test_smoke.py`, `tests/meta/test_anchors.py`, and
  `tests/meta/test_bootstrap.py`. §3.6.1 explicitly notes that
  "Phase-1 stage anchors … are NOT created at Goal 0."

  `pyproject.toml` `addopts = "-ra --strict-markers"` contains no
  flag that swallows exit-code 5.

- **Issue:** With no files under `tests/integration/`, `pytest` exits
  with status 5 ("no tests ran"), which fails the GitHub Actions
  step. The `test-integration` job is in the required-status-checks
  set for branch protection (§4) and on the PR checklist
  (`WORKFLOW.md` §3.3). Goal-0 completion criterion §8 "Latest CI
  run on `main` is green" cannot be met until the first integration
  test lands — which by design does not happen at Goal 0.

  (The `test-e2e` workflow is shielded by its `paths:` filter and is
  not required; `test-integration` has neither shield.)

- **Suggested resolution:** Add a placeholder
  `tests/integration/test_smoke.py` to §3.6.1 mirroring
  `tests/unit/test_smoke.py` (single `@pytest.mark.phase1` test that
  asserts `True`). An alternative is to wrap the CI step as
  `uv run pytest tests/integration -m phase1 || [ $? -eq 5 ]`, but
  that masks future genuine "all tests filtered out" regressions.
  The placeholder is cleaner.

### Finding 3 — `test_adr_files_match_template` enforces "Decision" and "Consequences" sections that gap-analysis ADRs do not have

- **Axis:** 1 (internal contradictions), 4 (anti-tautology vs over-strictness)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md` lines 558-571:

  ```
  ### test_adr_files_match_template — REQ-DOC-003
  ...
  - **Assertions:**
    - Each ADR has a level-1 heading matching the pattern
      `# NNNN — <title>`.
    - Each ADR contains a `Status:`, `Date:`, `Author(s):` line.
    - Each ADR has level-2 sections "Context", "Decision",
      "Consequences".
  ```

  The pass-3 invocation prompt (and by inheritance this file) uses
  sections `## Context`, `## Findings`, `## Summary`,
  `## Resolution log`. There is no `## Decision` or `## Consequences`.
  The same is true of any prior gap-analysis ADR in the same shape,
  and likely of any resolution ADR.

- **Issue:** When `test_adr_files_match_template` is implemented as a
  real pytest function in Phase 1, it will scan every file in
  `docs/decisions/` and fail on every gap-analysis ADR currently
  living there (including this one, until it is archived). It would
  also fail on `0002-pre-setup-resolutions.md` and
  `0005-pass-2-resolutions.md` if they likewise diverge from the
  decision template (I deliberately did not read them per the pass-3
  instructions, so the failure surface is at least the pass-N audits
  themselves).

- **Suggested resolution:** Either (a) loosen the anchor's third
  assertion to accept the alternative section set used by
  audits/resolutions, (b) carve out an exception via filename
  pattern (e.g. files matching `*-pre-setup-gap-analysis*.md` or
  `*-resolutions.md` use a different template), or (c) add a sibling
  `TEMPLATE-AUDIT.md` and tag each ADR with `template: <which>` in
  frontmatter so the assertion can branch on that. Option (b) is the
  smallest change.

### Finding 4 — REQ-ARCH-005 forbids hard-coded preset values, but its anchor explicitly permits them in pydantic schemas

- **Axis:** 3 (ambiguity in requirements)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REQUIREMENTS.md` REQ-ARCH-005:

  > All preset values MUST live in `presets/*.toml`. No preset values
  > MAY be hard-coded in Python source.

  `docs/TEST_SPEC.md` `test_no_preset_values_hardcoded_in_source`:

  > AST scan finds no numeric literals in fields named `brightness`,
  > `contrast`, `lowpass_hz`, `volume_db`, etc. outside of `tests/`,
  > **`presets/`, and explicit defaults in pydantic schemas**.

- **Issue:** The REQ text is absolute ("No preset values MAY be
  hard-coded"); the anchor carves out an exception the REQ does not
  mention. Two implementations both satisfy the REQ-as-written:
  (a) every preset key requires a TOML value, no schema defaults,
  pydantic fields are all `Field(...)` required; (b) schema defaults
  for every key, TOML overrides only. Implementation (b) passes the
  anchor; the REQ does not clearly distinguish.

- **Suggested resolution:** Decide whether defaults belong in TOML
  or in schemas, then update REQ-ARCH-005 to reflect that. A
  defensible carve-out wording: "Default values MAY live in pydantic
  field defaults as long as every key in the canonical preset
  (`cyberpsycho.toml`) is also set in TOML." That brings anchor and
  REQ into agreement.

### Finding 5 — REPO_SETUP.md §1 pre-flight reads `pyproject.toml`, which §3.3 creates later

- **Axis:** 6 (workflow gaps), 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REPO_SETUP.md` §1 instructs the agent to run,
  before bootstrapping, a yt-dlp version check that begins:

  ```bash
  YT_DLP_MIN=$(python3 -c "import tomllib, pathlib; \
    deps = tomllib.loads(pathlib.Path('pyproject.toml').read_text())...")
  ```

  §3.3 is the step that creates `pyproject.toml`. The live working
  tree confirms `pyproject.toml` does not yet exist (verified by
  `ls` on `/Users/rookslog/Development/erebus`).

- **Issue:** An agent reading §1 as the literal first step encounters
  `FileNotFoundError: pyproject.toml` and either has to re-order the
  documented procedure (deciding for itself which steps to defer) or
  fall back to a hardcoded floor. Both responses are escape hatches
  the agent shouldn't have to invent.

- **Suggested resolution:** Move the dynamic version-floor parse
  into §3.3 (right after `pyproject.toml` is written) and have §1
  perform a simple `yt-dlp --version` presence check only. Or
  hard-code the current floor (`2024.7.16`) inside §1 with a comment
  saying it is kept in sync manually with `pyproject.toml`. Either
  breaks the cycle.

### Finding 6 — TEST_SPEC.md anchor names do not match the bootstrap meta-test function names

- **Axis:** 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md` lines 524-543 name the
  docs-consistency anchors:

  - `test_every_req_id_has_test_anchor`
  - `test_every_anchor_has_test_function`

  `docs/REPO_SETUP.md` §3.6.1's `tests/meta/test_anchors.py` defines
  functions:

  - `test_every_must_req_has_anchor_citation`
  - `test_every_anchor_cites_valid_req`

  Neither function carries `@pytest.mark.anchor("...")`.

- **Issue:** `TESTING.md` §3 commits to anchor stability: "Once
  written and merged, their name doesn't change." The bootstrap
  ships implementations that materially do the work of the
  TEST_SPEC anchors under different names and without the `anchor`
  mark. When `test_every_anchor_has_test_function` is itself
  implemented in Phase 1, it will not find a
  `@pytest.mark.anchor("test_every_anchor_has_test_function")` and
  will report a missing implementation — unless a Phase-1 PR
  renames the bootstrap functions (which itself violates anchor
  stability) or adds the marker.

  Smaller secondary issue: the regex `ANCHOR_REQ_REF` in the
  bootstrap meta-test only matches headings of the form
  `### test_<name> — REQ-<id>`. It will not pick up the
  `(Cross-references: REQ-CLI-001, …)` body line under
  `test_phase1_integration`. I verified all cross-referenced REQs
  are also cited in their own per-stage anchor headings, so coverage
  still passes — but a future REQ that is only ever cross-referenced
  would silently slip through.

- **Suggested resolution:** Pick one. Either (a) rename the
  TEST_SPEC anchors to match the bootstrap functions and record the
  rename as the one allowed exception in this ADR; or (b) rename the
  bootstrap functions to the anchor names and add
  `@pytest.mark.anchor`. (b) is more consistent with the stability
  rule. While doing this, add a comment in
  `tests/meta/test_anchors.py` noting that cross-reference body
  lines are intentionally not parsed (or extend the regex to cover
  them).

### Finding 7 — `test_caption_fade_timing` assertion is vague about how the alpha envelope is extracted

- **Axis:** 3 (ambiguity), 4 (anti-tautology)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md` lines 289-300:

  ```
  ### test_caption_fade_timing — REQ-CAPTION-003
  ...
  - **Assertions:**
    - The generated alpha envelope (extractable from the drawtext
      expression) has the three phases at the right boundaries.
  - **Anti-tautology:** Hard-coding the values to wrong defaults
    fails.
  ```

  Compare with `test_caption_enable_expression_is_generated` two
  entries up, which spells out exact interval starts.

- **Issue:** `drawtext` has no first-class "alpha envelope"
  parameter. Implementations would land on one of: `alpha='if(…)'`
  on the drawtext filter, a `fade` filter wrapper, or splitting the
  caption into three sub-clauses with weights. The anchor cannot
  distinguish a correct implementation from an off-by-one
  implementation without committing to a specific extraction method.
  Two reasonable implementations could both "satisfy" the anchor
  while producing materially different fade behaviour.

- **Suggested resolution:** Decide on the mechanism (recommend:
  `alpha='if(lt(t-t0, fade_in_ms/1000), …, …)'` per caption), then
  rewrite the anchor with the same level of concrete arithmetic as
  the enable-expression anchor — numeric expected values at the
  fade-in start, fade-in end, hold end, and fade-out end.

### Finding 8 — AGENTS.md §"Self-audit" instructs the agent to read archived audits; the pass-3 invocation explicitly forbids it

- **Axis:** 1 (internal contradictions), 10 (other)
- **Severity:** SHOULD-resolve
- **Evidence:** `AGENTS.md` lines 180-183:

  > Prior passes live in `docs/decisions/archive/` after their MUST
  > items have been resolved. Read those archives before producing
  > your own findings so you do not re-raise issues that have
  > already been addressed.

  The pass-3 invocation given to me by Logan says:

  > Do not read the archived 0001 or 0004 or their resolution plans
  > (0002, 0005). Auditing the current docs cold avoids anchoring
  > on prior frames.

- **Issue:** A future agent triggered by AGENTS.md alone (no pass-N
  invocation prompt) would read the archives by default. A future
  agent given a pass-N invocation that overrides AGENTS.md has no
  place in AGENTS.md acknowledging the override pattern, so it might
  choose to follow AGENTS.md anyway. The two protocols are at odds;
  the right behaviour depends on which one Logan considers
  authoritative, and that choice is invisible to the reader.

- **Suggested resolution:** Add one sentence to AGENTS.md §"Self-
  audit" noting that subsequent passes may be invoked with a "cold-
  read" override prompt and that the override wins. The invocation
  prompts already encode this; AGENTS.md should acknowledge it so
  the rule isn't silent.

### Finding 9 — `test_mix_uses_two_stream_amix` second assertion is trivially true

- **Axis:** 4 (anti-tautology)
- **Severity:** CONSIDER
- **Evidence:** `docs/TEST_SPEC.md` lines 349-361:

  ```
  - **Assertions:**
    - The constructed filter graph contains exactly one `amix` node
      with `inputs=2`.
    - Replacing one input with a silent track produces output where
      that stream's contribution is silent (proving the stream
      entered the mix).
  ```

- **Issue:** Silence in produces silence out for any additive mix;
  the assertion doesn't actually prove the silent stream "entered"
  anything — a single-stream pass-through with the music branch
  detached entirely would also produce silence on that branch.

- **Suggested resolution:** Replace the silent track with a unique
  test tone (e.g. a 1 kHz sine) and assert that the tone is present
  in the output at the expected loudness. Symmetric across both
  inputs.

### Finding 10 — `test_concat_lossless_when_inputs_match` time-heuristic threshold is unstated

- **Axis:** 3 (ambiguity)
- **Severity:** CONSIDER
- **Evidence:** `docs/TEST_SPEC.md` lines 156-170:

  ```
  - Total elapsed time is less than would be required for full
    re-encode of the inputs (heuristic threshold).
  ```

- **Issue:** No threshold value, no formula, no reference point. A
  test author could pick a number and a reviewer would have no
  basis to push back. CI variance on hosted runners would flake any
  aggressive threshold.

- **Suggested resolution:** Drop the time heuristic. The bitrate
  check on its own already discriminates demuxer-concat from
  re-encode-concat in practice (re-encode at default CRF lands
  outside a 5% bitrate window). If the time check is kept, give it
  a concrete fraction (e.g. "elapsed < 0.25 × duration of inputs")
  and acknowledge CI flakiness in the anchor.

### Finding 11 — Three independent secret-scan invocations cover the same ground

- **Axis:** 5 (guardrails), 7 (tool assumptions)
- **Severity:** CONSIDER
- **Evidence:** Gitleaks runs in three places:
  - `pre-commit-config.yaml` §3.4 — `gitleaks` hook on every commit
    (`stages: [pre-commit, manual]`).
  - `.github/workflows/ci.yml` §3.7 — dedicated `gitleaks` job that
    runs `pre-commit run --hook-stage manual gitleaks --all-files`.
  - `docs/TEST_SPEC.md` `test_no_secrets_in_repo` — same command
    again, this time via `pytest`, picked up by `docs-consistency`.

- **Issue:** Three scans of the same tree by the same tool. No
  meaningful coverage gain, three places to keep in sync if the
  gitleaks rev bumps. CI time tax.

- **Suggested resolution:** Pick two: pre-commit (developer
  feedback) and the dedicated CI job (PR gate). Drop
  `test_no_secrets_in_repo` from the meta suite, or rewrite it to
  assert something else REQ-SEC-003 cares about (e.g. that `.env*`
  is gitignored). REQ-SEC-003 stays covered.

### Finding 12 — `test-unit-meta` installs ffmpeg on macOS for tests that do not need it

- **Axis:** 7 (tool assumptions)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §3.7 `test-unit-meta` job:

  ```yaml
  - name: Install ffmpeg
    run: |
      if [[ "${{ matrix.os }}" == "ubuntu-latest" ]]; then
        sudo apt-get update && sudo apt-get install -y ffmpeg
      else
        brew install ffmpeg
      fi
  ```

  The unit + meta suite at bootstrap (and through most of Phase 1)
  is pytest meta-tests and stage signature tests — no `ffmpeg`
  invocation. `brew install ffmpeg` on macOS GitHub-hosted runners
  takes several minutes per run and pulls dozens of bottle
  dependencies.

- **Issue:** Wasted CI minutes on every PR. The integration job
  needs ffmpeg; the unit + meta job does not.

- **Suggested resolution:** Drop the install step from
  `test-unit-meta`. When/if any unit test grows an ffmpeg
  dependency, add it back.

### Finding 13 — `mkdir -p lab/clips` does not commit anything; the `.gitkeep` whitelist in `.gitignore` has no file to permit

- **Axis:** 1 (internal contradictions), 6 (workflow gaps)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §3.1 includes:

  ```
  !lab/clips/.gitkeep
  !lab/outputs/.gitkeep
  ```

  §3.6 does `mkdir -p presets lab/clips` but does not `touch
  lab/clips/.gitkeep` or create `lab/outputs/` at all.

- **Issue:** The bootstrap commit does not include the empty `lab/`
  subtree. A fresh clone has no `lab/clips/` directory, so a user
  running the `erebus lab apply` example in README needs to `mkdir`
  it before populating it. The `.gitkeep` carve-outs in `.gitignore`
  are dead code as written.

- **Suggested resolution:** Either (a) `touch lab/clips/.gitkeep
  lab/outputs/.gitkeep` in §3.6 (then both directories ship in the
  bootstrap commit, matching the `.gitignore` carve-outs), or (b)
  remove the `!lab/clips/.gitkeep` and `!lab/outputs/.gitkeep` lines
  from `.gitignore` and let users create the dirs on demand.
  (a) is friendlier to the README example.

### Finding 14 — `pyproject.toml [tool.mypy]` mixes `strict = true` with redundant sub-flags

- **Axis:** 10 (other)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §3.3:

  ```toml
  [tool.mypy]
  python_version = "3.11"
  strict = true
  warn_return_any = true
  warn_unreachable = true
  disallow_untyped_defs = true
  ```

- **Issue:** `strict = true` already implies `disallow_untyped_defs`,
  `warn_return_any`, and others. The explicit sub-flags do not change
  behaviour but make a future reader wonder whether a divergence is
  intended.

- **Suggested resolution:** Drop the redundant sub-flags. Keep
  `warn_unreachable = true` (not part of strict). Or, drop
  `strict = true` and spell out only the desired flags. The current
  mix is the most confusing of the three options.

## Summary

- 14 findings total: 2 MUST-resolve, 6 SHOULD-resolve, 6 CONSIDER.
- Setup work blocks until each MUST-resolve item has a resolution
  recorded. Findings 1 and 2 will physically prevent Goal 0 from
  completing: Finding 1 stops the first bootstrap commit (pre-commit
  blocks); Finding 2 stops the first CI run on `main` from going
  green (a required check fails). Both are small fixes — one line in
  `.pre-commit-config.yaml` and one new file under
  `tests/integration/`.

## Resolution log

- Finding 1: resolved per 0007 §Finding-1; added
  `pytest >= 8.0` to the `.pre-commit-config.yaml` mypy hook's
  `additional_dependencies` in REPO_SETUP.md §3.4 so mypy's
  isolated pre-commit env can resolve the conftest's
  TYPE_CHECKING `import pytest`.
- Finding 2: resolved per 0007 §Finding-2; added a placeholder
  `tests/integration/test_smoke.py` to REPO_SETUP.md §3.6.1
  mirroring `tests/unit/test_smoke.py`. `pytest tests/integration
  -m phase1` now collects one test and exits 0 instead of 5, so the
  required `test-integration` CI job goes green on the first run
  on `main`.
