# Repo setup

How to bootstrap the `erebus` repository on GitHub. This document is
the operating manual for **Goal 0**. The goal commands references
this file; the agent executing Goal 0 reads it after completing the
pre-setup gap analysis.

---

## 1. Pre-flight: do these things ONCE on the host

The agent assumes a working host. Verify before bootstrapping:

```bash
# Required CLI tools
git --version          # ≥ 2.40
gh --version           # GitHub CLI, authenticated: `gh auth status`
uv --version           # Astral's uv package manager
pre-commit --version   # pre-commit framework
ffmpeg -version | head -1  # ≥ 6.0
yt-dlp --version

# Verify yt-dlp meets the declared minimum (REQ-SEC-005). §1 runs
# before §3.3 creates pyproject.toml, so the floor is hardcoded
# here. Keep this value in sync with the `yt-dlp >= ...` line in
# pyproject.toml [project.dependencies]; post-bootstrap, `uv sync`
# enforces the pyproject pin automatically and is authoritative.
YT_DLP_MIN="2024.7.16"
yt-dlp --version | awk -v min="$YT_DLP_MIN" '
  { split($1, v, "."); split(min, m, ".");
    for (i = 1; i <= 3; i++) {
      vi = (v[i] == "" ? 0 : v[i]+0);
      mi = (m[i] == "" ? 0 : m[i]+0);
      if (vi < mi) exit 1;
      if (vi > mi) exit 0;
    }
  }'

# GitHub auth
gh auth status         # should show authenticated as loganrooks
```

If any of these fail, stop and surface the missing dependency. Don't
silently install system-wide tools as part of the goal.

`gitleaks` is managed by `pre-commit` via the hook in
`.pre-commit-config.yaml`; no separate install needed on the host
or in CI.

## 2. Repository creation

The bootstrap directory `/Users/rookslog/Development/erebus` already
holds the docs. Initialize it as a git repo in place, commit the
bootstrap, then create the GitHub repo from that directory using
`gh repo create --source=.`. This avoids the dual-checkout conflict
that a `gh repo clone` into an already-populated directory would
cause.

```bash
cd /Users/rookslog/Development/erebus     # the existing directory

# Initialize as a git repo (idempotent if already done)
git init -b main

# Stage and commit the bootstrap
git add .
git status                                # sanity-check the staged set
git commit -m "chore: initial bootstrap (docs + skeleton)"

# Create the GitHub repo from this directory, set origin, push.
# Drop --license=mit here: the local LICENSE generated in step 3.2
# is the canonical one; passing --license=mit would conflict with
# the existing file when --source is a non-empty repo.
gh repo create loganrooks/erebus \
  --public \
  --description "Cyberpunk video-mix toolkit. Concat YouTube playlists, overlay music, apply cyberpsycho visual presets." \
  --source=. \
  --remote=origin \
  --push
```

If a different license is preferred (Apache-2.0 is the main
alternative for projects that may attract contributors), swap the
LICENSE file produced by step 3.2 before the bootstrap commit.

## 3. Bootstrap files

The bootstrap commit (created in §2 with `git add . && git commit`)
contains the files described in the steps below. The per-step
structure is a content walkthrough, not separate commits — every
file in §3.1 through §3.8 lives in that one bootstrap commit.
Subsequent changes after the bootstrap land as separate commits per
the normal workflow.

Each step closes with a "Conventional-Commits label (post-bootstrap
reference)" line. The label is the Conventional-Commits message
style a post-bootstrap commit touching the same content would use,
offered as a teaching example. It is NOT a commit boundary for
the bootstrap; the bootstrap is a single `git commit`.

### Step 3.1 — `.gitignore`

```gitignore
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
.eggs/
dist/
build/

# uv
.uv-cache/

# Editors
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Project: never commit
cache/
*.env
.env*
!.env.example

# Lab: clips are not distributed; outputs are scratch
lab/clips/
lab/outputs/
!lab/clips/.gitkeep
!lab/outputs/.gitkeep

# Tests
.coverage
htmlcov/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.hypothesis/

# Claude Code / local agent state
.claude/state/
CLAUDE.local.md
```

Conventional-Commits label (post-bootstrap reference): `chore: add .gitignore`.

### Step 3.2 — `LICENSE`

Generate the MIT LICENSE locally before the bootstrap commit:

