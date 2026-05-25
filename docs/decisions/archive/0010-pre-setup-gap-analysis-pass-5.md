# 0010 — Pre-setup gap analysis (pass 5)

- **Status:** resolved
- **Date:** 2026-05-24
- **Resolved:** 2026-05-24 (3 of 8 findings; 5 deferred — see
  closing note). **Pre-setup audit cycle is complete.**
- **Author(s):** Claude Code (claude-opus-4-7) — fifth-pass audit
- **Related ADRs:** archive/0001 (pass-1 audit, resolved),
  0002 (pass-1 resolution plan),
  0003 (name + license),
  archive/0004 (pass-2 audit, resolved),
  0005 (pass-2 resolution plan),
  archive/0006 (pass-3 audit, resolved),
  0007 (pass-3 resolution plan),
  archive/0008 (pass-4 audit, resolved),
  0009 (pass-4 resolution plan)
- **Related REQ-IDs:** (none — this is meta)
- **Related anchors:** (none — this is meta)

## Context

Cold-read audit of the pre-setup documentation set, performed without
reading the four archived audits (0001, 0004, 0006, 0008) or their
resolution plans (0002, 0005, 0007, 0009). The wrapper prompt for
this pass forbids reading those documents to prevent prior-pass
framing from anchoring the read.

Files read in full: `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`,
`docs/REQUIREMENTS.md`, `docs/TESTING.md`, `docs/TEST_SPEC.md`,
`docs/WORKFLOW.md`, `docs/REPO_SETUP.md`, `README.md`, `NOTES.md`.
Spot reads: `docs/decisions/TEMPLATE.md`,
`docs/decisions/0003-name-and-license.md` (short, accepted),
`docs/decisions/` and `docs/decisions/archive/` directory listings.

Findings below.

## Findings

### Finding 1 — `yt-dlp` listed only as an "External binary" in PROJECT.md §11, but is a Python dependency in pyproject.toml

- **Axis:** 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:**
  - `PROJECT.md:439` — "External binaries: `ffmpeg` ≥ 6, `yt-dlp`,
    `ffprobe`."
  - `PROJECT.md:441-446` — "Python (declared with minimum versions
    in `pyproject.toml`; exact resolved versions locked in
    `uv.lock` and committed): `typer`, `pydantic` v2, `rich`."
  - `docs/REPO_SETUP.md:180-185` — pyproject.toml
    `[project.dependencies]` includes `"yt-dlp >= 2024.7.16"`.
  - `AGENTS.md:53-56` — Rule 4: "No new dependencies without a docs
    update. If a stage needs something not in `pyproject.toml`,
    update `PROJECT.md` §11 ('Dependencies (Phase 1)') with the
    rationale, add the dep to `pyproject.toml`…"
- **Issue:** PROJECT.md §11 splits dependencies into "External
  binaries" and "Python". `yt-dlp` is declared in both forms by the
  rest of the docs: it is a binary the host pre-flight check
  verifies (`REPO_SETUP.md:22-37`), and it is a Python package
  pinned in `pyproject.toml` (`REPO_SETUP.md:184`). PROJECT.md §11
  lists it under "External binaries" only. AGENTS.md Rule 4 treats
  PROJECT.md §11 as the canonical Python-dependencies enumeration
  used to decide whether a new dep needs to be added; a reader
  following that rule would see `yt-dlp` missing from the Python
  list and either re-add it (no-op) or conclude the docs are out of
  sync with the code.
- **Suggested resolution:** Add a single line to PROJECT.md §11's
  Python paragraph noting that `yt-dlp` is also installed as a
  Python package (the binary entrypoint comes from the same wheel)
  and is pinned in pyproject.toml under the same minimum as the
  pre-flight check. Alternatively, add a sentence at the end of the
  External-binaries line: "`yt-dlp` is also a Python package and is
  pinned in `pyproject.toml`; the binary on PATH is the entrypoint
  installed by that package."

### Finding 2 — AGENTS.md cross-references a `REQUIREMENTS.md §"Stage protocol"` section that does not exist

- **Axis:** 1 (internal contradictions / broken cross-references)
- **Severity:** SHOULD-resolve
- **Evidence:**
  - `AGENTS.md:110` — "Stages communicate via files on disk
    (ffmpeg is the backplane), not in-memory pipes — this lets the
    lab apply any stage in isolation. Detailed contract in
    REQUIREMENTS.md §'Stage protocol'."
  - `docs/REQUIREMENTS.md` — no section titled "Stage protocol".
    The closest is "## Architecture (REQ-ARCH)" containing
    REQ-ARCH-001 through REQ-ARCH-005, which cover the stage
    contract piecemeal (isolation, file-based comms, dispatch,
    preset source-of-truth) but are not grouped under a "Stage
    protocol" heading.
