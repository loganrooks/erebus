# 0007 — Pass-3 resolutions

- **Status:** proposed
- **Date:** 2026-05-24
- **Author(s):** Claude Code (proposed); Claude Code (to execute on approval)
- **Related ADRs:** archive/0004 (pass-2 audit, resolved),
  0005 (pass-2 resolution plan), 0006 (pass-3 audit, this resolves)
- **Related REQ-IDs:** REQ-DOC-001 (Finding 6)
- **Related anchors:** `test_every_req_id_has_test_anchor`,
  `test_every_anchor_cites_valid_req` (new — Finding 6)
- **Supersedes:** N/A (resolves 0006)

## Context

`docs/decisions/0006-pre-setup-gap-analysis-pass-3.md` surfaced 14
findings (2 MUST-resolve, 6 SHOULD-resolve, 6 CONSIDER). Both
MUST findings and three of the SHOULDs trace to defects introduced
by pass-1 (0002) or pass-2 (0005) resolution work — they are debt
my prior passes created. The remaining three SHOULDs and all six
CONSIDERs are Phase-1 design questions or pure-doc cleanup that do
not block Goal-0.

This plan picks **5 findings to resolve in this PR** (2 MUSTs +
3 SHOULDs that are pass-1/2 regressions) and **defers 9** (3
SHOULDs that are Phase-1 design questions, 6 CONSIDERs).

Execution discipline mirrors 0002 and 0005:

- Apply resolutions in the order in the Decision summary table.
  MUSTs first.
- One commit per finding, Conventional Commits format, footer
  references the finding number and resolved REQ-IDs.
- After each commit, append the resolution line to 0006's
  Resolution log (`Finding N: resolved per 0007 §Finding-N; <brief
  summary>`).
- When all 5 accepted resolutions have log entries, change 0006's
  status to `resolved` and `git mv` to
  `docs/decisions/archive/0006-pre-setup-gap-analysis-pass-3.md`,
  with a closing note listing the deferred findings.
- Run pass-4 audit (`claude -p` subprocess) per the same wrapper
  pattern. Goal-0 unblocks only when pass-4 returns zero
  MUST-resolve findings.

---

## Decision summary

| # | Finding (short) | Severity | Action | One-line resolution |
|---|---|---|---|---|
| 1 | mypy pre-commit hook can't resolve `import pytest` in conftest TYPE_CHECKING block | MUST | ACCEPT | Add `pytest >= 8.0` to the mypy hook's `additional_dependencies` |
| 2 | `test-integration` CI job exits 5 against empty `tests/integration/` | MUST | ACCEPT | Add `tests/integration/test_smoke.py` mirroring the unit smoke test |
| 5 | §1 preflight reads `pyproject.toml` before §3.3 creates it | SHOULD | ACCEPT | Hardcode the yt-dlp floor in §1 with a "keep in sync" comment |
| 6 | TEST_SPEC anchor names don't match bootstrap meta-test function names | SHOULD | ACCEPT | Add two new anchors to TEST_SPEC matching the bootstrap functions; tag functions with `@pytest.mark.anchor` |
| 8 | AGENTS.md self-audit instructs "read archives" but pass-3 invocation forbids it | SHOULD | ACCEPT | Add an override-acknowledgment sentence to AGENTS.md |
| 3 | `test_adr_files_match_template` enforces sections audit ADRs lack | SHOULD | DEFER | Phase-1 anchor implementation choice (option (b) filename-pattern carve-out vs (c) frontmatter `template:` key) |
| 4 | REQ-ARCH-005 vs schema-defaults carve-out | SHOULD | DEFER | Phase-1 preset/schema design |
| 7 | `test_caption_fade_timing` extraction method unstated | SHOULD | DEFER | Phase-1 caption-stage implementation |
| 9 | `test_mix_uses_two_stream_amix` silent-input assertion is trivial | CONSIDER | DEFER | Phase-1 mix-stage anchor refinement |
| 10 | `test_concat_lossless_when_inputs_match` time-heuristic unstated | CONSIDER | DEFER | Phase-1 concat-stage anchor refinement |
| 11 | Three redundant gitleaks invocations | CONSIDER | DEFER | Defensible defense-in-depth at Goal 0; trim later if CI minutes hurt |
| 12 | `test-unit-meta` installs ffmpeg on macOS unnecessarily | CONSIDER | DEFER | Trim later when CI minutes hurt; harmless at Goal 0 |
| 13 | `mkdir -p lab/clips` doesn't actually commit a `.gitkeep` | CONSIDER | DEFER | Cosmetic; user can `mkdir` on first lab run |
| 14 | mypy `strict = true` + redundant sub-flags | CONSIDER | DEFER | Cosmetic config cleanup |

ACCEPT: 5 (2 MUST, 3 SHOULD). DEFER: 9 (3 SHOULD, 6 CONSIDER).

