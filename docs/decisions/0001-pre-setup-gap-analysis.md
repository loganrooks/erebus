# 0001 - Pre-setup gap analysis

- **Status:** proposed
- **Date:** 2026-05-24
- **Author:** Codex
- **Related REQ-IDs:** (none - this is meta)
- **Related anchors:** (none - this is meta)

## Context

This audit reviewed the Goal 0 documentation set before any setup work:
`PROJECT.md`, `AGENTS.md`, `CLAUDE.md`, `docs/REQUIREMENTS.md`,
`docs/TESTING.md`, `docs/TEST_SPEC.md`, `docs/WORKFLOW.md`,
`docs/REPO_SETUP.md`, `README.md`, `NOTES.md`, `docs/decisions/TEMPLATE.md`,
and the review prompts under `docs/review-prompts/`. The goal requires this
file to be produced and surfaced before repository bootstrap, CI setup,
branch protection, or commits begin.

## Findings

### Finding 1 - REQ to anchor coverage is not complete

- **Axis:** 2 - REQ <-> anchor coverage
- **Severity:** MUST-resolve
- **Evidence:** `docs/REQUIREMENTS.md:3-7` says the REQ-ID to anchor
  cross-reference is 1:1 and CI-enforced. `docs/REQUIREMENTS.md:359-364`
  requires every REQ-ID to be referenced by at least one test anchor. The
  anchors listed in `docs/TEST_SPEC.md:29-511` do not reference these REQ-IDs:
  `REQ-CAPTION-001`, `REQ-CLI-003`, `REQ-DOC-003`, `REQ-ENCODE-003`,
  `REQ-INGEST-005`, `REQ-LAB-003`, `REQ-MIX-001`, `REQ-MIX-003`,
  `REQ-OBS-003`, `REQ-SEC-005`, and `REQ-VIZ-003`.
- **Issue:** Goal 0 cannot honestly claim docs-consistency enforcement while
  the current docs are already inconsistent. Three missing IDs are MUST
  requirements: `REQ-CAPTION-001`, `REQ-MIX-001`, and `REQ-MIX-003`.
- **Suggested resolution:** Add explicit anchors for each missing REQ-ID or
  change the requirement scope/status with an ADR. If SHOULD requirements are
  intentionally not anchor-gated, rewrite `REQ-DOC-001` and the consistency
  checker contract to say so.

### Finding 2 - TEST_SPEC includes an anchor without a REQ-ID

- **Axis:** 2 - REQ <-> anchor coverage
- **Severity:** MUST-resolve
- **Evidence:** `docs/TEST_SPEC.md:7-19` defines the per-anchor format as
  `test_<name> - REQ-<ID>[, REQ-<ID>...]`. `docs/TEST_SPEC.md:511-530`
  defines `test_phase1_integration - Phase-1 verification surface` with no
  REQ-ID.
- **Issue:** The meta-test requirement says every test anchor's REQ-ID must
  exist in `REQUIREMENTS.md`, but this anchor has no REQ-ID to validate. It
  will either fail the intended parser or require a special case that is not
  documented.
- **Suggested resolution:** Attach the integration anchor to a defined REQ-ID,
  create a new integration/docs REQ for the phase-level acceptance test, or
  explicitly classify this as a non-anchor verification test outside the
  docs-consistency contract.

### Finding 3 - "1:1" coverage conflicts with multi-REQ anchors

- **Axis:** 1 - Internal contradictions
- **Severity:** MUST-resolve
- **Evidence:** `docs/REQUIREMENTS.md:3-7` says the cross-reference between
  REQ-IDs and test anchors is 1:1. `docs/TESTING.md:71-72` says a TDD anchor
  encodes one requirement, "one REQ-ID, sometimes more." `docs/TEST_SPEC.md`
  contains multi-REQ anchors at lines 106, 194, and 360.
- **Issue:** The docs use "1:1" to mean different things. A strict 1:1 checker
  would reject the current TEST_SPEC, while a many-to-many checker contradicts
  the wording in REQUIREMENTS.md.
- **Suggested resolution:** Pick the intended model. If anchors may cover
  multiple REQs, replace "1:1" with "complete bidirectional coverage" and define
  the parser rules. If true 1:1 is intended, split the multi-REQ anchors.

### Finding 4 - CI check names do not match the required checks

