# 0009 — Pass-4 resolutions

- **Status:** proposed
- **Date:** 2026-05-24
- **Author(s):** Claude Code (proposed); Claude Code (to execute on approval)
- **Related ADRs:** 0008 (pass-4 audit, this resolves),
  archive/0001, 0002, 0003, archive/0004, 0005, archive/0006, 0007
- **Related REQ-IDs:** (none — meta cleanup)
- **Related anchors:** (none — meta cleanup)
- **Supersedes:** N/A (resolves 0008)

## Context

`docs/decisions/0008-pre-setup-gap-analysis-pass-4.md` surfaced 20
findings (0 MUST, 12 SHOULD, 8 CONSIDER). The audit gate for
Goal-0 is met (zero MUSTs). This plan resolves a focused subset
before the resolution PR merges: the 4 SHOULDs that are my own
debt from pass-2/pass-3 work. The remaining 8 SHOULDs and 8
CONSIDERs join the Phase-1 prep backlog.

This plan is intentionally shorter than 0005/0007. Each ACCEPT
finding is a one-or-two-file edit.

Execution discipline mirrors 0005/0007: one commit per finding,
Conventional Commits format, footer references finding number;
append to 0008's Resolution log; archive 0008 with deferred-
findings closing note; run pass-5 audit; if pass-5 clean (zero
MUSTs), declare the audit cycle complete and the resolution PR
ready to merge.

---

## Decision summary

| # | Finding (short) | Severity | Action | One-line resolution |
|---|---|---|---|---|
| 1 | AGENTS.md Rule 4 references non-existent `## Dependencies` section | SHOULD | ACCEPT | Edit Rule 4 to point to PROJECT.md §11 (auditor option b) |
| 3 | Audit ADRs use `Author:`; template + meta-test expect `Author(s):` | SHOULD | ACCEPT | Sweep all ADRs to `Author(s):`; update audit prompt template |
| 13 | "Section of bootstrap commit:" labels look like commit messages | CONSIDER | ACCEPT | Rephrase to "Conventional-Commits label (post-bootstrap reference):" |
| 20 | NOTES.md empty despite audit work; rule ambiguous | CONSIDER | ACCEPT | Carve out pre-Goal-0 audit work in AGENTS.md NOTES.md rule |
| 2 | yt-dlp Python dep + host binary; resolution order unspecified | SHOULD | DEFER | Phase-1 ingest-stage implementation decision |
| 4 | `test_mix_video_audio_lowpassed` infeasible with single biquad lowpass | SHOULD | DEFER | Phase-1 mix-stage anchor refinement |
| 5 | Pre-commit hook versions are ~2 years stale | SHOULD | DEFER | Bump at bootstrap-execution time (Goal-0 work) |
| 6 | Cyberpsycho fonts (Rajdhani) have no provenance path | SHOULD | DEFER | Phase-1 caption-stage prerequisite; needs licensing decision |
| 7 | REQ-INGEST-001 (mp4) vs REQ-INGEST-005 (format selector) | SHOULD | DEFER | Phase-1 ingest-stage design |
| 8 | REQ-CAPTION-003 fade implementation surface unspecified | SHOULD | DEFER | Phase-1 caption-stage implementation |
| 9 | REQ-OBS-001 stdout/stderr convention is inverted | SHOULD | DEFER | Phase-1 observability design |
| 10 | SHOULD-tagged REQs contain MUST/SHALL body language | SHOULD | DEFER | REQUIREMENTS.md cleanup pass; not urgent |
| 11 | uv/gh have no minimum-version floors in §1 preflight | SHOULD | DEFER | Add floors at bootstrap-execution time |
| 12 | hatchling build backend is not version-pinned | SHOULD | DEFER | Trivial; add at bootstrap-execution time |
| 14 | REQ-MIX-004 loudness measurement strategy unspecified | CONSIDER | DEFER | Phase-1 mix-stage anchor refinement (repeat of pass-2 Finding 6) |
| 15 | byte-identical mp4 anchor needs deterministic flags | CONSIDER | DEFER | Phase-1 anchor refinement (repeat of pass-2 Finding 7) |
| 16 | concat-lossless bitrate proxy is weak | CONSIDER | DEFER | Phase-1 concat-stage anchor refinement |
| 17 | REQ-INTEG-001 references not-yet-existing Phase-1 goal file | CONSIDER | DEFER | Annotate as forward-looking; cosmetic |
| 18 | First-PR `review-artifact-exists` requirement under-documented | CONSIDER | DEFER | Doc nudge; Phase-1 has time to discover and fix |
| 19 | Bootstrap CI-red recovery flow before branch protection lands | CONSIDER | DEFER | Cosmetic; agent discipline implicit |

