# AGENTS.md

Instructions for AI coding agents (Codex CLI, Cursor, GitHub Copilot,
Gemini CLI, and others that read the `AGENTS.md` open standard
stewarded by the Linux Foundation). Claude Code reads `CLAUDE.md`,
which imports this file.

**Read PROJECT.md before doing anything else.** It defines the
architecture and the current phase. The current phase's goal command
is the contract; this file is the operating manual.

## Project summary

`erebus` is a Python toolkit that ingests YouTube playlists via
`yt-dlp`, applies an ffmpeg-based video processing pipeline, and
produces background mix videos. It has two surfaces — a CLI for human
users and a typed Python module for agents — that share one engine.

Stack:
- Python ≥ 3.11
- `uv` for dependency / environment management
- `ruff` for lint + format
- `mypy` for type checking
- `pytest` for testing
- `pre-commit` for local hook enforcement
- GitHub Actions for CI
- External binaries: `ffmpeg` ≥ 6, `yt-dlp`, `ffprobe`

## Non-negotiable rules

These rules are *hard constraints*. Violating them is grounds for the
human to revert the agent's work and restart with a narrower goal.

1. **No raw subprocess strings.** Every `ffmpeg`/`ffprobe` call goes
   through `erebus/ffmpeg/builder.py`. Every `yt-dlp` invocation goes
   through the typed wrapper in `erebus/stages/ingest.py`; no other
   module may call `yt-dlp` directly. Never
   `subprocess.run(f"ffmpeg ... {user_input} ...")`. See
   REQUIREMENTS.md REQ-SEC-001 / REQ-SEC-002.

2. **No `--no-verify` on commits.** Pre-commit hooks exist for a
   reason. If they fail, fix the code, not the hook invocation. AI
   coding agents reach for `--no-verify` more readily than humans;
   this rule guards against that tendency (see WORKFLOW.md §"Why
   we don't bypass hooks").

3. **No `--dangerously-skip-permissions`** on Claude Code, no `-y`
   on yt-dlp prompts, no equivalent flag on any other tool — unless
   you are demonstrably inside a disposable container or a worktree
   that the human has approved for that mode.

4. **No new dependencies without a docs update.** If a stage needs
   something not in `pyproject.toml`, update `docs/REQUIREMENTS.md`
   §"Dependencies" with the rationale, then rerun the pre-setup
   audit before installing.

5. **Tests come before implementation.** The TDD anchor for the
   behaviour you're implementing must exist in
   `docs/TEST_SPEC.md` and be failing before you write any
   production code. See `docs/TESTING.md` §"TDD anchors are not
   optional".

6. **One stage, one branch, one PR.** Don't batch unrelated changes.
   See WORKFLOW.md §"Branching and commits".

7. **No secrets in code or commit messages.** Use environment
   variables, GitHub Secrets, or `.env` (which is gitignored). See
   REQUIREMENTS.md REQ-SEC-003.

8. **The lab is the iteration surface.** Before changing a filter
   chain in `erebus/ffmpeg/presets.py`, run it through `erebus lab
   apply` on the 30-second reference clips. Commit a `NOTES.md`
   entry pointing at the lab output you reviewed.

## Working conventions

### Code style

Ruff and mypy are configured in `pyproject.toml`. Run
`uv run ruff check --fix && uv run ruff format && uv run mypy .`
before committing. Pre-commit will run this anyway; the explicit run
is faster than fixing a rejected commit.

Type-annotate every public function. Internal helpers can be
inferred. `Any` is allowed only when calling into untyped C extensions
(e.g. `cv2`); document the choice with a comment.

Module layout: see PROJECT.md §3. New stages go under
`erebus/stages/<name>.py` and re-export from `erebus/stages/__init__.py`.

### Stages

A stage is a pure function with this contract:

```python
def run(
    *,
    input_paths: list[Path],
    params: StageParams,         # a pydantic model
    work_dir: Path,
    log: logging.Logger,
) -> StageResult:
    ...
```

`StageResult` carries the output path(s) and any metadata the next
stage needs. Stages communicate via files on disk (ffmpeg is the
backplane), not in-memory pipes — this lets the lab apply any stage
in isolation. Detailed contract in REQUIREMENTS.md §"Stage protocol".

### Tests

Pytest, marked by phase: `@pytest.mark.phase1`, `@pytest.mark.phase2`,
etc. Run the full Phase-1 suite via `uv run pytest -m phase1`. CI
runs everything. The TDD anchor list is `docs/TEST_SPEC.md`; every
new behaviour gets an anchor there first.

Don't write tautological tests. A test that does
`assert stage.run(...).output == stage.run(...).output` proves
nothing. Tests must encode the *requirement* — what an external
observer would check to be convinced the code works.

### Commits

Conventional Commits format: `<type>(<scope>): <subject>`. Examples:
- `feat(stages): add ingest stage with archive dedup`
- `test(grade): add red anchor for cyberpsycho darkening`
- `fix(ingest): handle yt-dlp's "video unavailable" exit code`
- `docs(workflow): clarify recovery procedure for committed secrets`

Each commit message must reference the relevant REQ-ID and/or test
anchor when applicable: `Closes REQ-INGEST-002; satisfies anchor
test_ingest_archive_dedup_skips_known_ids.`

### Branches and PRs

One branch per logical change. Branch names: `<type>/<short-slug>`,
e.g. `feat/ingest-stage`, `fix/concat-duration-rounding`. Open a
draft PR early; the GitHub Actions checks help you stay in green
territory while iterating. Mark "Ready for review" when CI is green
AND the cross-vendor review checkpoint (see WORKFLOW.md) is run.

### Cross-vendor review checkpoints

After completing a stage AND before merging the PR, run the
review checkpoint described in WORKFLOW.md §"Stage review
checkpoint". This invokes `claude -p` (or `gemini`, or another
vendor) as a second-set-of-eyes reviewer. Save the review output
under `docs/decisions/reviews/<PR-NUM>-<stage>.md`.