- **Axis:** 1 - Internal contradictions
- **Severity:** MUST-resolve
- **Evidence:** `docs/WORKFLOW.md:134-143` lists required checks named
  `ruff-check`, `ruff-format`, `mypy`, `pytest-unit`, `pytest-integration`,
  `pytest-meta`, `gitleaks`, and `docs-consistency`. `docs/REPO_SETUP.md:311-389`
  defines jobs named `lint-and-type`, `test-unit-meta`, `test-integration`,
  `test-e2e`, `gitleaks`, and `docs-consistency`. `docs/REPO_SETUP.md:411-420`
  configures branch protection for `lint-and-type`, matrix variants of
  `test-unit-meta`, `test-integration`, `gitleaks`, and `docs-consistency`.
- **Issue:** The workflow, branch protection, and goal verification language do
  not name the same checks. The final objective requires CI to include
  ruff-check, ruff-format, mypy, pytest, and docs-consistency, but the proposed
  workflow groups ruff and mypy under one job.
- **Suggested resolution:** Either split the CI jobs so the status check names
  match WORKFLOW.md and the goal, or update WORKFLOW.md, REPO_SETUP.md, and the
  branch protection JSON to one canonical check list.

### Finding 5 - Goal 0 cannot reach green CI with only the documented skeleton

- **Axis:** 6 - Workflow gaps
- **Severity:** MUST-resolve
- **Evidence:** `docs/REPO_SETUP.md:257-289` creates only empty Python files and
  test directories. `docs/REPO_SETUP.md:382-389` runs
  `uv run pytest tests/meta -m meta`. `docs/REPO_SETUP.md:343-354` runs unit,
  meta, and integration tests. No setup step defines the actual meta tests,
  unit tests, fixtures, or minimal implementation needed for pytest to collect
  and pass.
- **Issue:** Empty test directories generally produce a pytest "no tests
  collected" failure, and the docs-consistency job has no specified test file to
  run. This makes the initial green CI criterion underspecified and likely
  unachievable as written.
- **Suggested resolution:** Add a bootstrap test/skeleton section that creates
  passing meta tests, placeholder unit tests, fixtures where needed, and minimal
  importable code. Define whether Phase-1 anchors start as skipped/red after
  Goal 0 or are not materialized until Goal 1.

### Finding 6 - Security wrapper path contradicts the source layout

- **Axis:** 1 - Internal contradictions
- **Severity:** MUST-resolve
- **Evidence:** `AGENTS.md:34-37` requires every `ffmpeg`, `yt-dlp`, and
  `ffprobe` call to go through wrappers in `erebus/ffmpeg/` and
  `erebus/ingest/`. `docs/REPO_SETUP.md:257-279` creates `erebus/ffmpeg/` and
  `erebus/stages/ingest.py`, but no `erebus/ingest/` package.
- **Issue:** Agents cannot follow the non-negotiable wrapper rule because one
  named wrapper package does not exist in the planned layout.
- **Suggested resolution:** Either add `erebus/ingest/` to the source tree and
  define its wrapper contract, or rewrite AGENTS.md to point yt-dlp calls at the
  actual planned wrapper location.

### Finding 7 - Tool and dependency pinning is inconsistent

- **Axis:** 7 - Tool and dependency assumptions
- **Severity:** MUST-resolve
- **Evidence:** `PROJECT.md:405-410` says Python dependencies are "pinned in
  pyproject.toml." `docs/REPO_SETUP.md:124-139` uses lower bounds rather than
  exact pins. `docs/REQUIREMENTS.md:322-326` says the required `yt-dlp` version
  shall be pinned in `pyproject.toml`, while `docs/REPO_SETUP.md:342`,
  `docs/REPO_SETUP.md:353`, and `docs/REPO_SETUP.md:369` install unpinned
  `yt-dlp` via `uv pip install yt-dlp`.
- **Issue:** The setup plan cannot satisfy the pinning claims. It also leaves
  host tools from `docs/REPO_SETUP.md:16-24` mostly version-bounded or
  unbounded rather than pinned.
- **Suggested resolution:** Decide whether "pinned" means exact versions in
  `pyproject.toml`/`uv.lock`, lower-bound compatibility ranges, or host preflight
  minimums. Then update PROJECT.md, REQUIREMENTS.md, and REPO_SETUP.md to match.

### Finding 8 - Gitleaks is required by tests but not guaranteed locally

- **Axis:** 7 - Tool and dependency assumptions
- **Severity:** MUST-resolve
- **Evidence:** `docs/TEST_SPEC.md:427-435` says
  `test_no_secrets_in_repo` runs `gitleaks detect ...`. `docs/REPO_SETUP.md:131-139`
  does not include gitleaks in the dev extras. `docs/REPO_SETUP.md:213-216`
  adds the gitleaks pre-commit hook, and `docs/REPO_SETUP.md:372-380` uses the
  GitHub Action.