---

## Accepted findings

### Finding 1 — Mypy hook needs `pytest` in additional_dependencies

**Decision:** Add `pytest >= 8.0` to the mypy hook's
`additional_dependencies` in `.pre-commit-config.yaml`. `mirrors-
mypy` runs in an isolated env populated only by that list; mypy
evaluates `TYPE_CHECKING` branches even when they don't execute at
runtime, so `import pytest` must resolve.

**Files:**
- `docs/REPO_SETUP.md` — §3.4 `.pre-commit-config.yaml` mypy hook.

**Edits:**

In §3.4, change:

```yaml
- id: mypy
  additional_dependencies:
    - pydantic >= 2.7
    - typer >= 0.12
  args: [--strict]
```

to:

```yaml
- id: mypy
  additional_dependencies:
    - pydantic >= 2.7
    - typer >= 0.12
    - pytest >= 8.0   # for conftest.py's TYPE_CHECKING import
  args: [--strict]
```

**Rationale:** Without this, the first `git commit` blocks because
pre-commit's mypy hook fails on the conftest's
`if TYPE_CHECKING: import pytest` plus `parser: pytest.Parser`
annotation. The CI `lint-and-type` job doesn't hit this because
`uv sync --extra dev` puts pytest in its venv; the pre-commit
hook's env is separate.

---

### Finding 2 — `tests/integration/test_smoke.py` placeholder

**Decision:** Add a placeholder `tests/integration/test_smoke.py`
to REPO_SETUP.md §3.6.1 mirroring the existing `tests/unit/
test_smoke.py`. Same shape, same `@pytest.mark.phase1` marker, so
`pytest tests/integration -m phase1` collects something and exits 0
instead of 5.

**Files:**
- `docs/REPO_SETUP.md` — §3.6.1 bootstrap test set.

**Edits:**

Add to §3.6.1, after the existing `tests/unit/test_smoke.py`
block (before the meta tests):

```python
# tests/integration/test_smoke.py
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

**Rationale:** `pytest` exits 5 ("no tests ran") when zero tests
match the selector — the GitHub Actions step reports this as
failure. `test-integration` is a required check (per §4 branch
protection JSON), so the first PR after bootstrap would fail until
real integration tests land. The placeholder unblocks Goal 0
without masking real "all tests filtered out" regressions later
(when real tests exist, the placeholder is irrelevant).

---

### Finding 5 — Preflight version check uses pre-bootstrap data

**Decision:** Hardcode the `yt-dlp` minimum in §1 preflight as
`2024.7.16` with a comment noting it must be kept in sync with
`pyproject.toml`. Drop the `tomllib`-based dynamic lookup from §1
(the lookup belongs in CI / pre-commit, where pyproject exists).

**Files:**
- `docs/REPO_SETUP.md` — §1 preflight block.

**Edits:**

Replace the §1 yt-dlp check (the `python3 -c "import tomllib..."`
block plus the `awk` comparison) with:

```bash
# yt-dlp version floor (REQ-SEC-005). Keep this in sync with the
# `yt-dlp >= ...` line in pyproject.toml [project.dependencies].
# §1 cannot read pyproject.toml because pyproject doesn't exist
# yet at preflight time; post-bootstrap, `uv sync` enforces the
# pyproject version automatically.
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
```

**Rationale:** §1 is the very first thing the Goal-0 agent runs;
`pyproject.toml` doesn't exist until §3.3. Reading from a file
that doesn't yet exist is the ordering bug. Hardcoding violates
"one source of truth" slightly, but the comment makes the
duplication explicit and the comment is short enough to stay
maintained. Post-bootstrap, `uv sync` from pyproject is the
authoritative pin.

---

### Finding 6 — Anchor-name stability vs bootstrap function names

**Decision:** Add two new anchors to TEST_SPEC.md
(`test_every_must_req_has_anchor_citation`,
`test_every_anchor_cites_valid_req`) matching the bootstrap
function names exactly. Tag the bootstrap functions with
`@pytest.mark.anchor("<name>")` matching the new anchors. Leave
the existing aspirational anchors (`test_every_req_id_has_test_anchor`,
`test_every_anchor_has_test_function`) in place as planned Phase-1
work; their `pending` status is normal per TESTING.md §3.

This preserves anchor stability (no renames) and accurately
describes both what bootstrap ships (the new MUST-only / cite-
valid anchors) and what Phase-1 will add (the broader / pytest-
collection anchors).

**Files:**
- `docs/TEST_SPEC.md` — add two new meta anchors after
  `test_every_anchor_has_test_function`.
- `docs/REPO_SETUP.md` — §3.6.1 add `@pytest.mark.anchor(...)`
  decorators to the bootstrap meta-test functions.

**Edits:**

In `docs/TEST_SPEC.md` Meta anchors section, insert after
`test_every_anchor_has_test_function`:

> ### test_every_must_req_has_anchor_citation — REQ-DOC-001
>
> - **Where:** `tests/meta/test_anchors.py`
> - **Inputs:** Parsed `REQUIREMENTS.md` MUST headings and parsed
>   `TEST_SPEC.md` anchor REQ-ID citations.
> - **Behaviour:** Every MUST requirement is cited by at least one
>   anchor in `TEST_SPEC.md`. This is the bootstrap-minimal
>   coverage check that ships at Goal 0; the broader
>   `test_every_req_id_has_test_anchor` (covering all REQs, not
>   just MUSTs) is Phase-1 work.
> - **Assertions:**
>   - `MUST_REQ_IDs - REQ_IDs_cited_by_any_anchor == set()`.
> - **Anti-tautology:** Adding a new MUST REQ without an anchor
>   fails CI; bootstrap test verified against the resolved 0001
>   audit.
>
> ### test_every_anchor_cites_valid_req — REQ-DOC-001
>
> - **Where:** `tests/meta/test_anchors.py`
> - **Inputs:** Parsed `TEST_SPEC.md` anchor REQ-ID citations and
>   parsed `REQUIREMENTS.md` REQ-IDs.
> - **Behaviour:** Every REQ-ID cited by an anchor exists as a
>   defined REQ in `REQUIREMENTS.md`. Inverse direction of
>   `test_every_must_req_has_anchor_citation`.
> - **Assertions:**
>   - For each anchor in TEST_SPEC, every cited REQ-ID is in
>     `REQ_PATTERN` matches of REQUIREMENTS.md.
>   - Empty citation lists fail.
> - **Anti-tautology:** A typo in an anchor's REQ citation
>   (e.g. `REQ-MIX-006` when no such REQ exists) fails.

In `docs/REPO_SETUP.md` §3.6.1, add `@pytest.mark.anchor(...)`
decorators to the two bootstrap meta-test functions:

```python
@pytest.mark.anchor("test_every_must_req_has_anchor_citation")
@pytest.mark.meta
@pytest.mark.phase1
def test_every_must_req_has_anchor_citation() -> None:
    ...