ACCEPT: 4 (2 SHOULD, 2 CONSIDER). DEFER: 16 (10 SHOULD, 6 CONSIDER).

---

## Accepted findings

### Finding 1 — AGENTS.md Rule 4 ghost section

**Decision:** Edit AGENTS.md non-negotiable Rule 4 to reference
`PROJECT.md §11` (the actual dependency list) instead of the
non-existent `docs/REQUIREMENTS.md §"Dependencies"`.

**Files:** `AGENTS.md` — Rule 4 in the non-negotiable rules
section.

**Edits:** Replace the Rule 4 reference text to read:

> If a stage needs something not in `pyproject.toml`, update
> `PROJECT.md` §11 ("Dependencies (Phase 1)") with the rationale,
> add the dep to `pyproject.toml`, and rerun the pre-setup audit
> before installing.

**Rationale:** `REQUIREMENTS.md` does not have a `## Dependencies`
section and adding one would duplicate `PROJECT.md` §11. Pointing
Rule 4 at the existing list is simpler.

---

### Finding 3 — `Author:` → `Author(s):` sweep

**Decision:** Bring all ADRs into compliance with the template's
`Author(s):` (plural) header, and update the audit-prompt template
in `docs/review-prompts/pre-setup-audit.md` so future audits use
the plural form by default.

**Files:**
- `docs/review-prompts/pre-setup-audit.md` — output template's
  Author line.
- `docs/decisions/0002-pre-setup-resolutions.md`,
  `docs/decisions/0005-pass-2-resolutions.md`,
  `docs/decisions/0007-pass-3-resolutions.md`,
  `docs/decisions/0008-pre-setup-gap-analysis-pass-4.md`,
  `docs/decisions/archive/0001-pre-setup-gap-analysis.md`,
  `docs/decisions/archive/0004-pre-setup-gap-analysis-pass-2.md`,
  `docs/decisions/archive/0006-pre-setup-gap-analysis-pass-3.md`
  — header line 5 (or 7).

**Edits:** In each file, replace the line beginning
`- **Author:** ` with `- **Author(s):** ` (preserve the value).
In the audit prompt template, replace `**Author:**` with
`**Author(s):**` in the prescribed output frontmatter.

**Rationale:** `docs/decisions/TEMPLATE.md` and
`test_adr_files_match_template` both use `Author(s):` (plural).
When the anchor is implemented in Phase 1, every ADR currently
using `Author:` (singular) would fail. The pass-2, pass-3, and
pass-4 wrapper prompts I wrote prescribed the singular form;
correcting the prompt template plus a one-line sweep across the
existing ADRs brings the corpus into compliance.

---

### Finding 13 — "Section of bootstrap commit:" labels read as commit subjects

**Decision:** Replace the label text "Section of bootstrap
commit:" with something that doesn't mimic a commit-subject line.
Keep the Conventional-Commits-style label content (for the
post-bootstrap teaching value) but make the framing word clearly
not a commit subject.

**Files:** `docs/REPO_SETUP.md` — the 9 closing lines in §3.1
through §3.8.

**Edits:** Globally replace
`Section of bootstrap commit: \`` with
`Conventional-Commits label (post-bootstrap reference): \``
in REPO_SETUP.md. Update §3's intro paragraph if needed to match
the new label phrasing.

**Rationale:** Pass-4 noted that a hurried reader still misreads
"Section of bootstrap commit:" as a commit boundary. The new
phrasing "Conventional-Commits label (post-bootstrap reference)"
makes explicit that the label is a teaching example for *future*
commits, not a directive for the bootstrap commit itself. Slightly
more verbose but unambiguous.

---

### Finding 20 — NOTES.md protocol carve-out

**Decision:** Add one sentence to AGENTS.md §"The journal
(NOTES.md)" carving out pre-Goal-0 audit-resolution work as
exempt. Pre-Goal-0 work is already documented in ADRs and commit
logs; duplicating it in NOTES.md adds noise without information.

**Files:** `AGENTS.md` — the NOTES.md journal rule subsection.

**Edits:** Append to the existing journal rule paragraph:

> Pre-Goal-0 audit-resolution work (the iterative pre-setup
> gap-analysis cycle producing ADRs in `docs/decisions/`) is
> exempt from this rule — the audit ADRs and their commit log
> already document each turn. Once Goal 0 lands and Phase 1
> begins, every coding turn appends one line to NOTES.md per the
> standard rule.

**Rationale:** The journal rule was written with coding turns in
mind; applying it literally to docs-only audit work would balloon
NOTES.md with ~50 lines for the audit-resolve cycle, each
duplicating information already in the per-finding commits and
the resolution-log entries in the ADRs themselves. The exemption
makes the intent explicit.

