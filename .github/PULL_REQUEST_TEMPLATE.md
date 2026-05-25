## What

<one paragraph: the user-facing or contributor-facing change>

## Why

<the REQ-ID(s) or issue being addressed, and the rationale>

## How

<the approach, focusing on choices a reviewer would want to second-guess>

## Verification

- [ ] All affected anchors green: `<anchor_name>`, …
- [ ] `uv run pytest -m phase1` passes locally
- [ ] `pre-commit run --all-files` passes
- [ ] CI jobs green:
  - `lint-and-type`
  - `test-unit-meta (ubuntu-latest)`
  - `test-unit-meta (macos-latest)`
  - `test-integration`
  - `gitleaks`
  - `docs-consistency`
  - `review-artifact-exists`
- [ ] Lab clip rendered + reviewed: `lab/outputs/<filename>`
- [ ] Cross-vendor review run; artifact committed at
      `docs/decisions/reviews/<PR>-*.{json,md}` (canonical
      invocation in WORKFLOW.md §5 writes both)

## Out of scope

<things deliberately not in this PR; link follow-up issues>