```bash
gh api /licenses/mit --jq .body > LICENSE
sed -i.bak "s/\[year\]/$(date +%Y)/; s/\[fullname\]/Logan Rooks/" LICENSE
rm LICENSE.bak
```

`gh repo create` in §2 deliberately omits `--license=mit` to avoid
a write conflict with this locally-generated LICENSE when
`--source=.` is a non-empty repo. The locally-generated file is
the canonical one.

Conventional-Commits label (post-bootstrap reference): `chore: add MIT license`.

### Step 3.3 — `pyproject.toml`

```toml
[project]
name = "erebus"
version = "0.0.1"
description = "Cyberpunk video-mix toolkit."
readme = "README.md"
requires-python = ">=3.11"
license = { file = "LICENSE" }
authors = [{ name = "Logan Rooks" }]
dependencies = [
  "typer >= 0.12",
  "pydantic >= 2.7",
  "rich >= 13.7",
  "yt-dlp >= 2024.7.16",
]

[project.optional-dependencies]
dev = [
  "pytest >= 8.0",
  "pytest-cov >= 5.0",
  "hypothesis >= 6.100",
  "ruff >= 0.5",
  "mypy >= 1.10",
  "pre-commit >= 3.7",
]

[project.scripts]
erebus = "erebus.cli:app"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "N", "S", "C4", "RUF"]
ignore = ["S101"]  # pytest uses assert

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S105", "S106"]  # tests use fake secrets

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unreachable = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
markers = [
  "phase1: Phase-1 anchors and tests",
  "phase2: Phase-2 (deferred)",
  "phase3: Phase-3 (deferred)",
  "phase4: Phase-4 (deferred)",
  "anchor(name): name of the TEST_SPEC.md anchor this test satisfies",
  "meta: docs-consistency and other meta tests; meta tests should also carry the relevant phase marker",
]
addopts = "-ra --strict-markers"
```

Exact versions for both runtime and dev dependencies are recorded in
`uv.lock`, which `uv sync` writes on first install. Commit `uv.lock`
on the same step as `pyproject.toml`.

Conventional-Commits label (post-bootstrap reference): `chore: add pyproject.toml with Python 3.11 + uv config`.

### Step 3.4 — `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-toml
      - id: check-added-large-files
        args: [--maxkb=500]
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.5.0
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.10.0
    hooks:
      - id: mypy
        additional_dependencies:
          - pydantic >= 2.7
          - typer >= 0.12
          - pytest >= 8.0   # for conftest.py's TYPE_CHECKING import
        args: [--strict]

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
        stages: [pre-commit, manual]

  - repo: local
    hooks:
      - id: pytest-fast
        name: pytest (unit + meta, phase1 + meta scope)
        entry: uv run pytest tests/unit tests/meta -m "phase1 or meta" --quiet --no-header
        language: system
        pass_filenames: false
        stages: [pre-commit]
```

Conventional-Commits label (post-bootstrap reference): `chore: add pre-commit config`.

Then install the hooks: `pre-commit install`.

### Step 3.5 — All documentation files

Drop in the following files (their contents are defined in their
respective sections of the project documentation):

- `PROJECT.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/REQUIREMENTS.md`
- `docs/TESTING.md`
- `docs/TEST_SPEC.md`
- `docs/WORKFLOW.md`
- `docs/REPO_SETUP.md` (this file)
- `docs/decisions/TEMPLATE.md`
- `docs/decisions/NNNN-pre-setup-gap-analysis*.md` (the agent's
  audit output; current pass lives in `docs/decisions/`,
  resolved prior passes in `docs/decisions/archive/`)
- `docs/review-prompts/stage-review.md`
- `docs/review-prompts/pre-setup-audit.md`
- `docs/review-prompts/phase-completion.md`
- `docs/review-prompts/permissions.md`
- `README.md`
- `NOTES.md` (empty except for a header)

Conventional-Commits label (post-bootstrap reference): `docs: add full project documentation set`.

### Step 3.6 — Source tree skeleton

```bash
mkdir -p erebus/stages erebus/ffmpeg erebus/visualizers
touch erebus/__init__.py
touch erebus/cli.py
touch erebus/config.py
touch erebus/stages/__init__.py
touch erebus/stages/ingest.py
touch erebus/stages/concat.py
touch erebus/stages/grade.py
touch erebus/stages/visualize.py
touch erebus/stages/caption.py
touch erebus/stages/mix.py
touch erebus/stages/encode.py
touch erebus/stages/lab.py
touch erebus/ffmpeg/__init__.py
touch erebus/ffmpeg/builder.py
touch erebus/ffmpeg/probe.py
touch erebus/ffmpeg/presets.py
touch erebus/visualizers/__init__.py
touch erebus/visualizers/showcqt.py
touch erebus/visualizers/avectorscope.py