---

## Deferred findings (16)

Each deferred finding is real and worth resolving later; the
rationale for deferring is that it is a Phase-1 design question, a
bootstrap-execution decision (better made at the moment of
bootstrap), or a cosmetic improvement that does not block Goal-0.

**SHOULD (10):**
- Finding 2 — `yt-dlp` host/venv resolution: depends on whether
  the ingest stage subprocesses or imports `yt_dlp`; decide
  during Phase-1 ingest-stage implementation.
- Finding 4 — Lowpass biquad rolloff vs anchor's 20 dB-at-2× ask:
  decide alongside the actual mix-stage filter chain (chained
  lowpass vs anchor relaxation).
- Finding 5 — Pre-commit hook versions stale: bump at Goal-0
  execution time when the agent installs them (pin to whatever is
  current then, record in an ADR).
- Finding 6 — Cyberpsycho fonts: requires a licensing/provenance
  decision before adding to repo; better as its own Phase-1-prep
  task. Caption-stage work blocks on this anyway.
- Finding 7 — `REQ-INGEST-001` (mp4) vs `REQ-INGEST-005` (selector):
  Phase-1 ingest-stage design question.
- Finding 8 — `REQ-CAPTION-003` fade implementation surface:
  Phase-1 caption-stage choice (`drawtext alpha=` vs separate
  `fade` filter).
- Finding 9 — `REQ-OBS-001` stdout/stderr convention: review at
  Phase-1 observability implementation; the inversion may or may
  not have been intentional.
- Finding 10 — SHOULD-tag REQs with MUST/SHALL body language:
  REQUIREMENTS.md sweep; not urgent, low risk.
- Finding 11 — `uv`/`gh` floors in preflight: trivial to add at
  Goal-0 execution time alongside any other preflight tweaks.
- Finding 12 — `hatchling` build backend unpinned: same as 11;
  add at Goal-0 execution.

**CONSIDER (6):**
- Findings 14, 15, 16 — Phase-1 anchor refinements (mix
  loudness measurement, byte-identity determinism, concat
  lossless detection). These repeat earlier-pass concerns that
  were also deferred to Phase-1 design.
- Finding 17 — Forward reference to `goals/`: cosmetic; the
  reference resolves at Goal-0.
- Finding 18 — First-PR review-artifact UX nudge: doc
  improvement; Phase-1 catches this organically.
- Finding 19 — Bootstrap CI-red recovery before branch protection
  lands: cosmetic; agent discipline implicit.

Combined Phase-1 prep backlog after this PR: 9 (from 0005) + 9
(from 0007) + 16 (from this plan) = **34 items**. Track in
`NOTES.md` (post-Goal-0) or as GitHub issues once the repo is
public.

---

## Consequences

- 4 commits land on `main`, one per accepted finding, in Decision
  summary order.
- After execution: 0008's status → `resolved`, `git mv` to
  `docs/decisions/archive/`, closing note lists the 16 deferred
  findings.
- Run pass-5 audit. If pass-5 returns zero MUSTs, declare the
  pre-setup audit cycle complete and the resolution PR ready to
  merge. If pass-5 returns MUSTs, write 0010 and repeat.
- Documents that change: `AGENTS.md`, `docs/REPO_SETUP.md`,
  `docs/review-prompts/pre-setup-audit.md`, the 7 ADRs whose
  Author line changes, plus 0008's frontmatter + closing note.

---

## Execution checklist

1. **Plan review** — Logan reviews this ADR; revise if cut is wrong.
2. **Apply ACCEPT edits, one commit per finding**, in Decision
   summary order. Conventional Commits format; footer references
   finding number.
3. **Append to 0008's Resolution log** as each commit lands.
4. **Verify** all 4 entries appear in 0008's log.
5. **Archive 0008**: status → `resolved`, `git mv` to
   `docs/decisions/archive/`, closing note lists 16 deferred.
6. **Run pass-5 audit** via `claude -p` with adapted wrapper.
7. **If pass-5 returns zero MUSTs:** declare audit cycle
   complete. PR is ready to push and merge. Goal-0 runs as a
   separate goal after merge.
   **If pass-5 returns MUSTs:** write 0011-pass-5-resolutions and
   repeat.

---

## References

- `docs/decisions/0008-pre-setup-gap-analysis-pass-4.md` — source
  audit.
- `docs/decisions/0005-pass-2-resolutions.md`,
  `docs/decisions/0007-pass-3-resolutions.md` — pattern
  precedents.
- `docs/review-prompts/pre-setup-audit.md` — audit-prompt template
  re-used for pass-5.
