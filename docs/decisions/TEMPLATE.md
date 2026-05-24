# NNNN — <short title>

- **Status:** proposed | accepted | superseded by NNNN | resolved | archived
- **Date:** YYYY-MM-DD
- **Author(s):** <name(s) or agent identifier>
- **Related REQ-IDs:** REQ-<DOMAIN>-<NUM>, ...
- **Related anchors:** test_<name>, ...
- **Supersedes:** NNNN (if applicable)

## Context

Why this decision is being made. What problem is it solving? What
constraints are in play? What did we try (if anything) before this
decision?

Keep this section grounded in observable facts and quoted text from
relevant files. Don't editorialize.

## Decision

The decision itself, stated clearly enough that someone reading only
this section knows what to do.

If the decision is "do X", state X. If the decision is "we explored
N options and chose option K", list the options and the rationale.

## Consequences

What changes because of this decision?

- Documents that need updating: ...
- Code that needs to change: ...
- Tests / anchors that need to be added or modified: ...
- Workflows that change: ...
- New risks introduced: ...
- Risks mitigated: ...

## Alternatives considered

Each alternative gets a sub-section with:
- What it would have looked like
- Why it was rejected

This isn't busywork — it's the future-reader's protection against
re-litigating the same question.

### Alternative A: <name>

What it would have looked like.

Why rejected: ...

### Alternative B: <name>

What it would have looked like.

Why rejected: ...

## References

- Links to relevant external sources, papers, or other ADRs.
- Quoted passages from `docs/REQUIREMENTS.md`, `docs/TESTING.md`,
  etc. that informed the decision.

---

## Notes for ADR authors

- Number ADRs sequentially: `0001-`, `0002-`, ... Don't skip numbers
  even if an ADR is rejected (mark it superseded or archived; the
  number stays).
- File naming: `NNNN-short-kebab-title.md`.
- Resolved gap analyses move to `docs/decisions/archive/`.
- An ADR can be amended (small clarifications) but not silently
  rewritten. Material changes mean a new ADR that supersedes the old.
- Reviews live in `docs/decisions/reviews/`, not as ADRs. ADRs are
  for decisions; reviews are audits.