If the reviewer surfaces a MUST-fix item, address it before merging.
SHOULD-fix items can be deferred via an issue; CONSIDER items are
optional.

### The journal (NOTES.md)

Append one line per turn:

```
2026-05-24T18:42:11-04:00 | grade | reduced edge opacity 0.30→0.20; lab clip looked cleaner | anchor green
```

Format: ISO-8601 timestamp `|` stage `|` what changed `|` lab clip or
anchor result. This is the audit trail that makes blockers
recoverable; see WORKFLOW.md §"Recovery".

## Self-audit before setup work (Goal 0 only)

If you are operating under Goal 0, your **first action** is the
pre-setup self-audit defined in the goal. Read every document listed
in PROJECT.md §3 in full, then produce the next-numbered ADR at
`docs/decisions/NNNN-pre-setup-gap-analysis.md` (subsequent passes
use a `-pass-N` suffix, e.g.
`docs/decisions/0004-pre-setup-gap-analysis-pass-2.md`) listing
every contradiction, missing piece, and ambiguity you find. Stop
there and surface to the human. Do not begin setup work until the
human resolves each item.

Prior passes live in `docs/decisions/archive/` after their MUST
items have been resolved. Read those archives before producing your
own findings so you do not re-raise issues that have already been
addressed; if you believe a past resolution was applied incorrectly
or introduced a new problem, raise that as a finding in your pass.

If the human invokes a later pass with a wrapper prompt that
overrides this default (e.g. a "cold read — do not read prior
passes" instruction), the wrapper wins. Cold-read passes are
useful when the goal is to surface issues that the prior-pass
framing might have anchored you away from; archive-aware passes
are useful when the goal is to verify resolutions landed
correctly. The invocation chooses; AGENTS.md is the default.

This is not optional and not skippable. You are the first reviewer of
the human's own plan, and they expect you to catch what they missed.

## When stuck

The blocker protocol in WORKFLOW.md §"Blocker protocol" describes
exactly how to report a block. The short version:

1. Stop. Don't keep trying random things.
2. Write the exact command attempted, expected output, actual output.
3. State the smallest next experiment that would unblock.
4. Surface to the human and wait.

Do not invent workarounds that violate the rules above to escape a
blocker. If the rules and the work are in tension, the rules win and
the work waits.

## References

- AGENTS.md spec: https://agents.md
- Codex goals: https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex
- Claude Code headless: https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-headless
- Beck, K. (2002), *Test-Driven Development: By Example*
- Conventional Commits: https://www.conventionalcommits.org
- pre-commit framework: https://pre-commit.com
- Ruff: https://docs.astral.sh/ruff
- uv: https://docs.astral.sh/uv