- **Issue:** The meta-test may fail locally and in CI unless a `gitleaks`
  binary is independently available. The pre-commit hook and GitHub Action do
  not necessarily put a `gitleaks` executable on PATH for `uv run pytest`.
- **Suggested resolution:** Add a documented installation path for the gitleaks
  binary, change the meta-test to use a vendored/pre-commit-managed invocation,
  or define "equivalent" scanning in a way the test can execute deterministically.

### Finding 9 - The no-bypass guardrails are policy-only, not CI-enforced

- **Axis:** 5 - Missing guardrails
- **Severity:** SHOULD-resolve
- **Evidence:** `AGENTS.md:39-48` forbids `--no-verify`,
  `--dangerously-skip-permissions`, and equivalent flags. `docs/WORKFLOW.md:89-99`
  treats use of these flags as a hard violation. The CI workflow in
  `docs/REPO_SETUP.md:311-389` contains no job that inspects commit messages,
  reflog, PR text, or diffs for these flags.
- **Issue:** CI will not detect a committed bypass unless the string appears in
  a scanned file and is noticed by review. The documented "hard violation" is
  enforced by process, not by a guardrail.
- **Suggested resolution:** Add a CI check that scans commit messages and diffs
  for forbidden bypass flags, or explicitly document this as a manual
  review-only rule.

### Finding 10 - Pre-commit and CI marker selections do not line up

- **Axis:** 5 - Missing guardrails
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/WORKFLOW.md:80-85` says pre-commit runs
  `pytest tests/unit tests/meta -m phase1`. `docs/REPO_SETUP.md:220-225` uses
  the same command. `docs/REPO_SETUP.md:389` runs docs consistency with
  `pytest tests/meta -m meta`. `docs/TESTING.md:128-133` defines meta tests as
  a separate meta-test layer.
- **Issue:** If docs-consistency tests are marked only `meta`, local pre-commit
  will not run them. If they are marked only `phase1`, the docs-consistency CI
  job will not run them. The marker policy is not specified.
- **Suggested resolution:** State that docs-consistency tests must carry both
  `phase1` and `meta`, or change the commands to a shared expression such as
  `-m "phase1 or meta"`.

### Finding 11 - Cross-vendor review is required but not gateable as written

- **Axis:** 6 - Workflow gaps
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/WORKFLOW.md:183-191` marks stage, phase, recovery, and
  pre-setup reviews as required. `docs/WORKFLOW.md:215-230` writes review
  artifacts and posts PR comments manually. `docs/REPO_SETUP.md:525-526` makes
  post-setup review part of Goal 0 completion.
- **Issue:** There is no CI gate, branch protection status, or fallback path if
  `claude -p` is unavailable, rate-limited, or returns an unusable report. The
  process is required but cannot be mechanically required by the proposed branch
  protection.
- **Suggested resolution:** Add a manual required checklist item with explicit
  fallback approval criteria, or create a CI status/check that verifies the
  expected review artifact exists and contains no MUST-fix items.

### Finding 12 - Stage review depends on an undefined renderer script

- **Axis:** 6 - Workflow gaps
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/WORKFLOW.md:223-226` invokes
  `uv run python scripts/render_review.py ...`. `docs/REPO_SETUP.md:237-253`
  lists docs to create, and `docs/REPO_SETUP.md:257-289` creates source/test
  skeleton directories, but neither creates `scripts/render_review.py`.
- **Issue:** The documented review checkpoint cannot be executed from the
  bootstrap files alone.
- **Suggested resolution:** Add `scripts/render_review.py` to the bootstrap
  file list with tests, or remove the render step and store/post the JSON
  directly.

### Finding 13 - Recovery procedures rely on tools outside the allowed setup set

- **Axis:** 6 - Workflow gaps
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/WORKFLOW.md:429-433` tells maintainers to install and run
  `git-filter-repo` during a secret incident. The Goal 0 objective says to use
  only git, gh CLI, uv, ruff, mypy, pytest, pre-commit, and standard GitHub
  Actions. `docs/REPO_SETUP.md:16-24` also does not preflight `git-filter-repo`.
- **Issue:** The recovery path for the most serious incident cannot be followed
  under the tool boundary stated for setup work.
- **Suggested resolution:** Add an explicit exception for emergency recovery
  tools, preflight/document `git-filter-repo`, or replace the recovery procedure
  with an allowed-tool path plus a human escalation step.

