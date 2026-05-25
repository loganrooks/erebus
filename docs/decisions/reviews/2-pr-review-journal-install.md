# Stage review — PR #2 (install pr-review-journal v0.1.0)

- **Reviewer:** Claude Code (claude-sonnet-4-7) — self-review
- **Date:** 2026-05-25
- **Scope:** PR #2, single commit `8edef34` installing `pr-review-journal`
  `v0.1.0` from `loganrooks/pr-review-journal` via the on-demand pattern.
  6 files changed: `.gitignore`, `.review-journal.version` (new),
  `.review-journal.json` (new), `.github/workflows/review-journal.yml`
  (new), `pyproject.toml`, `AGENTS.md`.
- **Related artifacts:** [montage_cli#21](https://github.com/loganrooks/montage_cli/pull/21)
  — first consumer of the same install pattern (just merged).
  `loganrooks/pr-review-journal v0.1.0` — the upstream tool tag.

## Context

This PR installs the per-PR review-journal tool — a Python+shell tool
that parses `review-verdict` fenced-block disposition replies on PR
review threads and writes the result to per-PR JSON records under
`docs/review-journal/`. The discipline is reviewer-agnostic and applies
whether the reviewer is CodeRabbit, Codex, GitHub Copilot review, or
Claude PR review.

The install pattern is **on-demand**, not vendored: the tool's source is
NOT committed to this repo. `.review-journal.version` pins a tag;
`install.sh` from the upstream raw URL is run by CI before invoking
`sync-pr.sh`, and local devs run the documented one-liner once. This
avoids duplicating ~6,000 lines of tool code into every consumer repo's
git history, at the cost of one network round-trip per CI run and a
one-time local install step for devs.

The cross-vendor review ideal calls for Codex to review Claude's work
here. Codex was not invoked for this PR; this self-review is a degraded
fallback documented as such (per WORKFLOW.md §5 — degraded fallbacks are
permitted as long as the model choice is noted). The self-review caveat
is real: I am unlikely to flag my own argumentation errors. The findings
below should be read as a floor, not a ceiling.

## Verification

Ran locally on `install-pr-review-journal @ 8edef34`:

- `bash <(curl ...) | VERSION=v0.1.0 bash` — installed `tools/review-journal/` cleanly
- `bash tools/review-journal/tests/run-tests.sh` — 41 passed, 0 failed
- `uv run ruff check .` — all checks passed
- `uv run ruff format --check .` — 31 files already formatted
- `uv run mypy .` — Success: no issues found in 31 source files

CI on PR #2 (commit `ae49164` after merge with main):

- `lint-and-type`: pass (13s)
- `check` (review-journal install workflow): pass (7s)
- `docs-consistency`: pass (8s)
- `review-artifact-exists`: was failing for absence of this very file; this
  artifact resolves it
- `test-unit-meta`, `test-integration`, `gitleaks`: pending at review time

## Findings

### Finding 1 — Reviewers list includes three bots not configured on this repo

- **Axis:** 2 (config vs reality).
- **Severity:** NICE-to-have.
- **Evidence:** `.review-journal.json` lines 3 list `coderabbitai`,
  `chatgpt-codex-connector`, `github-actions` alongside the actually-
  configured `copilot-pull-request-reviewer`. None of the first three
  bots will post on this repo today.
- **Rationale for keeping:** The tool only flags reviewers that actually
  post — so listing extra logins is a no-op until you add the
  corresponding bot. The forward-compat hedge means a future "add
  CodeRabbit to erebus" action is a zero-config addition. The cost is
  ~3 lines of JSON.
- **Disposition:** Accepted as-is. Could be tightened to just
  `copilot-pull-request-reviewer` if you prefer minimum-viable config;
  trivial to expand later.

### Finding 2 — `github-actions` profile in config points at Claude PR review, which isn't configured on this repo

- **Axis:** 2 (config vs reality).
- **Severity:** NICE-to-have / cosmetic.
- **Evidence:** `.review-journal.json` lines 5–17 define a profile for
  `github-actions` (the GraphQL form of `github-actions[bot]`) with
  Critical/Warning/Suggestion severity patterns specific to the
  agentic-ops `review.yml` workflow. That workflow is NOT installed on
  erebus today.
- **Rationale:** The profile's `notes` field explicitly calls out this
  fact ("Not currently configured on this repo; profile is here for
  forward-compat."). The profile is inert until the workflow is
  installed. The cost is ~10 lines of JSON; the benefit is that if you
  add agentic-ops later, the journal correctly classifies its findings
  from day one.
- **Disposition:** Accepted as-is, with the inline note as the relief
  valve.

### Finding 3 — Local-install instructions in AGENTS.md require an external network call

- **Axis:** 3 (operability).
- **Severity:** NICE-to-have.
- **Evidence:** AGENTS.md "Review tooling" section instructs:
  `curl -fsSL "https://raw.githubusercontent.com/loganrooks/pr-review-journal/$VERSION/install.sh" | VERSION="$VERSION" bash`.
  A dev in an air-gapped environment, on a flight, or behind a corporate
  proxy that blocks raw.githubusercontent.com, can't run the tool.
- **Rationale:** This is the standard trade-off for the on-demand
  pattern. The mitigation is documented: pinning by tag means the
  install is reproducible given network access. If air-gapped operation
  becomes a priority, the path is to add a `scripts/install-review-journal.sh`
  wrapper in erebus that knows how to use a cached tarball, but that's
  out of scope here.
- **Disposition:** Accepted as the trade-off the install-on-demand
  pattern was chosen for. Not actionable here.

### Finding 4 — `journal_dir: docs/review-journal/` lives outside `docs/decisions/`

- **Axis:** 1 (code-vs-docs agreement).
- **Severity:** Cosmetic.
- **Evidence:** Erebus's existing structure puts deliberation under
  `docs/decisions/` (ADRs) and `docs/decisions/reviews/` (this very
  file). The journal lands at `docs/review-journal/` — sibling, not
  nested.
- **Rationale:** Review journal entries are mechanical per-PR
  disposition records, not deliberated decisions. Putting them under
  `docs/decisions/` would conflate "we thought about this and chose X"
  with "the reviewer posted this and we logged the disposition." The
  separation feels right.
- **Disposition:** Accepted. Could be `docs/decisions/review-journal/`
  if you prefer everything-under-decisions; trivial to change.

### Finding 5 — No mention in CLAUDE.md or PROJECT.md

- **Axis:** 1 (code-vs-docs agreement).
- **Severity:** NICE-to-have.
- **Evidence:** AGENTS.md gained a "Review tooling" section. CLAUDE.md
  imports AGENTS.md per the project convention (CLAUDE.md line 4
  "imports this file"), so the section is transitively visible to
  Claude Code. But PROJECT.md (the high-level phase document) has no
  mention.
- **Rationale:** PROJECT.md is phase-scoped; review-tooling is
  infrastructure. Reasonable to leave PROJECT.md untouched. Future
  WORKFLOW.md update could cross-reference the verdict-block discipline
  in the cross-vendor-review §5 section, but that's a separate edit.
- **Disposition:** Accepted. NICE-to-have follow-up: cross-link
  WORKFLOW.md §5 to the new verdict-block discipline once usage is
  established (probably after the first real journal entry is
  produced).

### Finding 6 — `gh pr comment` failure mode in CI workflow

- **Axis:** 3 (operability).
- **Severity:** Already-mitigated; called out for the record.
- **Evidence:** `.github/workflows/review-journal.yml` line 80 uses
  `gh pr comment ... || echo "warning: ..."` to prevent a failed
  advisory comment from failing the warning-mode workflow.
- **Rationale:** This is the v0.1.0 upstream fix (Codex P2 finding from
  the original montage_cli port). Inherited as-is. Verified the guard
  is present in the installed-via-script workflow snippet.
- **Disposition:** Accepted as-is.

## Summary

Six findings, all NICE-to-have or cosmetic, none MUST-fix or
SHOULD-resolve. The pattern is sound, the trade-offs are documented,
and the install dogfoods cleanly. The biggest gap is the cross-vendor
review weakness (self-review by the developer agent) — that's the
WORKFLOW.md §5 fallback case and is documented as such in the Context
section.

**Recommendation:** Merge after the remaining pending CI checks come
back green.

## Rule-deltas / follow-ups (not blocking)

1. After the first real verdict-block lands on an erebus PR, consider
   adding a one-paragraph cross-reference in WORKFLOW.md §5 pointing at
   `tools/review-journal/README.md` for the structured form (the §5
   review checkpoint is the human-deliberated layer; verdict-blocks are
   the per-thread machine-readable layer).
2. If you ever enable CodeRabbit or `@codex review` on erebus, no
   `.review-journal.json` change is needed — the default profiles cover
   both.
