# Post-setup cross-vendor review — PR #1 (Goal-0 finalization)

- **Reviewer:** Claude Code (claude-opus-4-7) — post-setup audit
- **Date:** 2026-05-25
- **Scope:** Bootstrap state of `loganrooks/erebus` after Goal-0
  commits `a9f2ea0..1b1fc3c` (plus this review-artifact commit).
  PR #1 carries the GitHub issue + PR templates and this artifact.
- **Related ADRs:** `docs/decisions/archive/0010-pre-setup-gap-analysis-pass-5.md`
  (last pre-setup audit, resolved cycle); `docs/decisions/reviews/`
  (this directory).

## Context

Verified the on-disk bootstrap against `docs/REPO_SETUP.md` §3
file-by-file, ran the four CI `pytest` invocations locally
(unit+meta, integration, e2e with `--run-e2e`, docs-consistency)
— all green, 6 tests collected total. Confirmed the CI workflow
job names line up with the branch-protection contexts listed in
REPO_SETUP.md §4 and the PR-template / WORKFLOW.md §3 checklists.
Read every `erebus/**/*.py` stub; all are docstring-only and
mypy-strict-clean. Confirmed the meta-test regexes in
`tests/meta/test_anchors.py` match the actual REQ-ID and anchor
heading formats in REQUIREMENTS.md and TEST_SPEC.md. Spot-checked
`git ls-files` and `git check-ignore` against the leakage rules;
only `lab/clips/.gitkeep` and `lab/outputs/.gitkeep` are tracked
under `lab/`, and the `*.env` / `cache/` / `lab/(clips|outputs)/*`
patterns correctly ignore content while preserving the .gitkeep
re-include. The 39-item Phase-1 prep backlog from the archived
audit ADRs is treated as out-of-scope per the review prompt; no
deferred finding is re-raised here.

Branch protection and the green CI run on `main` cannot be
verified from the local filesystem; both are tracked by the
goal's own done-list (REPO_SETUP.md §8 bullets 2 and 5) and were
configured externally before this artifact was produced.

## Findings

### Finding 1 — `REPO_SETUP.md` §3.1 prescribes the broken `.gitignore` form for `lab/`

- **Axis:** 1 (code-vs-docs agreement).
- **Severity:** SHOULD-resolve.
- **Evidence:** `docs/REPO_SETUP.md` lines 131–135 vs `.gitignore`
  lines 28–34. The doc still shows:
  ```
  lab/clips/
  lab/outputs/
  !lab/clips/.gitkeep
  !lab/outputs/.gitkeep
  ```
  The on-disk `.gitignore` was corrected in commit `6d2ca32`
  ("chore: fix lab/.gitkeep pattern + add the .gitkeep files") to
  use `lab/clips/*` / `lab/outputs/*`, because bare-directory
  patterns exclude the directory entirely and git cannot
  re-include a file under an excluded directory — the `.gitkeep`
  carve-outs in the doc form are dead.
- **Issue:** A fresh-clone bootstrap or an agent regenerating
  `.gitignore` from §3.1 would re-introduce the bug. Pass-3
  Finding 13 caught the missing `.gitkeep` files but did not
  catch the pattern bug; commit `6d2ca32` fixed both on disk
  without back-propagating the pattern change to §3.1.
- **Suggested resolution:** Update REPO_SETUP.md §3.1 to the
  wildcard form, with the same explanatory comment that landed in
  `.gitignore` lines 28–30. Optionally cite `6d2ca32` so the
  rationale stays discoverable.

### Finding 2 — `REPO_SETUP.md` §3.8 references a non-existent `docs/README_TEMPLATE.md`

- **Axis:** 7 (documentation surface consistency).
- **Severity:** CONSIDER.
- **Evidence:** `docs/REPO_SETUP.md` lines 692–694: "See
  `docs/README_TEMPLATE.md` (or generate from PROJECT.md
  highlights)." `find docs -name 'README_TEMPLATE*'` returns
  nothing. The on-disk `README.md` matches the second option
  (generated from PROJECT.md highlights), so the bootstrap is
  not blocked.
- **Issue:** The dead cross-reference will mislead a future
  reader expecting a template file. The "or" clause makes it
  ambiguous whether the template was always optional or was
  intended to land at bootstrap.
- **Suggested resolution:** Drop the `docs/README_TEMPLATE.md`
  half of the sentence; keep "generate from PROJECT.md
  highlights" as the sole instruction.

## Summary

- 2 findings total: **0 MUST-resolve, 1 SHOULD-resolve, 1 CONSIDER**.
- No MUST-fix items. Goal-0 PR #1 may merge once CI is green.
- The SHOULD-resolve item is a Phase-1-prep doc patch (single
  edit to REPO_SETUP.md §3.1); the CONSIDER item is a one-line
  cleanup in §3.8. Neither blocks the templates PR.
