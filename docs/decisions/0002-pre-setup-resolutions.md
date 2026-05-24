# 0002 — Pre-setup gap analysis resolutions

- **Status:** proposed
- **Date:** 2026-05-24
- **Author:** Logan + Claude (proposed); Claude Code (to execute)
- **Related REQ-IDs:** REQ-DOC-001, REQ-SEC-005, plus new REQ-INTEG-001 and REQ-SEC-006 added below
- **Related anchors:** (multiple — see per-finding sections)
- **Supersedes:** N/A (resolves 0001)

## Context

Codex ran the Goal-0 pre-setup audit and produced
`docs/decisions/0001-pre-setup-gap-analysis.md`, which surfaced 17 findings
(8 MUST-resolve, 7 SHOULD-resolve, 2 CONSIDER). This ADR records the
resolution for each finding, identifies the documents that change, and
specifies the edits precisely enough that an agent (Claude Code, working
interactively with Logan) can apply them as a single resolution PR.

Execution discipline:

- Apply resolutions in the order listed below. Structural changes (the
  coverage model, the wrapper architecture, the pinning model) come first
  because mechanical alignments depend on them.
- After each finding's edits, append the resolution line to `0001`'s
  Resolution log (e.g., `Finding 1: anchors added per 0002 §Finding-1; see
  TEST_SPEC.md commit <sha>`).
- One commit per finding, Conventional Commits format, footer references
  the finding number and the resolved REQ-IDs.
- When all MUST-resolve items have resolution-log entries, change `0001`'s
  status to `resolved` and move it to `docs/decisions/archive/0001-pre-setup-gap-analysis.md`.
- Do **not** start Goal-0 setup work (repo create, branch protection, etc.)
  until this resolution PR is merged AND a second Codex audit pass produces
  no MUST-fix items.

---

## Decision summary

| # | Finding (short)                               | Severity | Resolution                                                        |
|---|-----------------------------------------------|----------|-------------------------------------------------------------------|
| 3 | "1:1" contradicts multi-REQ anchors           | MUST     | Adopt many-to-many; rewrite coverage language                     |
| 7 | Dependency pinning is inconsistent            | MUST     | `>=` floors in pyproject.toml + exact pins in uv.lock + preflight |
| 6 | Wrapper path contradicts source layout        | MUST     | Update AGENTS.md to match flat layout; no new `erebus/ingest/`    |
| 1 | REQ↔anchor coverage incomplete                | MUST     | Add 4 MUST anchors; reframe REQ-DOC-001 (MUSTs only)              |
| 2 | Integration anchor has no REQ-ID              | MUST     | Add new REQ-INTEG-001 as integration umbrella                     |
| 4 | CI check names mismatch                       | MUST     | Align WORKFLOW.md to REPO_SETUP.md's job names                    |
| 5 | Empty test dirs make green CI impossible      | MUST     | Add bootstrap test set; clarify anchor-pending semantics          |
| 8 | gitleaks not in dev extras                    | MUST     | Invoke via `pre-commit run` instead of expecting PATH binary      |
| 10| Marker policy not specified                   | SHOULD   | Meta tests carry both `phase1` + `meta`; document in pyproject    |
| 14| README references LICENSE before it exists    | SHOULD   | Add LICENSE to document map; setup order already correct          |
| 15| Workspace not a git repo                      | SHOULD   | `git init` in place; `gh repo create --source=.`                  |
| 12| `render_review.py` undefined                  | SHOULD   | Drop the renderer; post JSON via `gh pr comment` directly         |
| 9 | No-bypass guardrails policy-only              | SHOULD   | Accept as policy; document the audit-trail enforcement model      |
| 11| Cross-vendor review not gateable              | SHOULD   | Manual PR checklist + CI checks artifact exists; defer content gate |
| 13| Recovery tools outside Goal-0 allow-set       | SHOULD   | Add `git-filter-repo` as documented emergency exception           |
| 16| Fixture provenance ungated                    | CONSIDER | Add REQ-SEC-006; synthetic-only fixtures + gitignored lab clips   |
| 17| Name and license preflight implicit           | CONSIDER | Add ADR 0003 recording the `erebus` + MIT decision                |

---

## Structural decisions

### Finding 3 — Coverage model

**Decision:** Adopt many-to-many coverage. An anchor MAY cite multiple
REQ-IDs; an REQ MAY be cited by multiple anchors. The bidirectional
invariant is: every MUST requirement has at least one citing anchor; every
anchor cites at least one valid REQ-ID.

**Files:**
- `docs/REQUIREMENTS.md` — lines 3-7 (intro paragraph)
- `docs/TESTING.md` — line ~71 ("one REQ-ID, sometimes more" is already
  right; leave it)
- `docs/TEST_SPEC.md` — format definition at lines 7-19 (multi-REQ already
  permitted in the format; leave it; add a clarifying sentence)

**Edits:**