### Finding 14 - README references LICENSE before setup guarantees it exists

- **Axis:** 1 - Internal contradictions
- **Severity:** SHOULD-resolve
- **Evidence:** `README.md:72-74` says "MIT. See `LICENSE`." The current
  document map in `PROJECT.md:70-87` does not list `LICENSE`, while
  `docs/REPO_SETUP.md:100-111` creates it as a setup step and Goal 0 requires
  the chosen license.
- **Issue:** The public README is already written as if LICENSE exists, but
  LICENSE is not present in the current pre-bootstrap directory and is not part
  of the PROJECT.md document map.
- **Suggested resolution:** Add LICENSE to the document map and ensure the
  setup sequence creates it before README is committed, or make README's license
  line part of the README step after LICENSE exists.

### Finding 15 - Current workspace is not a Git repository

- **Axis:** 10 - Anything else
- **Severity:** SHOULD-resolve
- **Evidence:** Running `git status --short --branch` in
  `/Users/rookslog/Development/erebus` exits with `fatal: not a git repository
  (or any of the parent directories): .git`. `docs/REPO_SETUP.md:30-43` assumes
  repository creation and clone into a fresh `erebus` directory.
- **Issue:** The live workspace already contains the documentation files but is
  not a Git checkout. If the setup sequence blindly runs `gh repo clone
  loganrooks/erebus`, it will conflict with the existing directory name or
  create a second checkout elsewhere.
- **Suggested resolution:** Decide whether this directory should become the git
  repository via `git init`/remote setup after approval, or whether the docs
  should be copied into a fresh clone. Record the chosen path before setup work
  begins.

### Finding 16 - Public fixtures and lab clips are not provenance-gated

- **Axis:** 8 - Public-repo risks
- **Severity:** CONSIDER
- **Evidence:** `docs/TESTING.md:166-182` defines committed fixtures and
  lab clips. `PROJECT.md:361-383` describes stable lab clips under `lab/clips/`.
  `README.md:51-63` warns users to use only content they have rights to
  download.
- **Issue:** The docs do not say how fixture and lab clip provenance will be
  verified before publication. A public repo could accidentally include
  copyrighted clips even while the README warns users not to infringe.
- **Suggested resolution:** Add a fixture provenance rule: generated synthetic
  fixtures only under `tests/fixtures/`, and lab clips either generated,
  public-domain/CC with attribution, or excluded until provenance is recorded.

### Finding 17 - Name and license public-risk checks are left to implication

- **Axis:** 8 - Public-repo risks
- **Severity:** CONSIDER
- **Evidence:** `PROJECT.md:5-9` says the working name is `erebus` and can be
  renamed. `docs/REPO_SETUP.md:45-47` notes Apache-2.0 as an alternative to MIT
  before first push. The setup steps do not require a package-name, trademark,
  or license decision check before creating the public repo.
- **Issue:** A public repository name and license are chosen before any explicit
  collision or license-fit decision is recorded.
- **Suggested resolution:** Add a preflight decision item for repository name
  and license: keep `erebus` + MIT, or choose alternatives before the first
  public push.

## Summary

- 17 findings total: 8 MUST-resolve, 7 SHOULD-resolve, 2 CONSIDER.
- The most consequential are Findings 1 through 8: the REQ/anchor map is
  incomplete, the required CI checks do not match the setup workflow, the green
  CI path lacks concrete tests, the source layout contradicts a non-negotiable
  security rule, and dependency pinning is internally inconsistent.
- Setup work should NOT begin until each MUST-resolve item is addressed in the
  relevant doc or explicitly accepted by Logan with the remaining risk recorded.

## Resolution log

- Finding 1: resolved per 0002 §Finding-1; added four anchors to
  TEST_SPEC.md — test_caption_track_start_times_from_manifest
  (REQ-CAPTION-001), test_mix_uses_two_stream_amix (REQ-MIX-001),
  test_mix_video_audio_volume_attenuated (REQ-MIX-003), and
  test_adr_files_match_template (REQ-DOC-003). The seven missing
  SHOULDs remain unanchored per the reframed coverage model
  (Finding 3/Finding 5).
- Finding 2: resolved per 0002 §Finding-2; added new
  REQ-INTEG-001 to REQUIREMENTS.md as the integration umbrella and
  cited it on test_phase1_integration. The cross-references to
  individual stage REQs remain as informational notes.
- Finding 3: resolved per 0002 §Finding-3; rewrote REQUIREMENTS.md intro
  to bidirectional many-to-many coverage; added clarifying paragraph in
  TEST_SPEC.md permitting multi-REQ citations on a single anchor.
