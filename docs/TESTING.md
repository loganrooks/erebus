# Testing

How we test `erebus`. The short version: **tests are executable
specifications written before implementation**. They are not coverage
metrics, not afterthoughts, and not optional. The TDD anchor list
lives in `TEST_SPEC.md` and is part of the goal's verification
surface.

This document explains the *discipline*; `TEST_SPEC.md` carries the
*anchors* themselves.

---

## 1. Why TDD matters more for agents than for humans

Coding agents have smaller "working memory" than humans (Marc Love,
2026). They drift, they pattern-match to recent context, and they
will happily produce code that *looks* like it satisfies an
underspecified intent without actually doing so. Tests collapse intent
into a falsifiable claim that the agent (and the human reviewer)
can verify mechanically.

Empirical work on LLM-generated tests (Shubham Sharma, *Enforcing TDD
in Agentic AI CLIs and IDEs*, 2026) shows that agents tend to produce
**tautological tests** — tests that restate the implementation and
therefore prove nothing. The TDD anchor pattern in §3 is the
countermeasure: anchors are written *before* the implementation
exists, by a human or by the agent operating in RED-only mode, so
they can't be reverse-engineered from the code they're meant to
guard.

Reference: Beck, K. (2002), *Test-Driven Development: By Example* —
the red-green-refactor cycle this document operationalizes for
agentic workflows.

## 2. The three-phase cycle, enforced

Every behaviour change goes through three commits, in this order:

### RED — write the failing anchor
- Add or extend the test in `TEST_SPEC.md` AND in `tests/`.
- Run `pytest -m phase1` and confirm the new test fails for the
  *expected* reason (not for an unrelated reason like an import
  error).
- Commit: `test(<scope>): add red anchor <anchor_name> (REQ-<ID>)`.

### GREEN — minimal implementation
- Write the smallest production-code change that makes the new test
  pass without breaking any existing test.
- No additional features. No "while I'm here" cleanups. No new
  tests beyond trivial signature alignment.
- Commit: `feat(<scope>): satisfy <anchor_name> (REQ-<ID>)`.

### REFACTOR — structural cleanup
- Only structural changes. No new behaviour. All tests stay green.
- Examples: rename a helper, extract a function, dedupe two near-
  identical branches, tighten types.
- Commit: `refactor(<scope>): <what changed>`.

Why three commits, not one? Because the diff for each is a different
shape, and reviewers (human or agent) can audit them at different
levels. A `test(...)` commit answers "what new behaviour?". A
`feat(...)` commit answers "is the implementation minimal?". A
`refactor(...)` commit answers "is the code as clean as it can be?".

If a commit doesn't fit one of these three labels, you're probably
batching unrelated work — split it.

## 3. TDD anchors are not optional

A **TDD anchor** is a specific, named test in `TEST_SPEC.md` that
encodes one requirement (one REQ-ID, sometimes more). Anchors are:

- **Stable.** Once written and merged, their name doesn't change.
  Renaming requires an ADR.
- **Behavioural.** They assert what an external observer would
  check, not how the code is structured internally.
- **Falsifiable.** They can fail. A test that passes for every
  possible implementation is useless.
- **Independent.** Anchors don't share fixtures with overlapping
  invariants unless explicitly designed to.

The Phase-1 goal lists "every Phase-1 anchor in TEST_SPEC.md turns
from red to green" as a verification point. Missing anchors → not
done.

### Anchor naming

`test_<subject>_<observable_behavior>` with optional REQ-ID suffix
when ambiguous. Examples:

- `test_ingest_archive_dedup_skips_known_ids`
- `test_cyberpsycho_darkens_reference_clip`
- `test_caption_enable_expression_is_generated`
- `test_grade_filter_built_via_builder_only`

Avoid:
- `test_ingest_works` (vague)
- `test_grade_function_returns_correct_value` (tautological)
- `test_ingest_with_url_returns_files_and_manifest_and_handles_errors`
  (overloaded; split into separate anchors)

### Anchor lifecycle: planned vs. implemented

Anchors listed in `TEST_SPEC.md` may exist in either of two states:
*planned* (in the spec but no corresponding test function yet) or
*implemented* (test function exists and is tagged
`@pytest.mark.anchor("<name>")`). Anchors transition from planned
to implemented in the RED step of their feature PR. The
docs-consistency meta-test verifies properties of *all* anchors
(every anchor cites a valid REQ-ID; every MUST REQ is cited), but
does not require an implementing test function to exist yet —
pending anchors are normal during a phase. The phase-completion
review catches anchors that were planned-but-never-implemented
before the phase tag is created.

## 4. Test taxonomy

Three layers, plus a meta-test layer for docs consistency:

### Unit tests (`tests/unit/`)

One stage at a time, with deterministic inputs (fixtures, not
yt-dlp). These exercise the Python contract of each stage: input
validation, output shape, error handling. They run in milliseconds
each and form the majority of the suite.

### Integration tests (`tests/integration/`)