In `docs/REQUIREMENTS.md`, replace the intro paragraph with:

> Each requirement has a stable identifier (`REQ-<DOMAIN>-<NUMBER>`) used by
> test anchors in `TEST_SPEC.md` and by commit messages. The cross-reference
> between REQ-IDs and test anchors is bidirectional: every MUST requirement
> SHALL be referenced by at least one anchor in `TEST_SPEC.md`, and every
> anchor SHALL cite at least one valid REQ-ID. SHOULD and MAY requirements
> MAY be anchored but are not required to be. This coverage contract is
> enforced by the docs-consistency check in CI.

In `docs/TEST_SPEC.md`, after the format block at line 19, add:

> An anchor MAY cite multiple REQ-IDs when a single observable behaviour
> satisfies more than one requirement (typical for integration anchors). The
> coverage check counts the anchor against each cited REQ.

**Rationale:** TESTING.md already permits multi-REQ; REQUIREMENTS.md's
"1:1" language was inherited from an earlier draft. Many-to-many is the
correct model for integration tests where one anchor verifies a property
emerging from several REQs working together.

---

### Finding 7 — Pinning model

**Decision:** `pyproject.toml` declares **minimum versions** with `>=`
floors. `uv.lock` (committed) carries **exact resolved versions**. External
binaries (`ffmpeg`, `yt-dlp`, etc.) are checked at host pre-flight against
their declared minimums. The word "pinned" in any doc refers to this
lockfile-pinned model.

**Files:**
- `PROJECT.md` — §11 "Dependencies (Phase 1)"
- `docs/REQUIREMENTS.md` — REQ-SEC-005
- `docs/REPO_SETUP.md` — §1 pre-flight, §3.3 pyproject.toml, §3.7 CI jobs

**Edits:**

In `PROJECT.md` §11, replace:

> Python (pinned in `pyproject.toml`): `typer`, `pydantic` v2, `rich`,
> `tomli`/`tomllib`.

with:

> Python (declared with minimum versions in `pyproject.toml`; exact
> resolved versions locked in `uv.lock` and committed): `typer`,
> `pydantic` v2, `rich`, `tomli`/`tomllib`.

In `docs/REQUIREMENTS.md` REQ-SEC-005, replace the body with:

> The minimum supported `yt-dlp` version SHALL be declared in
> `pyproject.toml`. The exact resolved version SHALL be locked in
> `uv.lock` (committed). The host pre-flight check in
> `docs/REPO_SETUP.md` §1 SHALL verify that the installed `yt-dlp` binary
> meets the declared minimum. A user-supplied environment variable
> `EREBUS_YT_DLP_BIN` MAY override the binary path; if set, the stage SHALL
> log the override.

In `docs/REPO_SETUP.md` §3.3, leave the existing `>=` floors as-is (they
already match this model). After the `[project.optional-dependencies]`
block, add a brief note in prose:

> Exact versions for both runtime and dev dependencies are recorded in
> `uv.lock`, which `uv sync` writes on first install. Commit `uv.lock`
> on the same step as `pyproject.toml`.

Update §1 pre-flight to add a yt-dlp minimum-version assertion:

```bash
# Verify yt-dlp meets declared minimum (e.g. >= 2024.07.16)
yt-dlp --version | awk -F. '{ if ($1 < 2024 || ($1 == 2024 && $2 < 7)) exit 1 }'
```