- Finding 4: resolved per 0002 §Finding-4; aligned WORKFLOW.md's
  required-checks list and the PR template's Verification block to
  the job names defined in REPO_SETUP.md's CI workflow
  (lint-and-type, test-unit-meta {ubuntu,macos}, test-integration,
  gitleaks, docs-consistency).
- Finding 5: resolved per 0002 §Finding-5; added REPO_SETUP.md
  §3.6.1 "Bootstrap test set" (conftest, two meta tests, smoke
  unit test) so pytest collects something at Goal-0 green CI;
  reframed REQ-DOC-001 to require MUST coverage + valid-citation
  invariants without forcing every anchor to have a test function
  yet; added a "planned vs. implemented" paragraph to TESTING.md §3
  documenting the anchor lifecycle.
- Finding 6: resolved per 0002 §Finding-6; rewrote AGENTS.md
  non-negotiable rule #1 to point ffmpeg/ffprobe at
  `erebus/ffmpeg/builder.py` and yt-dlp at `erebus/stages/ingest.py`,
  removing the never-planned `erebus/ingest/` package reference.
- Finding 7: resolved per 0002 §Finding-7; PROJECT.md §11 reworded to
  "minimum versions in pyproject.toml + exact versions in uv.lock";
  REQ-SEC-005 rewritten with the same model and a pre-flight check
  obligation; REPO_SETUP.md §1 gained a yt-dlp version-floor assertion
  and §3.3 gained a uv.lock commit note.
- Finding 8: resolved per 0002 §Finding-8; switched the meta-test
  and CI job to invoke gitleaks via `pre-commit run --hook-stage
  manual gitleaks`, eliminating the host-PATH binary dependency;
  added `stages: [pre-commit, manual]` to the gitleaks hook in
  .pre-commit-config.yaml; updated REPO_SETUP.md §1 pre-flight to
  note gitleaks is pre-commit-managed.
- Finding 9: resolved per 0002 §Finding-9; appended an
  enforcement-model paragraph to WORKFLOW.md §"Why we don't bypass
  hooks" documenting the three policy layers (NOTES.md audit trail,
  stage-review checkpoint, branch-protection PR review) and noting
  a Phase-2 CI scan as a future enhancement.
- Finding 10: resolved per 0002 §Finding-10; documented the
  dual-marker convention (meta tests carry both phase1 and meta) in
  REPO_SETUP.md pyproject markers; updated pre-commit pytest entry,
  CI test-unit-meta job, and WORKFLOW.md hook description to use
  `-m "phase1 or meta"`.
- Finding 11: resolved per 0002 §Finding-11; added Enforcement +
  Fallback paths paragraphs to WORKFLOW.md §5 (Haiku fallback for
  rate-limits, NOTES.md skip + 24h retro for outage); added a
  `review-artifact-exists` CI job to REPO_SETUP.md §3.7 that checks
  for a non-empty `docs/decisions/reviews/<PR>-*.json`; added the
  job to the required-checks list in WORKFLOW.md §3 and the branch
  protection JSON in REPO_SETUP.md §4; updated PR template
  Verification block with the artifact bullet. Content gating
  (auto-block on MUST-fix) is deferred to Phase 2.
- Finding 12: resolved per 0002 §Finding-12; replaced the
  scripts/render_review.py invocation in WORKFLOW.md §5 with an
  inline jq pipeline. Soft follow-up: docs/review-prompts/stage-review.md
  needs to instruct the reviewer to emit JSON with .summary,
  .must_fix[].description, and .should_fix[].description keys for
  the jq filter to work; addressing that in the review-prompts pass
  is a separate non-blocking change.
- Finding 13:
- Finding 14: resolved per 0002 §Finding-14; added LICENSE row to
  PROJECT.md §3 document map. Setup order in REPO_SETUP.md already
  creates LICENSE (step 3.2) before README (step 3.8).
- Finding 15: resolved per 0002 §Finding-15; rewrote REPO_SETUP.md
  §2 to `git init -b main` in-place followed by `gh repo create
  --source=. --push`, with the license-collision caveat documented
  inline (drop --license=mit so the local LICENSE wins). The actual
  `git init` was performed during the resolution work itself so
  per-finding commits could land; the doc edit captures the
  canonical procedure for future bootstraps.
- Finding 16:
- Finding 17:

Once all MUST-resolve items have resolutions, change status to `resolved` and
move this file to `docs/decisions/archive/`.
