# 0005 — Pass-2 resolutions

- **Status:** proposed
- **Date:** 2026-05-24
- **Author:** Claude Code (proposed); Claude Code (to execute on approval)
- **Related ADRs:** 0004 (pass-2 audit), 0002 (pass-1 resolution plan, executed)
- **Related REQ-IDs:** REQ-SEC-005, REQ-SEC-006, REQ-CLI-002 (per-finding citations below)
- **Related anchors:** (per finding)
- **Supersedes:** N/A (resolves 0004)

## Context

`docs/decisions/0004-pre-setup-gap-analysis-pass-2.md` surfaced 23
findings (3 MUST-resolve, 13 SHOULD-resolve, 7 CONSIDER). Three of
the MUST-resolve items trace to defects introduced in pass-1
resolution work; the rest are pre-existing gaps that pass-1 missed.

This plan picks **14 findings to resolve in this PR** and **9 to
defer**. The cut is:

- All 3 MUST findings (required to unblock Goal-0's "CI green on
  `main`" criterion).
- 6 SHOULD findings that are pure doc / CI fixes, each <30 lines
  of edits and no architectural decisions: **5, 11, 12, 13, 14,
  15**.
- 5 CONSIDER findings that are cheap doc reconciliations or small
  bootstrap additions: **17, 19, 20, 22, 23**.

The 9 deferred findings (4, 6, 7, 8, 9, 10, 16 SHOULD; 18, 21
CONSIDER) are Phase-1 design questions or optional hardening. They
do not block Goal-0 and benefit from being decided alongside the
actual Phase-1 implementation work rather than pre-emptively.

Execution discipline (mirrors 0002):

- Apply resolutions in the order in the Decision summary table.
  MUSTs first.
- After each finding's edits, append the resolution line to 0004's
  Resolution log (`Finding N: resolved per 0005 §Finding-N; <brief
  summary>`).
- One commit per finding, Conventional Commits format, footer
  references the finding number and the resolved REQ-IDs.
- When all 14 accepted resolutions have log entries, change 0004's
  status to `resolved` and `git mv` to
  `docs/decisions/archive/0004-pre-setup-gap-analysis-pass-2.md`.
  Append a note to 0004 listing the deferred findings and pointing
  to the Phase-1 prep backlog (see `## Deferred findings` below).
- Run pass-3 audit (`claude -p` subprocess) before any Goal-0
  setup work begins.

---

## Decision summary

| # | Finding (short) | Severity | Action | One-line resolution |
|---|---|---|---|---|
| 1 | REQ-SEC-006 has no citing anchor | MUST | ACCEPT | Add `test_fixtures_reproducible_from_generator` meta-anchor citing REQ-SEC-006 |
| 2 | REPO_SETUP §2 vs §3 commit-strategy contradiction | MUST | ACCEPT | Reframe §3's "Commit:" lines as "Bootstrap contents" (auditor option b) |
| 3 | `tests/conftest.py` fails mypy strict | MUST | ACCEPT | Drop the `pytest_configure` stub (auditor option b) |
| 12 | Pre-commit scope inconsistency (TESTING.md vs others) | SHOULD | ACCEPT | TESTING.md §7 → `-m "phase1 or meta"` |
| 15 | `tomli` conditional dependency is dead | SHOULD | ACCEPT | Drop `tomli` from pyproject deps; PROJECT.md §11 → `tomllib` only |
| 19 | AGENTS.md self-audit instruction names `0001` literally | CONSIDER | ACCEPT | Path-abstract both AGENTS.md and REPO_SETUP.md §3.5 references |
| 20 | REPO_SETUP §3.2 LICENSE conditional misleading | CONSIDER | ACCEPT | Make §3.2's `gh api /licenses/mit` unconditional |
| 5 | `test-e2e` CI trigger uses push-only field | SHOULD | ACCEPT | Replace with `paths:` filter on the `pull_request:` event |
| 11 | `yt-dlp` not in `pyproject.toml` | SHOULD | ACCEPT | Add `yt-dlp >= 2024.7.16` to deps; CI uses `uv sync`; preflight reads pyproject |
| 13 | `review-artifact-exists` only matches `.json` | SHOULD | ACCEPT | Glob `${PR}-*`; add size>0 check |
| 14 | "CI green on Ubuntu and macOS" overstates | SHOULD | ACCEPT | Reword PROJECT.md §4 verification point 5 (auditor option b) |
| 17 | Caption anchor: `fade_ms` is ambiguous | CONSIDER | ACCEPT | Rewrite anchor with explicit `fade_in_ms + hold_ms + fade_out_ms` |
| 22 | Lab clips referenced but gitignored | CONSIDER | ACCEPT | Add a subsection to PROJECT.md §9 on clip provision |
| 23 | `--run-e2e` flag has no `pytest_addoption` | CONSIDER | ACCEPT | Add `pytest_addoption` to the bootstrap conftest |
| 4 | Output duration semantics (`min` vs `longest`) | SHOULD | DEFER | Phase-1 design decision |
| 6 | REQ-MIX-004 loudness measurement isolation | SHOULD | DEFER | Phase-1 measurement procedure |
| 7 | Byte-identical CLI vs Python output is non-deterministic | SHOULD | DEFER | Phase-1 anchor design |
| 8 | `erebus.stages.render` absent from skeleton | SHOULD | DEFER | Phase-1 orchestrator API choice |
| 9 | `loudnorm` parameters hard-coded in PROJECT.md example | SHOULD | DEFER | Phase-1 preset/schema extension |
| 10 | REQ-CLI-002 cap vs concat-demuxer | SHOULD | DEFER | Phase-1 architecture choice |
| 16 | REQ-ENCODE-002 framerate normalization implicit | SHOULD | DEFER | Phase-1 encode/grade design |
| 18 | LAB-002 filename can collide within 1s | CONSIDER | DEFER | Lab-UX decision; not load-bearing for Goal-0/Phase-1 |
| 21 | GitHub Actions are major-version tagged, not SHA-pinned | CONSIDER | DEFER | Hardening pass when first secret is introduced |

ACCEPT: 14 (3 MUST, 6 SHOULD, 5 CONSIDER). DEFER: 9 (7 SHOULD, 2 CONSIDER).

---

## Accepted findings

### Finding 1 — REQ-SEC-006 has no citing anchor

**Decision:** Add a new meta-anchor
`test_fixtures_reproducible_from_generator` to `TEST_SPEC.md` that
cites REQ-SEC-006. The anchor asserts that every file under
`tests/fixtures/` is byte-equal to the output of
`scripts/generate_fixtures.py` against a tmpdir. At Goal-0 the
fixture directory is empty so the test trivially passes; the
assertion activates as fixtures are added in Phase 1.

**Files:**
- `docs/TEST_SPEC.md` — add anchor in the "Meta-tests
  (docs/fixtures consistency)" section.

**Edits:**

Add to `docs/TEST_SPEC.md`, in the meta-tests section
(after `test_adr_files_match_template` per the existing ordering):

> ### test_fixtures_reproducible_from_generator — REQ-SEC-006
>
> - **Scope:** Meta; runs in `tests/meta/`.
> - **Setup:** Invoke `scripts/generate_fixtures.py` against a
>   pytest tmpdir.
> - **Assertions:**
>   - For every file under `tests/fixtures/`, an identically-named
>     file exists in the tmpdir output.
>   - Their SHA-256 hashes are equal.
>   - The set of files in `tests/fixtures/` is exactly the set of
>     files written by the generator (no orphans, no extras).
> - **Failure modes guarded:** Hand-edited fixture files,
>   accidentally-committed third-party clips, generator drift that
>   would silently change test inputs.

**Rationale:** REQ-SEC-006 was added in pass-1 Finding 16 (synthetic
fixture provenance) but no anchor cites it. The bootstrap meta-test
`test_every_must_req_has_anchor_citation` will fail at Goal 0
without this. A meta-anchor is the right home: REQ-SEC-006 is a
provenance invariant, not a behavioural property of a stage.

---

### Finding 2 — REPO_SETUP §2 vs §3 commit-strategy contradiction

**Decision:** Adopt the auditor's option (b): §2 stays as a single
bootstrap commit; §3 reframes its per-step "Commit:" lines as
"Bootstrap contents — files added in this step of the walkthrough"
so the walkthrough functions as a content tour, not a literal
commit history.

This matches what the current repo actually did (the baseline
commit on `main` contains all docs as one commit).

**Files:**
- `docs/REPO_SETUP.md` — §3 intro paragraph and each Step 3.N's
  closing "Commit:" line.

**Edits:**

Replace `docs/REPO_SETUP.md` §3's opening paragraph:

> The initial commit creates these files in this order. Each step
> is a separate commit on `main` so the history reads as a setup
> walkthrough.

with:

> The initial commit (per §2) contains the files described in the
> steps below. The per-step structure is a content walkthrough,
> not separate commits — the bootstrap commit is one commit that
> contains everything in §3.1 through §3.8. Subsequent changes
> after the bootstrap land as separate commits per the normal
> workflow.

In each Step 3.N section, replace the closing line
`Commit: \`<type>: ...\`` with:
`Section of bootstrap commit: \`<type>: ...\``

(The conventional-commits "type" prefix is preserved so the
walkthrough still teaches the message style.)

**Rationale:** Pass-1 Finding 15 added §2's single-commit flow but
did not reconcile §3's per-step framing. Picking option (b) over
option (a) avoids forcing a rewrite of the current repo's history
and keeps the doc descriptive of what actually happens at bootstrap.

---

### Finding 3 — `tests/conftest.py` fails mypy strict

**Decision:** Adopt the auditor's option (b): drop the
`pytest_configure` hook from the bootstrap conftest. Markers are
declared in `pyproject.toml`; the hook is purely aspirational at
Goal 0.

**Files:**
- `docs/REPO_SETUP.md` — §3.6.1 `tests/conftest.py` code block.

**Edits:**

Replace the `tests/conftest.py` code block in §3.6.1 with:

```python
"""Pytest configuration for the erebus test suite.

Markers are declared in pyproject.toml [tool.pytest.ini_options];
shared fixtures and hooks go here as they are introduced.
"""
```

(See Finding 23 for an addition to this same file that adds the
`--run-e2e` option; the two edits compose cleanly.)

**Rationale:** The stub function `pytest_configure(config):` has an
untyped parameter and missing return type; `mypy --strict` rejects
it. The hook does nothing at Goal-0 (it's a placeholder), so the
simplest fix is to remove it. A future contributor adding a typed
hook will know to annotate it because the rest of the codebase
will be `--strict`-clean.

---

### Finding 12 — Pre-commit scope inconsistency

**Decision:** Standardize on `-m "phase1 or meta"`. Edit TESTING.md
§7 to match WORKFLOW.md §2 and REPO_SETUP.md §3.4.

**Files:**
- `docs/TESTING.md` — §7 "Running tests" code block.

**Edits:**

In `docs/TESTING.md` §7, replace:

```
Pre-commit runs `pytest tests/unit tests/meta -m phase1 --quiet --no-header`
```

with:

```
Pre-commit runs `pytest tests/unit tests/meta -m "phase1 or meta" --quiet --no-header`
```

**Rationale:** The `-m "phase1 or meta"` form is more explicit and
defends against future meta tests that forget the `phase1` marker.
The three docs should agree.

---

### Finding 15 — `tomli` conditional dependency is dead

**Decision:** Remove the conditional `tomli` dependency from
`pyproject.toml`. The project requires Python ≥ 3.11, which has
`tomllib` in stdlib.

**Files:**
- `docs/REPO_SETUP.md` — §3.3 `pyproject.toml` `dependencies`
  list.
- `PROJECT.md` — §11 dependency list.

**Edits:**

In `docs/REPO_SETUP.md` §3.3, remove the line:

```toml
"tomli >= 2.0; python_version < '3.11'",
```

In `PROJECT.md` §11, change `tomli/tomllib` to `tomllib` (stdlib).

**Rationale:** `requires-python = ">=3.11"` prevents the conditional
from ever activating. Dead code in `pyproject.toml` signals to
readers that 3.10 might be supported.

---

### Finding 19 — AGENTS.md self-audit instruction names `0001`

**Decision:** Replace the literal `0001-pre-setup-gap-analysis.md`
references in AGENTS.md and REPO_SETUP.md §3.5 with abstract
descriptions so a fresh agent doesn't look for a file in the wrong
location or re-run a redundant audit.

**Files:**
- `AGENTS.md` — the "Self-audit before setup work" subsection.
- `docs/REPO_SETUP.md` — §3.5 commit list (if it names the file
  literally; verify when applying).

**Edits:**

In `AGENTS.md`, change:

> produce `docs/decisions/0001-pre-setup-gap-analysis.md`

to:

> produce the next-numbered ADR
> `docs/decisions/NNNN-pre-setup-gap-analysis.md` (subsequent
> passes use `-pass-N` suffixes). Prior passes are in
> `docs/decisions/archive/`. Read those first to understand what
> has already been audited and resolved before producing your own
> findings.

In `docs/REPO_SETUP.md` §3.5, replace any literal
`0001-pre-setup-gap-analysis.md` reference with a description of
the audit output (or the current pass file path).

**Rationale:** Pass-1 Finding 17 (archive 0001) moved the file but
did not update the references. A future agent at Goal 0 would
either re-create 0001 in the live decisions directory (overwriting
the archive's identity) or be confused about which audit is current.

---

### Finding 20 — REPO_SETUP §3.2 LICENSE conditional misleading

**Decision:** Make §3.2 unconditionally generate the LICENSE via
`gh api /licenses/mit`. The conditional ("If it isn't there,
generate it...") was correct under the old §2 flow that passed
`--license=mit` to `gh repo create`; the current §2 explicitly
drops that flag, so the LICENSE is never auto-generated.

**Files:**
- `docs/REPO_SETUP.md` — §3.2.

**Edits:**

In §3.2, replace:

> The MIT LICENSE generated by `gh repo create`. If it isn't
> there, generate it with: `gh api /licenses/mit ...`

with:

> Generate the MIT LICENSE locally before the bootstrap commit:
>
> ```bash
> gh api /licenses/mit --jq .body > LICENSE
> ```
>
> (The `gh repo create` command in §2 deliberately omits
> `--license=mit` to avoid a conflict with this locally-generated
> LICENSE when `--source=.` is a non-empty repo.)

**Rationale:** Pass-1 Finding 14/15 work changed §2 to drop
`--license=mit` but §3.2's conditional language was inherited from
the prior flow. The current docs describe a branch that is
always-taken; making the call unconditional removes the misleading
branching.

---

### Finding 5 — `test-e2e` CI trigger uses push-only field

**Decision:** Replace the broken `if:` expression on the `test-e2e`
job with a `paths:` filter on the workflow's `pull_request:`
trigger. Cleanest GitHub-native solution; no third-party action
needed.

**Files:**
- `docs/REPO_SETUP.md` — §3.7 CI workflow YAML.

**Edits:**

In §3.7, restructure the workflow into two `on:` triggers — one
for the main job set, and a separate workflow (or trigger
condition) for the e2e job that uses `paths:`. The simplest form
is two `pull_request:` clauses at the top:

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
```

and move the e2e job's path-gating into the job-level `if:` using
`tj-actions/changed-files` (already an Ubuntu-standard
third-party action), or split the e2e job to a separate workflow
file with its own `paths:`-filtered `pull_request:`.

I propose the split: a new file
`.github/workflows/test-e2e.yml` (described in REPO_SETUP §3.7)
with:

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - 'erebus/**'
      - 'presets/**'
      - 'tests/e2e/**'
  workflow_dispatch:

jobs:
  test-e2e:
    runs-on: ubuntu-latest
    steps:
      # … same steps as before …
```

and remove the `test-e2e` job (and its `if:` block) from
`.github/workflows/ci.yml`. Update §8 to note that
`test-e2e` remains a required check (the branch protection JSON
should reference its check name from the new workflow; this is a
documentation update, not a behaviour change since branch
protection hasn't been applied yet).

**Rationale:** `github.event.head_commit.modified` is only
populated on `push` events; for PRs it is empty, so the
`contains(...)` check never matches and the e2e job is silently
skipped (which appears as a green check). A skipped required-check
job may or may not satisfy branch protection depending on
configuration — this is a real risk to discover post-bootstrap.
Splitting the workflow is the cleanest fix.

---

### Finding 11 — `yt-dlp` not in `pyproject.toml`

**Decision:** Add `yt-dlp` to `pyproject.toml`
`[project.dependencies]` with the same minimum version the
preflight check enforces. Update the CI workflow to install via
`uv sync` instead of `uv pip install yt-dlp`. Update the preflight
check in REPO_SETUP §1 to read the minimum from `pyproject.toml`
rather than the hard-coded `2024.07` placeholder.

**Files:**
- `docs/REPO_SETUP.md` — §1 preflight, §3.3 `pyproject.toml`,
  §3.7 CI workflow steps.

**Edits:**

In §3.3 `pyproject.toml`, add to `[project.dependencies]`:

```toml
"yt-dlp >= 2024.7.16",
```

(The exact minimum should be audited when applying — pick the
latest stable that fixes the cookies-from-browser regressions
through 2026-05.)

In §3.7 CI workflow, replace any `uv pip install yt-dlp` step
with `uv sync --extra dev`.

In §1 preflight, change:

```bash
# yt-dlp version threshold (placeholder: 2024.07)
yt-dlp --version | <check against 2024.07>
```

to read the minimum from pyproject:

```bash
YT_DLP_MIN=$(python -c "import tomllib; \
  data = tomllib.loads(open('pyproject.toml').read()); \
  deps = data['project']['dependencies']; \
  print([d.split('>=')[1].strip() for d in deps if d.startswith('yt-dlp')][0])")
yt-dlp --version | awk -v min="$YT_DLP_MIN" '{ exit ($1 < min) }'
```

**Rationale:** REQ-SEC-005 calls for `yt-dlp` to be pinned in
pyproject + locked in uv.lock. Bootstrap pyproject not declaring
yt-dlp at all is a contradiction with that REQ and means CI
installs whatever upstream `pip` resolves at run-time. Folding the
install into `uv sync` also tightens the bootstrap reproducibility
story.

---

### Finding 13 — `review-artifact-exists` only matches `.json`

**Decision:** Change the CI bash check to use a glob that matches
any extension and add a non-empty file check.

**Files:**
- `docs/REPO_SETUP.md` — §3.7 CI workflow's
  `review-artifact-exists` job.

**Edits:**

Replace the bash block in the `review-artifact-exists` job with:

```bash
PR="${{ github.event.pull_request.number }}"
DIR="docs/decisions/reviews"

# Match any review artifact for this PR, with any extension,
# requiring size > 0 (non-empty).
matches=$(find "$DIR" -name "${PR}-*" -type f -size +0c 2>/dev/null || true)

if [ -n "$matches" ]; then
  echo "Review artifact(s) found:"
  echo "$matches"
else
  echo "::error::No non-empty review artifact at $DIR/${PR}-*"
  echo "::error::Expected at least one file matching $DIR/${PR}-<reviewer>.{json,md}"
  exit 1
fi
```

**Rationale:** WORKFLOW.md §5 explicitly mentions `.{json,md}` as
the allowed forms; the bash check restricted to `.json` would
reject a reviewer who emits `.md` only. The non-empty check
implements WORKFLOW.md's "non-empty" qualifier that was previously
unimplemented.

---

### Finding 14 — "CI green on Ubuntu and macOS" overstates

**Decision:** Adopt the auditor's option (b): reword PROJECT.md §4
verification point 5 to be honest about which layers run on which
platform.

**Files:**
- `PROJECT.md` — §4 verification surface point 5.

**Edits:**

Replace:

> All Phase-1 TDD anchors green; CI green on Ubuntu and macOS.

with:

> All Phase-1 TDD anchors green. CI matrix coverage:
> `test-unit-meta` runs on Ubuntu and macOS;
> `test-integration` and `test-e2e` run on Ubuntu only.
> macOS-specific concerns (Homebrew ffmpeg codec set,
> AVFoundation hardware encoders per REQ-ENCODE-003) are tracked
> manually by Logan when iterating locally on macOS; if a macOS
> regression surfaces, `test-integration` may be promoted to a
> matrix build at that point.

**Rationale:** The current statement implies more cross-platform
coverage than CI delivers. Option (b) is honest and cheap;
option (a) (full matrix on integration) adds 2-3× CI cost without
clear benefit at Phase 1. The reword preserves the macOS-aware
intent while accurately describing the matrix.

---

### Finding 17 — Caption anchor: `fade_ms` is ambiguous

**Decision:** Rewrite the anchor's arithmetic to use explicit
`fade_in_ms + hold_ms + fade_out_ms`.

**Files:**
- `docs/TEST_SPEC.md` — `test_caption_enable_expression_is_generated`.

**Edits:**

Replace:

> The first clause's interval starts at 0 and ends at hold_ms +
> fade_ms after track 1's start.

with:

> The first clause's interval starts at 0 and ends at
> `fade_in_ms + hold_ms + fade_out_ms` after track 1's start
> (i.e. the total visible duration of one caption envelope).

**Rationale:** `fade_ms` was a non-existent field; the preset has
`fade_in_ms` and `fade_out_ms` separately. The anchor's arithmetic
must be unambiguous so the implementer doesn't have to guess.

---

### Finding 22 — Lab clips referenced but gitignored

**Decision:** Add a short subsection to PROJECT.md §9 (or §7,
whichever section describes the lab workflow) explaining how Logan
obtains the lab clips and what an agent should do when they're
missing.

**Files:**
- `PROJECT.md` — §7 lab clips subsection (or §9 if the lab
  workflow lives there; verify when applying).

**Edits:**

Add at the bottom of the relevant lab subsection:

> ### Obtaining lab clips
>
> The lab clips (`lab/clips/cyberpsycho_30s.mp4`,
> `lab/clips/synthwave_30s.opus`) are not distributable and not
> in the repository. Logan maintains them locally; if an agent
> needs them and they are absent:
>
> - The agent SHALL NOT attempt to download or generate
>   substitutes.
> - The agent SHALL log a note in `NOTES.md` describing what lab
>   verification was skipped and why ("missing clip:
>   `lab/clips/cyberpsycho_30s.mp4`").
> - The agent SHALL flag the missing-clip status in the PR
>   description so the cross-vendor reviewer knows lab
>   verification was not performed (`stage-review.md` Check 8
>   covers this).

**Rationale:** REQ-SEC-006 requires fixtures to be synthetic, so
the lab clips are intentionally not in the repo. But the workflow
references them by name (and Check 8 of the stage review expects
them), so an agent encountering a missing clip needs a documented
graceful-fallback. Otherwise they may try to download a
substitute, violating REQ-SEC-006.

---

### Finding 23 — `--run-e2e` flag has no `pytest_addoption`

**Decision:** Add a `pytest_addoption` hook to the bootstrap
conftest that registers the `--run-e2e` flag. Composes with
Finding 3 (which drops the existing `pytest_configure` stub).

**Files:**
- `docs/REPO_SETUP.md` — §3.6.1 `tests/conftest.py` code block.

**Edits:**

Final `tests/conftest.py` (combining Finding 3 + Finding 23):

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

(The `TYPE_CHECKING`-guarded import keeps `pytest.Parser`
available for type-checking without a runtime import of pytest's
internals.)

**Rationale:** `pytest --run-e2e` will fail with "unrecognized
argument" until `pytest_addoption` is registered. The CI workflow
and the TESTING.md examples both invoke `--run-e2e`; without the
hook, both fail immediately. Folding the addition into the same
conftest edit as Finding 3 produces a single, mypy-strict-clean
file.

---

## Deferred findings

Each deferred finding is real and worth addressing; the rationale
for deferring is that the resolution is a Phase-1 design decision
(better made with implementation context) or an optional hardening
step (better made when the trigger condition is met).

### Finding 4 (SHOULD) — Output duration semantics

`TEST_SPEC` says `min(sum_v, sum_m)`; PROJECT.md §5 example uses
`amix duration=longest`. Three reasonable resolutions (min/longest/
loop-shorter) each have different implications for concat,
captioning, and lab UX. Pick during Phase-1 mix-stage design.

### Finding 6 (SHOULD) — REQ-MIX-004 loudness measurement isolation

`ebur128` measures one stream; the mix is one stream that combines
both sources. The measurement procedure (run twice with sides
muted, vs. pre-mix measurement with mix-math compensation, vs.
stems) is a Phase-1 test-design question.

### Finding 7 (SHOULD) — Byte-identical CLI vs Python output

libx264 + mp4 muxer are not byte-deterministic by default. The
semantic-equivalence formulation (same duration, frame count,
audio sample count, decoded SHA, manifest filter-graph) is better
designed alongside the actual `render` orchestrator and the
manifest schema.

### Finding 8 (SHOULD) — `erebus.stages.render` absent from skeleton

The orchestrator API (`erebus.render` vs `erebus.stages.render` vs
`erebus.cli`) is an architecture decision that the two-track
contract depends on. Better decided in Phase-1's first
architecture-pass than pre-emptively.

### Finding 9 (SHOULD) — `loudnorm` parameters hard-coded in example

Adding `loudnorm_i`, `loudnorm_lra`, `loudnorm_tp` to the
preset/schema and extending the no-hardcoded-values scan is
straightforward but should land alongside the actual mix-stage
preset schema (REQ-MIX-* implementation work).

### Finding 10 (SHOULD) — REQ-CLI-002 cap vs concat-demuxer

Three architectural options (carve-out, separate trim stage,
manifest-level trim). The right choice depends on whether the
boundary track can be partial-trimmed losslessly or requires a
re-encode, which is best decided with concat-stage implementation
context.

### Finding 16 (SHOULD) — REQ-ENCODE-002 framerate normalization

Add `fps=<target_fps>` somewhere in grade or encode. The placement
decision (end of grade vs start of encode) is a Phase-1 stage-
ownership question.

### Finding 18 (CONSIDER) — LAB-002 filename can collide within 1s

Real workflow risk but not load-bearing for Goal-0 or Phase-1.
Decide during actual lab use (millisecond timestamps vs
hash-only filename vs accept overwrites).

### Finding 21 (CONSIDER) — GitHub Actions tag-pinned

SHA-pinning is a hardening step recommended for repos with
permissioned secrets. Phase-1 has no secrets; revisit when the
first secret is added (probably the GitHub release-publishing
flow in a later phase).

These deferred items should be appended to a "Phase-1 prep
backlog" — either a section in this ADR after execution, a
section in `NOTES.md`, or a tracking issue once the repo is public.

---

## Consequences

- 14 commits land on `main` in the resolution PR, one per accepted
  finding, in the order in the Decision summary table (MUSTs
  first, then doc/CI fixes by ascending finding number).
- The 9 deferred findings are documented in this ADR's "Deferred
  findings" section and should be transferred to a backlog
  (`NOTES.md` or a GitHub issues list once the repo is created).
- After execution: 0004's status changes to `resolved`,
  `git mv` to `docs/decisions/archive/`, and a pass-3 audit runs
  via `claude -p` to confirm Goal-0 is no longer blocked.
- If pass-3 returns MUST findings, another resolution cycle (this
  pattern repeats until clean). If pass-3 returns only SHOULDs and
  CONSIDERs, Logan judges whether to defer them all to Phase-1 or
  fold any in.
- Documents that change in this PR: `docs/TEST_SPEC.md`,
  `docs/TESTING.md`, `docs/WORKFLOW.md` (possibly — verify §5
  artifact path syntax), `docs/REPO_SETUP.md`, `PROJECT.md`,
  `AGENTS.md`, plus 0004's frontmatter and 0005's own resolution
  log.
- New risks introduced: low. Each accepted edit is small and
  reversible. Largest blast-radius edit is Finding 5 (splitting
  the CI workflow), which is a configuration change that lands
  before branch protection is applied, so a typo cannot lock the
  branch.

---

## Execution checklist

1. **Plan review** — Logan reviews this ADR. If the cut is wrong
   (e.g. Logan wants more SHOULDs accepted, or wants different
   resolutions for the MUSTs), revise before execution.
2. **Apply ACCEPT edits, one commit per finding**, in Decision
   summary order. Each commit's message:
   - Title: `<type>(<scope>): <one-line>` (Conventional Commits).
   - Body: link to 0005 § for the finding; reference resolved
     REQ-IDs in footer.
3. **Append to 0004's Resolution log** as each commit lands.
4. **Verify** all 14 entries appear in 0004's log.
5. **Archive 0004**: change status to `resolved`, `git mv` to
   `docs/decisions/archive/`. Add a closing note pointing to
   the Deferred-findings section of 0005.
6. **Run pass-3 audit subprocess**:

   ```bash
   claude -p "$(cat docs/review-prompts/pre-setup-audit.md)" \
     --allowedTools "Read,Grep,Glob" --model claude-opus-4-7 \
     --output-format text --max-turns 80 \
     > docs/decisions/0006-pre-setup-gap-analysis-pass-3.md
   ```

   (The pass-2 wrapper preamble's pattern can be reused if desired,
   adapting the pass number and "do not re-read prior audits"
   guidance.)
7. **Block Goal-0 setup until pass-3 returns zero MUST findings.**
   If pass-3 has MUSTs, write 0007-pass-3-resolutions and repeat.
   If clean, Goal-0 (repo create, push, branch protection) proceeds
   as a separate goal.

---

## References

- `docs/decisions/0004-pre-setup-gap-analysis-pass-2.md` —
  source audit.
- `docs/decisions/0002-pre-setup-resolutions.md` — the pass-1
  resolution plan; this plan mirrors its execution discipline.
- `docs/decisions/archive/0001-pre-setup-gap-analysis.md` —
  pass-1 audit (for historical context on what was already
  addressed).
- `docs/review-prompts/pre-setup-audit.md` — the audit prompt
  re-used for pass-3.