mkdir -p tests/unit tests/integration tests/e2e tests/meta tests/fixtures
mkdir -p presets lab/clips
mkdir -p .github/workflows

# Fixture-generator script (stub at Goal 0; implementation in Phase 1)
mkdir -p scripts
touch scripts/generate_fixtures.py
```

Each `.py` file gets a minimal stub: a module docstring and any
NotImplementedError placeholder needed to satisfy mypy strict mode.

Conventional-Commits label (post-bootstrap reference): `chore: add source tree skeleton`.

### Step 3.6.1 — Bootstrap test set

The empty test directories from §3.6 would cause `pytest` to exit
non-zero (no tests collected). Add a minimal bootstrap test set
that passes immediately:

`tests/conftest.py`:

```python
"""Pytest configuration for the erebus test suite.

Markers are declared in pyproject.toml [tool.pytest.ini_options];
shared fixtures and hooks go here as they are introduced.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import pytest


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--run-e2e",
        action="store_true",
        default=False,
        help="Run end-to-end tests (slow; gated by default).",
    )
```

The `--run-e2e` option is referenced by TESTING.md §7 and by the
test-e2e workflow; without this hook, `pytest --run-e2e` fails
with "unrecognized argument" on the first invocation. The
`TYPE_CHECKING`-guarded `import pytest` plus
`from __future__ import annotations` keeps the file mypy-strict-
clean without paying for a runtime import of pytest internals.

`tests/meta/test_anchors.py`:

```python
"""Docs-consistency: REQ <-> anchor coverage check."""
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
REQ_FILE = REPO_ROOT / "docs" / "REQUIREMENTS.md"
SPEC_FILE = REPO_ROOT / "docs" / "TEST_SPEC.md"

REQ_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[", re.MULTILINE)
MUST_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[MUST", re.MULTILINE)
ANCHOR_REQ_REF = re.compile(
    r"### test_\w+\s*—\s*((?:REQ-[A-Z]+-\d{3}[,\s]*)+)"
)


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


@pytest.mark.anchor("test_every_must_req_has_anchor_citation")
@pytest.mark.meta
@pytest.mark.phase1
def test_every_must_req_has_anchor_citation() -> None:
    """Every MUST requirement must be cited by at least one anchor."""
    req_text = _read(REQ_FILE)
    spec_text = _read(SPEC_FILE)
    musts = set(MUST_PATTERN.findall(req_text))
    cited: set[str] = set()
    for match in ANCHOR_REQ_REF.finditer(spec_text):
        cited.update(re.findall(r"REQ-[A-Z]+-\d{3}", match.group(1)))
    missing = musts - cited
    assert not missing, f"MUST REQs without anchor: {sorted(missing)}"


@pytest.mark.anchor("test_every_anchor_cites_valid_req")
@pytest.mark.meta
@pytest.mark.phase1
def test_every_anchor_cites_valid_req() -> None:
    """Every anchor must cite at least one REQ-ID that exists."""
    req_text = _read(REQ_FILE)
    spec_text = _read(SPEC_FILE)
    valid_reqs = set(REQ_PATTERN.findall(req_text))
    bad: list[str] = []
    for match in ANCHOR_REQ_REF.finditer(spec_text):
        cited = re.findall(r"REQ-[A-Z]+-\d{3}", match.group(1))
        if not cited:
            bad.append(f"empty citation near: {match.group(0)[:60]}")
            continue
        for req in cited:
            if req not in valid_reqs:
                bad.append(f"unknown REQ cited: {req}")
    assert not bad, "\n".join(bad)
```

`tests/meta/test_bootstrap.py`:

```python
"""Smoke test that erebus is importable at bootstrap."""
import pytest


@pytest.mark.meta
@pytest.mark.phase1
def test_erebus_importable() -> None:
    import erebus  # noqa: F401
```

`tests/unit/test_smoke.py`:

```python
"""At least one unit test so pytest collects something at Goal-0."""
import pytest


@pytest.mark.phase1
def test_smoke() -> None:
    assert True
```

`tests/integration/test_smoke.py`:

```python
"""At least one integration test so pytest collects something at Goal-0.