(Adjust the version threshold to whatever you decide pinned-minimum is at
bootstrap time; document the chosen value in REQ-SEC-005's commentary.)

**Rationale:** This is the standard `uv` workflow. Adds zero friction; the
existing `>=` constraints are correct as written; only the wording needs
to match.

---

### Finding 6 — Wrapper architecture

**Decision:** Collapse the wrapper layer. `erebus/ffmpeg/` remains the
ffmpeg/ffprobe wrapper boundary. yt-dlp invocations live inside the
`ingest` stage at `erebus/stages/ingest.py`; no separate `erebus/ingest/`
package. The non-negotiable rule is unchanged in spirit (subprocess goes
through a typed wrapper, never raw strings); the path in AGENTS.md is
corrected to match the actual layout.

**Files:**
- `AGENTS.md` — non-negotiable rule #1

**Edits:**

In `AGENTS.md`, replace rule #1 with:

> 1. **No raw subprocess strings.** Every `ffmpeg`/`ffprobe` call goes
>    through `erebus/ffmpeg/builder.py`. Every `yt-dlp` invocation goes
>    through the typed wrapper in `erebus/stages/ingest.py`; no other
>    module may call `yt-dlp` directly. Never
>    `subprocess.run(f"ffmpeg ... {user_input} ...")`. See REQUIREMENTS.md
>    REQ-SEC-001 / REQ-SEC-002.

**Rationale:** The audit caught a real typo. The original draft mentioned
`erebus/ingest/` once but REPO_SETUP.md never created it; only one of those
needed to change. Fixing AGENTS.md to match REPO_SETUP.md is simpler than
adding a package layer that wasn't doing useful work.

---

## Mechanical alignments

### Finding 1 — Missing anchor coverage

**Decision:** Add four new anchors for the missing MUST requirements
(REQ-CAPTION-001, REQ-DOC-003, REQ-MIX-001, REQ-MIX-003). Leave the seven
missing SHOULD requirements without anchors for now; the reframed
REQ-DOC-001 (Finding 5) makes this consistent.

**Files:**
- `docs/TEST_SPEC.md` — add four anchors

**Edits — add to TEST_SPEC.md:**

Under the existing Caption section, add:

```
### test_caption_track_start_times_from_manifest — REQ-CAPTION-001

- **Where:** tests/unit/test_caption.py
- **Inputs:** A 3-track manifest with known per-track durations.
- **Behaviour:** The caption stage derives start times exclusively from
  manifest fields; it does NOT call ffprobe or yt-dlp to re-derive them.
- **Assertions:**
  - The generated enable expression's interval boundaries equal the
    cumulative sums of manifest track durations exactly (no rounding
    drift).
  - With ffprobe monkeypatched to raise, the caption stage still
    produces correct output (proves no probe path is taken).
- **Anti-tautology:** A naïve implementation that re-probes input files
  would fail when ffprobe is mocked to raise.
```

Under a new Meta section (or extending the existing one), add:

```
### test_adr_files_match_template — REQ-DOC-003

- **Where:** tests/meta/test_adrs.py
- **Inputs:** Every file under docs/decisions/ matching NNNN-*.md.
- **Behaviour:** Each ADR contains the required sections from TEMPLATE.md.
- **Assertions:**
  - Each ADR has a level-1 heading matching the pattern
    `# NNNN — <title>`.
  - Each ADR contains a `Status:`, `Date:`, `Author(s):` line.
  - Each ADR has level-2 sections "Context", "Decision", "Consequences".
- **Anti-tautology:** A free-form markdown file lacking these sections
  would fail; an ADR genuinely matching the template passes.
```

Under the Mix section, add:

```
### test_mix_uses_two_stream_amix — REQ-MIX-001

- **Where:** tests/integration/test_mix.py
- **Inputs:** A test video clip + a test music clip.
- **Behaviour:** The mix stage's ffmpeg invocation uses
  `amix=inputs=2:...`, not concat or a different mixing approach.
- **Assertions:**
  - The constructed filter graph contains exactly one `amix` node with
    `inputs=2`.
  - Replacing one input with a silent track produces output where that
    stream's contribution is silent (proving the stream entered the mix).
- **Anti-tautology:** A single-stream pass-through would have no amix
  node; a three-stream amix would have wrong inputs count.

### test_mix_video_audio_volume_attenuated — REQ-MIX-003

- **Where:** tests/integration/test_mix.py
- **Inputs:** A test video with known RMS level + a silent music track.
- **Behaviour:** After mixing, the video audio's RMS in the output is
  attenuated by approximately the preset's `volume_db`.
- **Assertions:**
  - Measured RMS_output / RMS_video_input is within 1 dB of
    10**(volume_db/20).
- **Anti-tautology:** No attenuation, or wrong-direction attenuation,
  both fail. The tolerance is tight enough to detect off-by-one in the
  filter chain.
```

**Rationale:** These four are the audit-flagged MUSTs. The SHOULDs
(REQ-CLI-003, REQ-DOC-003 [already addressed above], REQ-ENCODE-003,
REQ-INGEST-005, REQ-LAB-003, REQ-OBS-003, REQ-SEC-005, REQ-VIZ-003) are
intentionally not anchored at this stage; some will be anchored in
Phase 2, some remain SHOULD-level guarantees enforced by review.

---

### Finding 2 — Integration anchor has no REQ-ID

**Decision:** Add a new umbrella requirement `REQ-INTEG-001` and cite it
on `test_phase1_integration`. The new REQ documents the integration test
as a first-class requirement rather than an incidental.

**Files:**
- `docs/REQUIREMENTS.md` — add new REQ-INTEG-001 (new section at end of
  existing requirements, before "Out-of-scope")
- `docs/TEST_SPEC.md` — update the `test_phase1_integration` entry to
  cite REQ-INTEG-001

**Edits:**

In `docs/REQUIREMENTS.md`, add a new section before "Out-of-scope for
Phase 1":

```
## Integration (REQ-INTEG)

### REQ-INTEG-001 [MUST, phase:1] — End-to-end Phase-1 verification

The full `erebus render` pipeline, exercised against synthetic test
playlists, MUST produce an output that simultaneously satisfies the
Phase-1 verification criteria in `PROJECT.md` §4 and the acceptance
points 1-4 in the Phase-1 goal command. This REQ is the integration
umbrella; the individual stage REQs cited by `test_phase1_integration`
are tested separately by their own anchors.
```

In `docs/TEST_SPEC.md`, update the `test_phase1_integration` entry's
header line to:

```
### test_phase1_integration — REQ-INTEG-001

(Cross-references: REQ-CLI-001, REQ-CLI-002, REQ-CONCAT-002,
REQ-GRADE-003, REQ-VIZ-001, REQ-CAPTION-002, REQ-MIX-004,
REQ-ENCODE-001, REQ-ENCODE-002 — all verified individually by their own
anchors; this anchor verifies the composition.)
```

**Rationale:** A dedicated REQ is cleaner than multi-citing nine
requirements on one anchor. The cross-references are informational.

---

### Finding 4 — CI check name alignment

**Decision:** WORKFLOW.md's required-checks list and the PR template
update to match the job names defined in REPO_SETUP.md's CI workflow
(which is what GitHub will actually expose).

**Files:**
- `docs/WORKFLOW.md` — §3 "Required CI checks"
- `docs/WORKFLOW.md` — §3 PR description template (Verification section)

**Edits:**

In `docs/WORKFLOW.md` §"Required CI checks", replace the bulleted list
with:

```
- `lint-and-type`
- `test-unit-meta (ubuntu-latest)`
- `test-unit-meta (macos-latest)`
- `test-integration`
- `gitleaks`
- `docs-consistency`

`test-e2e` runs conditionally (on PRs touching `erebus/`, `presets/`,
or `tests/e2e/`) and is not in the required list. It must still be
green when it runs.
```

Update the PR template's Verification block to reference these job
names exactly.

**Rationale:** GitHub's branch protection consumes job names; aligning
the docs to match REPO_SETUP.md's actual workflow file means
configuration and documentation finally agree.

---

### Finding 5 — Bootstrap test set

**Decision:** Add a bootstrap test set to REPO_SETUP.md that lets CI
go green at Goal-0 completion without inventing anchors prematurely.
Reframe the meta-test contract so pending anchors are normal during a
phase.

**Files:**
- `docs/REPO_SETUP.md` — add a new step 3.6.1 "Bootstrap test set"
  between the source skeleton (3.6) and the CI workflows (3.7)
- `docs/REQUIREMENTS.md` — REQ-DOC-001 reframing (covered also in
  Finding 1 follow-up)
- `docs/TESTING.md` — clarify pending-anchor semantics

**Edits:**

In `docs/REPO_SETUP.md`, add a new subsection §3.6.1:

```
### Step 3.6.1 — Bootstrap test set

The empty test directories from §3.6 would cause `pytest` to exit
non-zero (no tests collected). Add a minimal bootstrap test set that
passes immediately:

`tests/conftest.py`:

```python
"""Pytest configuration for the erebus test suite."""

def pytest_configure(config):
    """Register custom markers."""
    # All markers are declared in pyproject.toml [tool.pytest.ini_options];
    # this hook is reserved for future runtime config.
```

`tests/meta/test_anchors.py`:

```python
"""Docs-consistency: REQ ↔ anchor coverage check."""
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
REQ_FILE = REPO_ROOT / "docs" / "REQUIREMENTS.md"
SPEC_FILE = REPO_ROOT / "docs" / "TEST_SPEC.md"

REQ_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[", re.MULTILINE)
MUST_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[MUST", re.MULTILINE)
ANCHOR_REQ_REF = re.compile(r"### test_\w+\s*—\s*((?:REQ-[A-Z]+-\d{3}[,\s]*)+)")


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


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

Phase-1 stage anchors (per `docs/TEST_SPEC.md`) are NOT created at
Goal 0. They are added during Phase 1 in the RED step of each stage's
red-green-refactor PR cycle. The meta-tests above only check that
*existing* anchors are properly cross-referenced; pending anchors are
normal until their feature PR lands.

Commit: `chore: add bootstrap test set`.
```

In `docs/REQUIREMENTS.md` REQ-DOC-001, replace the body with:

> A CI job MUST verify that:
> - Every MUST requirement in this document is referenced by at least one
>   anchor entry in `TEST_SPEC.md`.
> - Every anchor entry in `TEST_SPEC.md` cites at least one REQ-ID, and
>   every cited REQ-ID exists in this document.
>
> The reverse direction — every `TEST_SPEC.md` entry has a corresponding
> test function in `tests/` — is NOT enforced per-PR. Pending anchors are
> normal during a phase. The phase-completion review (per
> `docs/WORKFLOW.md` §5) verifies that every anchor for the closing phase
> has been implemented before the phase tag is created.

In `docs/TESTING.md`, after the "TDD anchors are not optional" section,
add a paragraph:

> Anchors listed in `TEST_SPEC.md` may exist in either of two states:
> *planned* (in the spec but no corresponding test function yet) or
> *implemented* (test function exists and is tagged
> `@pytest.mark.anchor("<name>")`). Anchors transition from planned to
> implemented in the RED step of their feature PR. The meta-test
> verifies properties of implemented anchors only.

**Rationale:** This resolves the contradiction Codex caught (empty test
dirs → no green CI) while preserving the TDD discipline. The bootstrap
tests are not anchors; they're scaffolding. Phase-1 anchors come in
later PRs as their features are built. The phase-completion review
catches anchors that were planned-but-never-implemented.

---

### Finding 8 — gitleaks invocation

**Decision:** Invoke gitleaks via `pre-commit run` rather than expecting
a `gitleaks` binary on PATH. The pre-commit framework manages the
binary install; this works locally and in CI without per-platform
install steps.

**Files:**
- `docs/TEST_SPEC.md` — update `test_no_secrets_in_repo` invocation
- `docs/REPO_SETUP.md` — CI workflow `gitleaks` job
- `docs/REPO_SETUP.md` — pre-flight notes

**Edits:**

In `docs/TEST_SPEC.md`, update `test_no_secrets_in_repo`'s Assertions
section to:

> - `uv run pre-commit run --hook-stage manual gitleaks --all-files`
>   exits 0.

And in the Where line, this test lives in `tests/meta/` and just shells
out to pre-commit (mark it as integration-grade if you prefer; it's
fast).

In `docs/REPO_SETUP.md` CI workflow, replace the `gitleaks` job with:

```yaml
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
```

In §1 pre-flight, remove any expectation of a system `gitleaks` binary.
Add a note:

> `gitleaks` is managed by `pre-commit` via the hook in
> `.pre-commit-config.yaml`; no separate install needed.

Update `.pre-commit-config.yaml` (described in §3.4) to add
`stages: [pre-commit, manual]` to the gitleaks hook so it's invocable
via `--hook-stage manual`.

**Rationale:** Removes a host-dependency. The pre-commit-managed binary
is the same one the local commit hook uses, so local and CI behaviour
match.

---

### Finding 10 — Marker policy

**Decision:** Meta tests carry **both** `phase1` and `meta` markers.
Pre-commit's pytest invocation uses `-m "phase1 or meta"`. CI's
docs-consistency job uses `-m meta`. The pyproject.toml marker section
explicitly documents this.

**Files:**
- `docs/REPO_SETUP.md` — §3.3 pyproject.toml markers
- `docs/REPO_SETUP.md` — §3.4 pre-commit pytest entry
- `docs/REPO_SETUP.md` — §3.7 CI workflow docs-consistency job

**Edits:**

In §3.3 `pyproject.toml`, update the markers block:

```toml
markers = [
  "phase1: Phase-1 anchors and tests",
  "phase2: Phase-2 (deferred)",
  "phase3: Phase-3 (deferred)",
  "phase4: Phase-4 (deferred)",
  "anchor(name): name of the TEST_SPEC.md anchor this test satisfies",
  "meta: docs-consistency and other meta tests; meta tests should also carry the relevant phase marker",
]
```

In §3.4 `.pre-commit-config.yaml`, update the pytest-fast hook entry:

```yaml
- id: pytest-fast
  name: pytest (unit + meta, phase1 + meta scope)
  entry: uv run pytest tests/unit tests/meta -m "phase1 or meta" --quiet --no-header
  language: system
  pass_filenames: false
  stages: [pre-commit]
```

In §3.7 CI workflow, the `docs-consistency` job already runs
`pytest tests/meta -m meta`; that stays. The `test-unit-meta` job's
invocation becomes `uv run pytest tests/unit tests/meta -m "phase1 or
meta"` to match pre-commit.

**Rationale:** The dual-marker convention is the simplest fix. Both
runners select the meta tests; the docs-consistency job is the
narrower one.

---

### Finding 14 — LICENSE in document map

**Decision:** Add LICENSE to PROJECT.md's document map. Setup order is
already correct (LICENSE at step 3.2, README at step 3.8).

**Files:**
- `PROJECT.md` — §3 document map

**Edits:**

In `PROJECT.md` §3, add a row to the document map table after
`README.md`:

```
| `LICENSE`                  | MIT license text                                                | Visitors          |
```

**Rationale:** Trivial. Resolves the audit's observation that LICENSE
was off-map.

---

### Finding 15 — git init in place

**Decision:** Initialize the existing
`/Users/rookslog/Development/erebus` directory as the git repo via
`git init`, commit the bootstrap, then `gh repo create --source=.`.
This avoids the conflict the audit caught.

**Files:**
- `docs/REPO_SETUP.md` — §2 repository creation

**Edits:**

In `docs/REPO_SETUP.md` §2, replace the current `gh repo create` /
`gh repo clone` sequence with:

```bash
cd /Users/rookslog/Development/erebus     # the existing directory

# Initialize as a git repo
git init -b main

# Stage and commit the bootstrap (the docs are already in place from
# the bootstrap tarball or organize script)
git add .
git status                                # sanity-check the staged set
git commit -m "chore: initial bootstrap (docs + skeleton)"

# Create the GitHub repo from this directory, set origin, push
gh repo create loganrooks/erebus \
  --public \
  --description "Cyberpunk video-mix toolkit. Concat YouTube playlists, overlay music, apply cyberpsycho visual presets." \
  --license=mit \
  --source=. \
  --remote=origin \
  --push
```

Note that `--source=.` requires the directory to be a git repo with at
least one commit — hence the `git commit` step first. The `--license=mit`
flag here adds the LICENSE file in the GitHub-side repo creation; the
local LICENSE file from step 3.2 will collide with it. Two options:

- Pass `--license=mit` and let GitHub generate LICENSE; skip step 3.2
  (delete the local LICENSE before this step if it exists).
- Drop `--license=mit` and keep the locally-generated LICENSE from
  step 3.2.

Recommended: drop `--license=mit` from the `gh repo create` flags
(GitHub doesn't add LICENSE when `--source` is given a non-empty repo)
and keep step 3.2's local LICENSE generation. Verify with `git log`
after that LICENSE is in the initial commit.

**Rationale:** Avoids creating a second checkout. Makes the existing
directory the canonical one.

---

### Finding 12 — Drop `render_review.py`

**Decision:** Remove the renderer script. Post `claude -p`'s JSON output
directly via `gh pr comment --body-file`, optionally piped through `jq`
for a human-readable summary in the comment body.

**Files:**
- `docs/WORKFLOW.md` — §5 stage review checkpoint invocation

**Edits:**

In `docs/WORKFLOW.md` §"How to run a checkpoint with `claude -p`",
replace the stage-review block with:

```bash
PR_NUMBER="$1"
STAGE_NAME="$2"

gh pr diff "$PR_NUMBER" | claude -p \
  --append-system-prompt "$(cat docs/review-prompts/stage-review.md)" \
  --allowedTools "Read,Grep,Glob" \
  --model claude-sonnet-4-6 \
  --output-format json \
  --max-turns 8 \
  > "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.json"

# Extract a markdown summary for the PR comment
jq -r '
  "## Review summary\n\n" + .summary + "\n\n" +
  "**MUST-fix (\(.must_fix | length)):**\n" +
  ((.must_fix // []) | map("- " + .description) | join("\n")) +
  "\n\n**SHOULD-fix (\(.should_fix | length)):**\n" +
  ((.should_fix // []) | map("- " + .description) | join("\n"))
' "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.json" \
  > "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.md"

gh pr comment "$PR_NUMBER" \
  --body-file "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.md"
```

**Rationale:** `jq` is already in every dev environment that has `gh`.
A throwaway shell pipeline beats a maintained Python script for this
purpose.

---

## Policy items

### Finding 9 — Bypass guardrails as policy

**Decision:** Accept that no-bypass is enforced by review and audit
trail, not CI. Document this clearly. A future CI check that scans for
bypass flags in commit metadata may be added in Phase 2.

**Files:**
- `docs/WORKFLOW.md` — §2 "Why we don't bypass hooks"

**Edits:**

In `docs/WORKFLOW.md` §"Why we don't bypass hooks", append:

> **Enforcement model:** This rule is enforced by three layers that work
> together, not by CI:
>
> 1. `NOTES.md` audit trail: every agent turn appends an entry. A bypass
>    leaves a gap or an admission.
> 2. The stage review checkpoint inspects the diff and the commit
>    metadata for forbidden flag usage as part of its security check
>    (per `docs/review-prompts/stage-review.md` Check 5).
> 3. Branch protection requires PR review; a reviewing human (or the
>    cross-vendor agent) can flag suspicious commit patterns.
>
> A future Phase-2 enhancement may add a mechanical CI scan of commit
> metadata for `--no-verify` and `--dangerously-skip-permissions` strings.
> Until then, treat this rule as policy-enforced, not CI-enforced.

**Rationale:** Honest naming. The rule's importance hasn't changed;
its enforcement mechanism is just being correctly described.

---

### Finding 11 — Cross-vendor review gating

**Decision:** Manual PR checklist item plus a CI check that verifies a
review-artifact file exists. Content-quality gating (no MUST-fix items)
is deferred until Phase 2 once the review-output format has stabilized.

**Files:**
- `docs/WORKFLOW.md` — §5 "When to run a checkpoint"
- `docs/REPO_SETUP.md` — CI workflow: add a `review-artifact-exists`
  job to the required checks
- `docs/WORKFLOW.md` — PR template (Verification section)

**Edits:**

In `docs/WORKFLOW.md` §5, after the "When to run a checkpoint" table,
add:

> **Enforcement:** The stage review checkpoint is required by PR
> checklist (manual). A CI job `review-artifact-exists` verifies that a
> review file exists at
> `docs/decisions/reviews/<PR-NUMBER>-*.{json,md}` and is non-empty
> before the PR can merge. The job does NOT inspect content; a reviewer
> with no MUST-fix findings produces a valid artifact equally with a
> reviewer that finds many. Content gating (auto-block on MUST-fix
> items) is a Phase-2 enhancement.
>
> **Fallback paths:** If `claude -p` is rate-limited, run with
> `--model claude-haiku-4-5` as a degraded fallback and note the model
> choice in the review file. If the reviewer is unavailable entirely
> (Anthropic API outage), document the skip in `NOTES.md` and proceed
> with an explicit human signoff in the PR; the review must be run
> retrospectively within 24 hours.

In `docs/REPO_SETUP.md` §3.7 CI workflow, add a job:

```yaml
review-artifact-exists:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v4
    - name: Check for review artifact
      run: |
        PR="${{ github.event.pull_request.number }}"
        if compgen -G "docs/decisions/reviews/${PR}-*.json" > /dev/null; then
          echo "Review artifact found."
        else
          echo "::error::No review artifact at docs/decisions/reviews/${PR}-*.json"
          echo "Run the stage review checkpoint before merging."
          exit 1
        fi
```

Add `review-artifact-exists` to the required-checks list in WORKFLOW.md
§3 and in the branch protection JSON in REPO_SETUP.md §4.

Update the PR template's Verification block to include:

> - [ ] Cross-vendor review run; artifact committed at
>       `docs/decisions/reviews/<PR>-*.json`

**Rationale:** A presence check is cheap and catches the most common
failure mode (forgetting the review). Content gating waits until the
review prompts have produced enough outputs to know what "good" looks
like; auto-blocking on MUST-fix would block legitimate work if the
reviewer is being too aggressive.

---

### Finding 13 — Emergency recovery tools

**Decision:** Add `git-filter-repo` as a documented emergency-recovery
tool exception to Goal-0's tool allow-set. Pre-flight optional.

**Files:**
- `docs/WORKFLOW.md` — §8.3 secret recovery (add install note)
- Goal-0 command's constraint language: leave broadly as-is, but
  document that recovery tools are exempt.

**Edits:**

In `docs/WORKFLOW.md` §8.3, replace the install line with:

> ```bash
> # Install git-filter-repo (one-time, emergency recovery tool)
> # macOS:
> brew install git-filter-repo
> # Linux:
> pip install --user git-filter-repo
> # Or use the standalone script from
> # https://github.com/newren/git-filter-repo
> ```
>
> `git-filter-repo` is exempt from Goal-0's tool allow-set as a
> recovery-only dependency. It is NOT used during normal development.

In `docs/REPO_SETUP.md`, leave the pre-flight as-is (git-filter-repo
isn't needed at setup time; install it only if and when needed for
recovery).

**Rationale:** The Goal-0 tool restriction is about constraining setup
work, not about disallowing emergency response. Documenting the
exception makes the constraint coherent.

---

## Additions

### Finding 16 — Fixture provenance

**Decision:** Add a new requirement REQ-SEC-006 mandating synthetic
fixtures. Lab clips are gitignored by default; provenance must be
recorded in an ADR before any clip is committed. Add
`scripts/generate_fixtures.py` to the bootstrap.

**Files:**
- `docs/REQUIREMENTS.md` — add new REQ-SEC-006 in the Security section
- `docs/REPO_SETUP.md` — §3.1 add `lab/clips/` to .gitignore (already
  has `lab/outputs/`, extend it)
- `docs/REPO_SETUP.md` — §3.6 add `scripts/generate_fixtures.py` stub
- `docs/TESTING.md` — §6 update fixtures section

**Edits:**

In `docs/REQUIREMENTS.md` Security section, add:

```
### REQ-SEC-006 [MUST, phase:1] — Fixture provenance

Test fixtures under `tests/fixtures/` MUST be synthetic — generated by
the committed script `scripts/generate_fixtures.py`, which uses ffmpeg
filters (`testsrc`, `sine`, `color`) and predictable parameters. No
fixture MAY be sourced from copyrighted material, scraped from external
sources, or recorded from a human user.

Lab clips under `lab/clips/` are NOT fixtures and are NOT distributed
with the repo. `lab/clips/` is gitignored. A clip MAY be committed only
if its provenance is recorded in an ADR (public-domain, CC-licensed
with attribution, or original work).
```

In `docs/REPO_SETUP.md` §3.1, add to `.gitignore`:

```
# Lab: clips are not distributed; outputs are scratch
lab/clips/
lab/outputs/
!lab/clips/.gitkeep
!lab/outputs/.gitkeep
```

In `docs/REPO_SETUP.md` §3.6, add a script stub to the source skeleton:

```bash
mkdir -p scripts
touch scripts/generate_fixtures.py
```

The script's actual implementation comes in a Phase-1 PR; a stub at
Goal 0 is fine.

In `docs/TESTING.md` §6, replace the "Fixtures and reference data"
section's intro with:

> Small reference fixtures live in `tests/fixtures/` and MUST be
> synthetic per REQ-SEC-006. The committed
> `scripts/generate_fixtures.py` regenerates them from ffmpeg filters,
> so a fresh check-out can rebuild them locally without copying binary
> blobs into git. The fixtures themselves are committed (for CI speed)
> but are reproducible.

**Rationale:** Removes a public-repo risk surface. Synthetic fixtures
also have better testability properties (known luminance, known
spectrum, etc.) — the audit's CONSIDER finding is actually a quality
improvement.

---

### Finding 17 — Name and license decision

**Decision:** Keep the name `erebus` and the MIT license. Record the
decision as ADR 0003.

**Files:**
- `docs/decisions/0003-name-and-license.md` (new ADR, follows
  TEMPLATE.md)

**Edits:**

Create `docs/decisions/0003-name-and-license.md`:

```markdown
# 0003 — Project name and license

- **Status:** accepted
- **Date:** 2026-05-24
- **Author(s):** Logan Rooks
- **Related REQ-IDs:** (none — policy)
- **Related anchors:** (none — policy)

## Context

The project needs a published name and license before pushing to a public
GitHub repository. The working name has been `erebus` (Greek primordial
of deep darkness, matching the Apollo / Dionysus / Orpheus naming pattern
in Logan's machine inventory). Two licenses were considered.

## Decision

- Project name: **erebus**, repository at `loganrooks/erebus`.
- License: **MIT**.

A `gh search repos erebus --owner=loganrooks` returns no conflict.
"erebus" has prior software use in unrelated domains (a particle physics
analysis framework, several abandoned packages); none have trademark
claims. The project's scope (personal video-mixing tool) does not
require a defensive position against patent claims.

## Consequences

- Repo created as `loganrooks/erebus` (public).
- `LICENSE` file: MIT, generated by `gh api /licenses/mit` at bootstrap.
- README and PROJECT.md both reference "erebus" by name throughout.
- Renaming later requires updating: repo name (via `gh repo rename`),
  PyPI distribution name (not yet published; trivial pre-publication),
  README, PROJECT.md, and AGENTS.md.

## Alternatives considered

### Apache-2.0 license

Would provide an explicit patent grant. Rejected because the project's
domain (ffmpeg orchestration) is not in patent-disputed territory and
MIT's brevity is preferable.

### A different name

`hauntology` was considered (cultural-theory term, on-brand for the
philosophical context) but is harder to type and remember. `cyberpsycho`
was considered but is tightly bound to a single preset and would not
generalize as the project grows. `erebus` won on brevity, mnemonic fit,
and pattern consistency with Logan's other machines.

## References

- `PROJECT.md` §1 (working-name note)
- `gh repo create` output and namespace verification (run at bootstrap).
```

**Rationale:** Records the decision before push so the repo's public
identity has a documented basis.

---

## Execution checklist

When this resolution PR is applied, the following must hold:

- [ ] All 17 findings have entries in `0001`'s Resolution log naming
      the relevant doc changes (commit shas or section references).
- [ ] `0001`'s status is changed to `resolved` and the file moved to
      `docs/decisions/archive/`.
- [ ] `0002` (this file) and `0003` (the name-and-license ADR) are
      committed.
- [ ] `docs/REQUIREMENTS.md` contains the new REQ-INTEG-001 and
      REQ-SEC-006, the reworded intro paragraph, the reworded
      REQ-DOC-001, and the reworded REQ-SEC-005.
- [ ] `docs/TEST_SPEC.md` contains the four new anchors (caption-001,
      doc-003, mix-001, mix-003) and the REQ-INTEG-001 citation on
      `test_phase1_integration`.
- [ ] `docs/TESTING.md` reflects the planned-vs-implemented anchor
      distinction.
- [ ] `docs/WORKFLOW.md` has aligned CI check names, the bypass
      enforcement model paragraph, the cross-vendor review fallback
      paths, and the `review-artifact-exists` job in the required
      list.
- [ ] `docs/REPO_SETUP.md` has step 3.6.1 (bootstrap test set), the
      git-init-in-place §2, the gitleaks-via-pre-commit job, the
      `review-artifact-exists` job, `.gitignore` updates, and the
      `scripts/generate_fixtures.py` stub.
- [ ] `AGENTS.md` has the corrected non-negotiable rule #1.
- [ ] `PROJECT.md` has LICENSE in the document map and the updated
      pinning language.
- [ ] No new files appear outside the planned set; no other docs
      changed beyond what is listed above.
- [ ] After all edits, run the audit again:
      `claude -p "$(cat docs/review-prompts/pre-setup-audit.md)"
      --allowedTools "Read,Grep,Glob" --model claude-opus-4-7
      --output-format text --max-turns 30
      > docs/decisions/0004-pre-setup-gap-analysis-pass-2.md` and
      verify no MUST-fix items remain.

Only after the second-pass audit returns no MUST-fix items does Goal-0
proceed to the actual setup work (repo create, push, branch
protection).