Multiple stages chained, with small real video/audio fixtures (a
3-second test clip committed under `tests/fixtures/`). They verify
that stages compose correctly and that the manifest passes between
stages without loss. These run in seconds.

### End-to-end tests (`tests/e2e/`)

The full pipeline on a synthetic playlist (a directory of small
clips + a directory of small audio files, NOT a real yt-dlp call).
The e2e tests are slow (tens of seconds) and run on CI behind a
`--run-e2e` flag, but are required to pass before any Phase-1 release.

### Meta-tests (`tests/meta/`)

Checks on the docs themselves: every REQ-ID in `REQUIREMENTS.md` has
a referencing anchor in `TEST_SPEC.md` and vice versa; every anchor
exists as a test function; every preset file validates against its
pydantic schema; every example in `README.md` actually parses.

## 5. What we don't do

### We don't write tests after the implementation

A test written after the code it tests is heavily contaminated by
the code's structure. The whole point of TDD is to defend against
that contamination. If you find yourself "adding tests" to existing
untested code, treat it as a RED step in a future change, not as
catch-up coverage.

### We don't mock the world

Mocks belong at trust boundaries — places where the real thing is
unreliable, expensive, or non-deterministic. Don't mock pydantic
validation, don't mock pathlib, don't mock `dataclasses.asdict`.
Mock yt-dlp's network call. Mock the wall clock when timestamps
matter. Otherwise: use the real thing.

### We don't chase coverage numbers

100% coverage with bad tests is worse than 60% coverage with good
tests. The TDD anchor count is the metric that matters; coverage is
reported but not gated.

### We don't allow `xfail` to accumulate

`@pytest.mark.xfail` is for tests that capture a known bug we
haven't fixed yet. It MUST come with a linked GitHub issue and a
target date. CI fails if any `xfail` is older than 30 days without
movement.

## 6. Fixtures and reference data

Small reference fixtures live in `tests/fixtures/` and MUST be
synthetic per REQ-SEC-006. The committed
`scripts/generate_fixtures.py` regenerates them from ffmpeg
filters, so a fresh check-out can rebuild them locally without
copying binary blobs into git. The fixtures themselves are
committed (for CI speed) but are reproducible.

- `tests/fixtures/video_3s.mp4` — a 3-second 1920×1080 mp4 with
  predictable content (color bars, a sweep tone, a moving square).
  Used for grading and visualizer tests with checkable luminance /
  spectrum properties.
- `tests/fixtures/audio_3s.opus` — matching 3-second audio with
  known peak frequencies.
- `tests/fixtures/manifest_minimal.json` — a 2-track manifest
  satisfying REQ-INGEST-003 for downstream tests that don't need to
  exercise ingest.

The lab clips (`lab/clips/cyberpsycho_30s.mp4`,
`lab/clips/synthwave_30s.opus`) are *not* fixtures — they're
human-iteration material. Tests don't depend on them.

## 7. Running tests

```bash
# All Phase-1 tests (default for dev work)
uv run pytest -m phase1

# Unit tests only (fastest feedback)
uv run pytest tests/unit -m phase1

# Integration (a few seconds)
uv run pytest tests/integration -m phase1

# End-to-end (slow; gated)
uv run pytest tests/e2e -m phase1 --run-e2e

# Meta tests (docs consistency)
uv run pytest tests/meta

# All of the above
uv run pytest -m "phase1 or meta" --run-e2e
```

CI runs the same commands. Pre-commit runs `pytest tests/unit
tests/meta -m phase1 --quiet --no-header` on every commit; the
slower layers run only in CI.

## 8. Property-based testing

For pure functions with non-trivial input domains (e.g. the
`build_enable_expression` function in the caption stage), use
`hypothesis` to generate random inputs and check invariants. Add a
`hypothesis` strategy alongside the unit test rather than as a
separate file. Bound search time with `@settings(max_examples=50,
deadline=500)` so the suite stays fast.

## 9. Test review during the cross-vendor checkpoint

The stage review checkpoint in `WORKFLOW.md` includes specific
prompts for the reviewer to check whether the new anchors are
tautological. The reviewer's report goes into
`docs/decisions/reviews/`. If the reviewer flags a tautological
anchor, treat it as a MUST-fix.

## 10. References

- Beck, K. (2002), *Test-Driven Development: By Example*. The
  red-green-refactor pattern as originally formulated.
- Sharma, S. (2026), *Enforcing TDD in Agentic AI CLIs and IDEs*,
  Medium. Empirical evidence on agent-produced tautological tests.
- Monnette, J. (2025), *Test-Driven Agentic Development*, Medium.
  Behavioural test suites as agent specifications.
- *TDD Governance for Multi-Agent Code Generation via Prompt
  Engineering*, arXiv:2604.26615 (2026). Phase-label enforcement
  via system prompts.
- *Test-Driven AI Agent Definition*, arXiv:2603.08806 (2026). PRD →
  tests → compilation workflow; the "tests can't be pleased"
  argument against spec-gaming.
- pytest docs: https://docs.pytest.org/
- hypothesis docs: https://hypothesis.readthedocs.io/