The real integration anchors land in Phase 1's stage-by-stage PR
cycle (per docs/TEST_SPEC.md "Integration anchors"). This file may
be deleted once the first real integration test lands; the
test-integration CI job needs at least one collected test to pass.
"""
import pytest


@pytest.mark.phase1
def test_integration_smoke() -> None:
    assert True
```

`tests/e2e/test_smoke.py`:

```python
"""At least one e2e test so pytest collects something at Goal-0.

The test-e2e workflow runs `pytest tests/e2e -m phase1 --run-e2e`
on PRs touching erebus/, presets/, or tests/e2e/. Without a
collected test, pytest exits 5 ("no tests ran") and the job
reports failure on the first stage PR. WORKFLOW.md §3 says
test-e2e MUST be green when it runs.

Real e2e anchors (`test_phase1_integration`) land in their
feature PRs during Phase 1; this placeholder may be deleted once
that anchor is in place.
"""
import pytest


@pytest.mark.phase1
def test_e2e_smoke() -> None:
    assert True
```

Phase-1 stage anchors (per `docs/TEST_SPEC.md`) are NOT created at
Goal 0. They are added during Phase 1 in the RED step of each
stage's red-green-refactor PR cycle. The meta-tests above only
check that *existing* anchors are properly cross-referenced;
pending anchors are normal until their feature PR lands.

Conventional-Commits label (post-bootstrap reference): `chore: add bootstrap test set`.

### Step 3.7 — GitHub Actions workflows

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-type:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
        with:
          enable-cache: true
      - run: uv python install 3.11
      - run: uv sync --extra dev
      - run: uv run ruff check .
      - run: uv run ruff format --check .
      - run: uv run mypy .

  test-unit-meta:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - run: uv python install 3.11
      - run: uv sync --extra dev
      - name: Install ffmpeg
        run: |
          if [[ "${{ matrix.os }}" == "ubuntu-latest" ]]; then
            sudo apt-get update && sudo apt-get install -y ffmpeg
          else
            brew install ffmpeg
          fi
      - run: uv run pytest tests/unit tests/meta -m "phase1 or meta"

  test-integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - run: uv python install 3.11
      - run: uv sync --extra dev
      - run: sudo apt-get update && sudo apt-get install -y ffmpeg
      - run: uv run pytest tests/integration -m phase1

  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: astral-sh/setup-uv@v3
      - run: uv python install 3.11
      - run: uv sync --extra dev
      - run: uv run pre-commit run --hook-stage manual gitleaks --all-files

  docs-consistency:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - run: uv python install 3.11
      - run: uv sync --extra dev
      - run: uv run pytest tests/meta -m meta

  review-artifact-exists:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - name: Check for review artifact
        run: |
          PR="${{ github.event.pull_request.number }}"
          DIR="docs/decisions/reviews"
          # WORKFLOW.md §5 permits either .json or .md for review
          # artifacts. Match any extension and require a non-empty
          # file (per the "non-empty" qualifier in WORKFLOW.md §5).
          matches=$(find "$DIR" -name "${PR}-*" -type f -size +0c 2>/dev/null || true)
          if [ -n "$matches" ]; then
            echo "Review artifact(s) found:"
            echo "$matches"
          else
            echo "::error::No non-empty review artifact at $DIR/${PR}-*"
            echo "::error::Expected at least one file matching $DIR/${PR}-<reviewer>.{json,md}"
            echo "Run the stage review checkpoint before merging."
            exit 1
          fi
```

Conventional-Commits label (post-bootstrap reference): `ci: add main workflow with lint, type, test, gitleaks, docs jobs`.

The end-to-end job is split into its own workflow so its
path-filter trigger works correctly on `pull_request` events.

`.github/workflows/test-e2e.yml`:

```yaml
name: test-e2e

on:
  pull_request:
    branches: [main]
    paths:
      - 'erebus/**'
      - 'presets/**'
      - 'tests/e2e/**'
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: test-e2e-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test-e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - run: uv python install 3.11
      - run: uv sync --extra dev
      - run: sudo apt-get update && sudo apt-get install -y ffmpeg
      - run: uv run pytest tests/e2e -m phase1 --run-e2e
```

The `paths:` filter on `pull_request:` is the workflow-trigger
mechanism (GitHub-native, no third-party action). It evaluates
against the actual diff for the PR, so the job runs when
`erebus/`, `presets/`, or `tests/e2e/` change and skips
otherwise. `workflow_dispatch` exposes a manual-run button for
ad-hoc runs.

The earlier inline `test-e2e` job in `ci.yml` used
`github.event.head_commit.modified`, which is populated only on
`push` events — on `pull_request` events that field is empty, so
the conditional never matched and the job silently skipped. The
split workflow corrects that.

Conventional-Commits label (post-bootstrap reference): `ci: add test-e2e workflow with paths-filter trigger`.

### Step 3.8 — README

Public-facing. Minimal install + example + disclaimer + link to
`PROJECT.md`. See `docs/README_TEMPLATE.md` (or generate from
PROJECT.md highlights).

Conventional-Commits label (post-bootstrap reference): `docs: add public README`.

## 4. Branch protection

After the initial main branch has a green CI run:

```bash
# Use the GitHub API via gh to configure protection
gh api -X PUT /repos/loganrooks/erebus/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "lint-and-type",
      "test-unit-meta (ubuntu-latest)",
      "test-unit-meta (macos-latest)",
      "test-integration",
      "gitleaks",
      "docs-consistency",
      "review-artifact-exists"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
JSON
```

`enforce_admins: false` because Logan needs to be able to override
during emergencies. The pattern is: protection is the default, the
admin bypass is the recovery hatch — and recovery uses are logged in
ADRs.

Squash-merging stays disabled at the repo level:

```bash
gh api -X PATCH /repos/loganrooks/erebus \
  -f allow_squash_merge=false \
  -f allow_merge_commit=true \
  -f allow_rebase_merge=true \
  -f delete_branch_on_merge=true
```

## 5. Secrets

GitHub Secrets are configured for CI access to external services.
For Phase 1 there are no required secrets. Phase 4 adds:
`ACOUSTID_API_KEY`, optionally `ACRCLOUD_KEY` / `ACRCLOUD_SECRET`.

To add later:

```bash
gh secret set ACOUSTID_API_KEY --body "$key"
```

Secrets MUST never be echoed in workflow logs. The CI workflow uses
`env:` injection only in steps that need them; never in `run:` strings.

## 6. Issue and PR templates

`.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
---
name: Bug report
about: Report a bug in erebus
labels: [bug]
---

**What happened?**

**What did you expect?**

**Reproduction steps:**

**Environment:**
- OS:
- Python:
- ffmpeg:
- yt-dlp:

**Logs / output:**
```

`.github/PULL_REQUEST_TEMPLATE.md` matches the body template in
`docs/WORKFLOW.md` §3.

## 7. The initial green CI run

After all bootstrap commits land on main, the CI must turn green.
If it doesn't:

1. Don't merge anything else.
2. Open a `fix/ci-bootstrap` branch.
3. Diagnose and fix.
4. Merge via PR.

A red main on day one is the worst possible signal for an
agent-driven project. Get green before declaring Goal 0 complete.

## 8. Goal 0 completion criteria

Goal 0 is **complete** when all of these hold:

- [ ] `gh repo view loganrooks/erebus` returns a public repo.
- [ ] Latest CI run on `main` is green.
- [ ] `pre-commit run --all-files` exits 0 locally.
- [ ] Every doc listed in PROJECT.md §3 exists and is non-empty.
- [ ] `gh api repos/loganrooks/erebus/branches/main/protection`
      shows required status checks + required PR review.
- [ ] No secrets, no `cache/`, no `lab/outputs/`, no `.env` are
      tracked (verified by `git ls-files`).
- [ ] The most recent pre-setup gap analysis
      (`docs/decisions/NNNN-pre-setup-gap-analysis*.md` in the
      live directory) is either marked `status: resolved` and
      archived, or the human has explicitly accepted each item.
      Earlier resolved passes live in
      `docs/decisions/archive/`.
- [ ] The post-setup cross-vendor review (run via `claude -p` per
      WORKFLOW.md §5) reports no MUST-fix items.

## 9. References

- `gh` CLI: https://cli.github.com/manual/
- GitHub Actions docs: https://docs.github.com/en/actions
- Branch protection API:
  https://docs.github.com/en/rest/branches/branch-protection
- gitleaks-action: https://github.com/gitleaks/gitleaks-action
- Astral uv: https://docs.astral.sh/uv/
- Ruff: https://docs.astral.sh/ruff/
- pre-commit hooks index: https://pre-commit.com/hooks.html