@pytest.mark.anchor("test_every_anchor_cites_valid_req")
@pytest.mark.meta
@pytest.mark.phase1
def test_every_anchor_cites_valid_req() -> None:
    ...
```

(The `pytest.mark.anchor` mark is forward-compatible — it does
nothing at runtime today, and the Phase-1
`test_every_anchor_has_test_function` meta-test will pick it up
once implemented.)

**Rationale:** TESTING.md §3 commits to anchor stability ("Once
written and merged, their name doesn't change"). Renaming the
bootstrap functions to the TEST_SPEC anchor names would have been
inaccurate (the bootstrap functions enforce a strictly weaker
contract — MUST REQs only). Instead, treat them as separate
anchors with their own names; the broader Phase-1 anchors live
alongside.

This decision adds two anchors but renames zero, so anchor
stability is preserved cleanly.

---

### Finding 8 — AGENTS.md self-audit override note

**Decision:** Add one sentence to AGENTS.md §"Self-audit before
setup work" acknowledging that pass-N invocations may carry an
override that wins over the default "read archives" instruction.

**Files:**
- `AGENTS.md` — §"Self-audit before setup work".

**Edits:**

Add after the existing "Prior passes live in `docs/decisions/
archive/`..." paragraph:

> If the human invokes a later pass with a wrapper prompt that
> overrides this default (e.g. a "cold read — do not read prior
> passes" instruction), the wrapper wins. Cold-read passes are
> useful when the goal is to surface issues that the prior-pass
> framing might have anchored you away from; archive-aware passes
> are useful when the goal is to verify resolutions landed
> correctly. The invocation chooses; AGENTS.md is the default.

**Rationale:** The pass-2 and pass-3 wrapper preambles told the
audit agent to skip the archives even though AGENTS.md says to
read them. Without a doc acknowledgment, the two protocols look
like a contradiction; an agent without a wrapper might "correct"
the apparent inconsistency by reading the archives. The
acknowledgment names the override pattern so future readers
recognize it.

---

## Deferred findings

Each deferred finding is real and worth resolving later; the
rationale for deferring is that the resolution is a Phase-1 design
question or pure-doc cleanup that does not block Goal-0.

### Finding 3 (SHOULD) — `test_adr_files_match_template` vs audit ADR shape

The anchor requires `## Decision` and `## Consequences` sections
that gap-analysis and resolution ADRs do not have. Two reasonable
resolutions (filename-pattern carve-out vs frontmatter
`template:` key) each have Phase-1 implementation implications.
Decide when the anchor is actually implemented in `tests/meta/
test_adrs.py`.