- **Issue:** Dead cross-reference. A reader following the link
  finds no target. The agent who tries to find "the detailed stage
  contract" sees a name with no corresponding section. Mild but
  real navigation failure.
- **Suggested resolution:** Either (a) rename the AGENTS.md
  pointer to `REQUIREMENTS.md §"Architecture (REQ-ARCH)"`, or (b)
  add a short "Stage protocol" subheading in REQUIREMENTS.md
  preceding REQ-ARCH-001 that introduces the `run(...)` signature
  and links to the individual REQs. Option (a) is the smaller
  edit.

### Finding 3 — `test_path_containment` anchor is satisfied by a "raise on every input" validator

- **Axis:** 4 (anti-tautology)
- **Severity:** SHOULD-resolve
- **Evidence:**
  - `docs/TEST_SPEC.md:466-475` —
    ```
    ### test_path_containment — REQ-SEC-004
      Assertions:
        - For each malicious input, the validator raises
          `PathContainmentError`.
      Anti-tautology: A pass-through validator fails.
    ```
- **Issue:** The single assertion covers only the negative
  direction: every malicious path MUST raise. The anti-tautology
  note rules out a pass-through validator (one that lets
  everything through, including malicious paths), but does not
  rule out the symmetric trivial implementation: a validator that
  raises on *every* input, including legitimate `cache/...` and
  `lab/...` paths. That validator would pass the anchor as written
  and break the application entirely. REQ-SEC-004 itself ("Stages
  MUST refuse to read from or write to paths outside the
  configured `cache/` and `lab/` directories") implies the
  positive direction as well.
- **Suggested resolution:** Add a second assertion: "For each
  benign input (a path inside `cache/` or `lab/`), the validator
  returns the path unchanged (or normalized)." Update the
  anti-tautology note to read "A pass-through validator fails the
  malicious cases; an always-raise validator fails the benign
  cases."

### Finding 4 — `test-e2e` workflow will fail with "no tests collected" on the first PR that touches `erebus/`

- **Axis:** 6 (workflow gaps) / 1 (internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:**
  - `docs/REPO_SETUP.md:619-650` — `test-e2e.yml` runs
    `uv run pytest tests/e2e -m phase1 --run-e2e` on PRs whose diff
    touches `erebus/**`, `presets/**`, or `tests/e2e/**`.
  - `docs/REPO_SETUP.md:344` — `mkdir -p tests/unit tests/integration
    tests/e2e tests/meta tests/fixtures` creates an empty
    `tests/e2e/` directory.
  - `docs/REPO_SETUP.md:359-505` — §3.6.1 adds bootstrap
    placeholder tests for `tests/unit`, `tests/integration`,
    `tests/meta`, and a conftest at `tests/`. No
    `tests/e2e/test_smoke.py` is included.
  - `docs/WORKFLOW.md:165-168` — "`test-e2e` runs conditionally
    … and is not in the required list. It must still be green when
    it runs."
- **Issue:** pytest exits 5 (`EXIT_NOTESTSCOLLECTED`) when given a
  directory with no collectable tests. The first PR after Goal 0
  that touches `erebus/` (the most likely first PR — adding a
  stage) will trigger `test-e2e`, pytest will find no e2e tests
  yet (the Phase-1 e2e anchors are added in their respective
  feature PRs), and the job will fail. WORKFLOW.md §3 explicitly
  says the job must be green when it runs. The result is friction
  on the first stage PR — the agent must either add an e2e test
  out of scope, or modify the workflow.
- **Suggested resolution:** Add a `tests/e2e/test_smoke.py` to
  §3.6.1 mirroring the existing `tests/integration/test_smoke.py`
  (a single `@pytest.mark.phase1` `assert True` test with a
  docstring noting it can be deleted once the first real e2e
  anchor lands). Cheap and consistent with what §3.6.1 already
  does for the other layers.

### Finding 5 — `WORKFLOW.md §5` reviewer-unavailable fallback does not survive the `review-artifact-exists` gate

- **Axis:** 6 (workflow gaps)
- **Severity:** SHOULD-resolve
- **Evidence:**
  - `docs/WORKFLOW.md:223-228` — "If the reviewer is unavailable
    entirely (Anthropic API outage), document the skip in
    `NOTES.md` and proceed with an explicit human signoff in the
    PR; the review must be run retrospectively within 24 hours."
  - `docs/WORKFLOW.md:215-221` — "A CI job
    `review-artifact-exists` verifies that a review file exists at
    `docs/decisions/reviews/<PR-NUMBER>-*.{json,md}` and is
    non-empty before the PR can merge."
  - `docs/REPO_SETUP.md:684-695` — branch protection lists
    `review-artifact-exists` in `required_status_checks.contexts`.
  - `docs/REPO_SETUP.md:712-715` — "`enforce_admins: false`
    because Logan needs to be able to override during
    emergencies."
- **Issue:** The §5 fallback says "proceed" without specifying the
  mechanism. `review-artifact-exists` is a required status check;
  branch protection blocks merges that miss it. The only way to
  "proceed" without producing an artifact is the admin-override
  hatch (which works because `enforce_admins: false`), but §5
  never names that mechanism. A reader following §5 literally
  would not know whether to use admin override, commit a stub
  artifact, or wait out the outage.
- **Suggested resolution:** Pick one of two mechanizations and
  spell it out in §5. Either (a) require the fallback to commit a
  stub artifact (e.g.
  `docs/decisions/reviews/<PR>-fallback-outage.md` with a single
  paragraph describing the outage and the retrospective-review
  commitment) so the existing CI gate is satisfied without
  bypass, or (b) name the admin-override path explicitly and link
  to an ADR template for the post-incident logging. Option (a)
  preserves the CI invariant; option (b) preserves the "reviewer
  produces the artifact" invariant.

### Finding 6 — Step 3.6 stub-file guidance is vague about how to satisfy mypy strict

- **Axis:** 7 (tool assumptions) / 10 (other)
- **Severity:** CONSIDER
- **Evidence:**
  - `docs/REPO_SETUP.md:353-354` — "Each `.py` file gets a minimal
    stub: a module docstring and any `NotImplementedError`
    placeholder needed to satisfy mypy strict mode."
- **Issue:** mypy strict (per
  `pyproject.toml [tool.mypy] strict = true` and
  `disallow_untyped_defs = true`) does not require any function to
  exist; it only requires that defined functions be fully
  annotated. An empty module with a docstring passes mypy strict
  on its own. A function body of `raise NotImplementedError()`
  passes only if the function signature is annotated. The phrase
  "any `NotImplementedError` placeholder needed to satisfy mypy
  strict mode" suggests the placeholder satisfies mypy, when in
  practice it is the annotation that does. A Goal-0 agent
  literally writing `def run(): raise NotImplementedError()` would
  fail mypy strict; one writing `def run() -> None: raise
  NotImplementedError()` would pass.
- **Suggested resolution:** Replace the sentence with: "Each
  `.py` file gets a module docstring. Stub functions, if any, MUST
  carry a return-type annotation (e.g. `def run(...) -> None:`)
  to satisfy mypy strict; an empty module with only a docstring
  is also acceptable." Optionally include a one-line example so
  the agent doesn't have to infer it.

### Finding 7 — PR template wording in WORKFLOW.md §3 mentions only `.json` review artifacts; storage rule allows `.md`

- **Axis:** 1 (internal contradictions, minor)
- **Severity:** CONSIDER
- **Evidence:**
  - `docs/WORKFLOW.md:147-148` — PR template checklist line:
    "Cross-vendor review run; artifact committed at
    `docs/decisions/reviews/<PR>-*.json`".
  - `docs/WORKFLOW.md:217-219` — "verifies that a review file
    exists at `docs/decisions/reviews/<PR-NUMBER>-*.{json,md}`".
  - `docs/WORKFLOW.md:264-275` — the canonical stage-review
    invocation writes BOTH `.json` (raw) and `.md` (rendered
    summary) under that directory.
- **Issue:** Three voices, two formats. The PR template suggests
  only `.json`; the CI gate accepts either; the canonical
  invocation produces both. A reader filling in the PR template
  may check the box even if only the `.md` is present (because
  they did run the review) and then question whether they
  satisfied the artifact requirement.
- **Suggested resolution:** Change the PR template line to
  `docs/decisions/reviews/<PR>-*.{json,md}` so all three sources
  agree.

### Finding 8 — REQ-CLI-002 names a `concat` trimming capability that no REQ-CONCAT establishes

- **Axis:** 1 (internal contradictions, minor) / 2 (REQ ↔ anchor
  coverage, indirect)
- **Severity:** CONSIDER
- **Evidence:**
  - `docs/REQUIREMENTS.md:284-287` — "REQ-CLI-002 — The
    `--max-duration <seconds>` flag MUST cap the output's duration
    without re-running ingestion (use `concat` trimming)."
  - `docs/REQUIREMENTS.md:124-141` — REQ-CONCAT-001/002/003 cover
    lossless concat, duration preservation, and deterministic
    ordering. None defines a trim operation or accepts a
    max-duration parameter.
  - `docs/TEST_SPEC.md:442-449` — `test_render_max_duration_caps_output`
    cites only REQ-CLI-002, not any REQ-CONCAT.
- **Issue:** REQ-CLI-002 delegates the trimming responsibility to
  the concat stage parenthetically, but REQ-CONCAT has no
  corresponding requirement. The `concat` implementer reading
  REQ-CONCAT will not know the stage owes a trim-to-duration
  contract. The CLI test anchors the end-to-end behaviour but
  doesn't decompose it. This is the kind of cross-stage handoff
  that bites at integration time.
- **Suggested resolution:** Add a `REQ-CONCAT-004 [MUST, phase:1]
  — Optional duration cap`: "When called with a `max_duration`
  parameter, the concat stage MUST stop concatenation at the
  specified duration boundary (within ±100 ms), trimming the last
  input clip if necessary." Then either reuse the existing
  `test_render_max_duration_caps_output` anchor by adding
  REQ-CONCAT-004 to its citation list, or add a dedicated
  `test_concat_max_duration_trims_at_boundary` anchor. Either
  satisfies the coverage check; the dedicated anchor gives a
  faster failure signal.

## Summary

- 8 findings total: 0 MUST-resolve, 5 SHOULD-resolve, 3 CONSIDER.
- No MUST-resolve findings remain. The pre-setup audit cycle is
  complete. Goal-0 setup work may proceed.
- The SHOULD-resolve items (Findings 1–5) are quality improvements
  that do not block setup but should be addressed before Phase-1
  work begins so the first stage PR doesn't immediately surface
  Finding 4 or Finding 5. Findings 1, 2, 6, 7 are documentation
  drift; Finding 3 is a test-spec quality fix; Finding 8 is a
  decomposition gap that will surface during Phase-1
  implementation if not addressed.

## Resolution log

- Finding 1: resolved; added yt-dlp to PROJECT.md §11's Python
  dependencies list (it was listed only as an external binary)
  and added a clarifying parenthetical explaining the
  binary/wheel relationship and pin authority. Brings §11 into
  agreement with REPO_SETUP.md §3.3 pyproject.toml.
- Finding 4: resolved; added `tests/e2e/test_smoke.py` placeholder
  to REPO_SETUP.md §3.6.1, mirroring `tests/integration/test_smoke.py`
  from pass-3 Finding 2. The first PR touching erebus/ will no
  longer hit pytest exit-5 on the test-e2e workflow.
- Finding 7: resolved; updated the PR template checklist in
  WORKFLOW.md §3 to match the CI check and the §5 canonical
  invocation (which writes both `.json` and `.md`). The three
  voices now agree on `{json,md}`.

## Deferred findings (5)

Cycle terminating with these deferred to the Phase-1 prep backlog
(joining 9 + 9 + 16 from the prior passes — combined backlog:
**39 items**). None block Goal-0; all need either Phase-1 design
context or are cosmetic.

- **SHOULD (3):** 2 (AGENTS.md `REQUIREMENTS.md §"Stage protocol"`
  dead cross-reference), 3 (`test_path_containment` anti-tautology
  gap — missing positive-direction assertion), 5 (reviewer-
  unavailable fallback in WORKFLOW.md §5 doesn't survive the
  `review-artifact-exists` gate — needs a stub-artifact convention
  or admin-override naming).
- **CONSIDER (2):** 6 (§3.6 stub-file mypy strict guidance:
  annotation, not `NotImplementedError`, is what passes), 8
  (REQ-CLI-002 names `concat` trim but no REQ-CONCAT establishes
  the contract — repeat of pass-2 Finding 10 and pass-3 Finding 10,
  intentionally deferred to Phase-1 architectural design).

## Cycle complete

Two consecutive zero-MUST passes (4 and 5) with a sharp drop in
total findings (20 → 8). The pre-setup audit cycle terminates
here. Goal-0 setup work (repo create, branch protection, push)
runs as a separate goal after the resolution PR merges.

### Convergence trend

| Pass | Total | MUST | SHOULD | CONSIDER |
|---|---|---|---|---|
| 1 (archive/0001) | 17 | 8 | 7 | 2 |
| 2 (archive/0004) | 23 | 3 | 13 | 7 |
| 3 (archive/0006) | 14 | 2 | 6 | 6 |
| 4 (archive/0008) | 20 | 0 | 12 | 8 |
| 5 (this) | **8** | **0** | 5 | 3 |