### Finding 4 (SHOULD) — REQ-ARCH-005 vs schema-defaults carve-out

REQ text is absolute ("no preset values MAY be hard-coded"); the
anchor permits pydantic field defaults. Pick during Phase-1
preset/schema design — the answer depends on whether the canonical
preset is intended to be a "complete spec" or a "set of
overrides."

### Finding 7 (SHOULD) — `test_caption_fade_timing` extraction method

The anchor doesn't say HOW to extract the alpha envelope from the
drawtext expression. The right choice depends on which `alpha=`
or `fade=` syntax the caption stage actually emits; decide
alongside Phase-1 caption-stage implementation.

### Finding 9 (CONSIDER) — Mix silent-input assertion is trivial

Replace silent input with a unique tone (e.g. 1 kHz sine) and
assert tone presence. Defer to Phase-1 mix-stage anchor
refinement; the change is cosmetic for Goal-0.

### Finding 10 (CONSIDER) — Concat time-heuristic unstated

Either drop the time check (bitrate alone discriminates) or give
it a concrete threshold. Defer; the concat anchor is Phase-1
work.

### Finding 11 (CONSIDER) — Three gitleaks invocations

Pre-commit + dedicated CI job + `test_no_secrets_in_repo` is
defense-in-depth. Defensible at Goal-0. Trim if CI minutes hurt
later. Note that `test_no_secrets_in_repo` also encodes the
intent ("REQ-SEC-003 has a meta-test") which the other two don't
— removing it would silently drop coverage.

### Finding 12 (CONSIDER) — ffmpeg installed on macOS unit job

`brew install ffmpeg` per matrix run is wasted minutes. Defer;
trim when CI cost becomes a concern. Harmless at Goal-0 throughput.

### Finding 13 (CONSIDER) — `.gitkeep` files not actually created

`mkdir -p lab/clips` doesn't commit anything; the `.gitignore`
carve-out is dead. Trivial fix (touch the .gitkeep files in §3.6)
but defer with the rest of the cosmetic cleanup — it doesn't
break anything since `lab/clips/` is user-supplied content
anyway.

### Finding 14 (CONSIDER) — mypy `strict = true` plus redundant sub-flags

Drop the redundant sub-flags or replace `strict` with explicit
flags. Cosmetic; current behaviour is correct, just verbose.

These deferred items should be transferred to the Phase-1 prep
backlog (alongside the 9 deferred from 0005).

---

## Consequences

- 5 commits land on `main` in the resolution PR, one per accepted
  finding, in Decision summary order (MUSTs first, then ascending
  finding number).
- 9 deferred findings join the Phase-1 prep backlog (alongside
  0005's 9 deferred). Total Phase-1 prep backlog after this PR:
  18 items.
- After execution: 0006's status changes to `resolved`,
  `git mv` to `docs/decisions/archive/`, with a closing note
  listing deferred findings.
- Run pass-4 audit via the same wrapper pattern. If pass-4 returns
  zero MUSTs, Goal-0 unblocks. If pass-4 returns MUSTs, write
  0008 and repeat.
- Documents that change in this PR: `docs/REPO_SETUP.md`,
  `docs/TEST_SPEC.md`, `AGENTS.md`, plus 0006's frontmatter and
  closing note.
- New risks introduced: low. Each accepted edit is small and
  reversible.

---

## Execution checklist

1. **Plan review** — Logan reviews this ADR. If the cut is wrong
   (e.g. fold in a SHOULD), revise before execution.
2. **Apply ACCEPT edits, one commit per finding**, in Decision
   summary order. Each commit's message: title under 72 chars,
   body links to 0007 §, footer references finding number + REQs.
3. **Append to 0006's Resolution log** as each commit lands.
4. **Verify** all 5 entries appear in 0006's log.
5. **Archive 0006**: change status to `resolved`, `git mv` to
   `docs/decisions/archive/`. Add a closing note listing the 9
   deferred findings.
6. **Run pass-4 audit subprocess** with the same wrapper pattern
   (adapt pass number, related-ADRs frontmatter, output path).
7. **Block Goal-0 setup until pass-4 returns zero MUST findings.**
   If pass-4 has MUSTs, write 0009 and repeat. If clean, Goal-0
   proceeds.

---

## References

- `docs/decisions/0006-pre-setup-gap-analysis-pass-3.md` —
  source audit.
- `docs/decisions/0005-pass-2-resolutions.md` — pass-2 resolution
  plan; this plan mirrors its execution discipline.
- `docs/decisions/archive/0001-pre-setup-gap-analysis.md` and
  `docs/decisions/archive/0004-pre-setup-gap-analysis-pass-2.md`
  — prior passes, for historical context only.
- `docs/review-prompts/pre-setup-audit.md` — the audit prompt
  re-used for pass-4.
