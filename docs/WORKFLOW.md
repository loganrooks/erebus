# Workflow

How to make changes to `erebus`. Covers branching, commits, the
review-checkpoint discipline (including cross-vendor agent reviews),
permission management, and recovery when things go wrong.

This document is mandatory reading for any agent or human about to
modify the repo. The Goal commands enforce adherence; CI catches the
mechanical violations.

---

## 1. Branching

`main` is always green. Never push to `main` directly. Branch
protection in GitHub enforces this; see `REPO_SETUP.md`.

Branch naming:

| Type     | Prefix    | Example                           |
| -------- | --------- | --------------------------------- |
| Feature  | `feat/`   | `feat/ingest-stage`               |
| Bug fix  | `fix/`    | `fix/concat-duration-rounding`    |
| Tests    | `test/`   | `test/grade-cyberpsycho-anchor`   |
| Docs     | `docs/`   | `docs/recovery-procedure`         |
| Refactor | `refactor/` | `refactor/extract-builder-helper` |
| Chore    | `chore/`  | `chore/bump-yt-dlp-version`       |

One logical change per branch. Don't piggyback unrelated fixes onto
a feature branch — the cross-vendor reviewer (see §5) will flag this
and the PR will be sent back.

## 2. Commits

[Conventional Commits](https://www.conventionalcommits.org) format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

`<type>` is `feat`, `fix`, `test`, `docs`, `refactor`, or `chore`.
`<scope>` names the affected stage or area: `ingest`, `concat`,
`grade`, `visualize`, `caption`, `mix`, `encode`, `lab`, `cli`,
`ci`, `docs`.

The subject line is imperative mood, ≤ 72 characters, no trailing
period.

The body explains *why*, not what. The diff already shows what.

The footer is reserved for REQ-ID references and anchor names:

```
Closes REQ-INGEST-002.
Satisfies anchor: test_ingest_archive_dedup_skips_known_ids.
```

### Red-Green-Refactor commits

Per `TESTING.md` §2, behaviour changes go in three commits:

1. `test(grade): add red anchor test_cyberpsycho_darkens_reference_clip`
2. `feat(grade): satisfy test_cyberpsycho_darkens_reference_clip (REQ-GRADE-003)`
3. `refactor(grade): extract luminance helper`

Don't squash these on merge — they are the audit trail.

### What pre-commit hooks check

The pre-commit config (`.pre-commit-config.yaml`) runs on every
local commit:

- `ruff check --fix` — lint with auto-fix
- `ruff format` — formatting
- `mypy .` — type checking
- `pytest tests/unit tests/meta -m "phase1 or meta" --quiet --no-header` —
  fast tests only (unit + meta)
- Standard pre-commit hooks: trailing whitespace,
  end-of-file fixer, large file check, YAML validity, merge conflict
  marker check
- `gitleaks detect --staged --redact` — secret scan on staged files

The full test suite (integration + e2e) runs in CI, not locally.

### Why we don't bypass hooks

`git commit --no-verify` and `--dangerously-skip-permissions` are
permitted only in disposable containers, never on a developer
machine and never on a tracked branch. AI coding agents tend to
reach for these flags when a hook fails (empirical observation from
pydevtools.com handbook); this project's rules treat any use of
either flag on a commit destined for `main` as a hard violation.

If a hook is broken, fix the hook in its own `chore(ci): ...`
commit. Don't bypass it.

**Enforcement model:** This rule is enforced by three layers that
work together, not by CI:

1. `NOTES.md` audit trail: every agent turn appends an entry. A
   bypass leaves a gap or an admission.
2. The stage review checkpoint inspects the diff and the commit
   metadata for forbidden flag usage as part of its security check
   (per `docs/review-prompts/stage-review.md` Check 5).
3. Branch protection requires PR review; a reviewing human (or the
   cross-vendor agent) can flag suspicious commit patterns.

A future Phase-2 enhancement may add a mechanical CI scan of commit
metadata for `--no-verify` and `--dangerously-skip-permissions`
strings. Until then, treat this rule as policy-enforced, not
CI-enforced.

## 3. Pull requests

Open a PR as a draft as soon as the branch has one commit. Drafts
trigger CI without spam-pinging reviewers. Draft early, ready late.

### PR description template

```
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
- [ ] CI jobs green: `lint-and-type`, `test-unit-meta
      (ubuntu-latest)`, `test-unit-meta (macos-latest)`,
      `test-integration`, `gitleaks`, `docs-consistency`,
      `review-artifact-exists`
- [ ] Lab clip rendered + reviewed: `lab/outputs/<filename>`
- [ ] Cross-vendor review run; artifact committed at
      `docs/decisions/reviews/<PR>-*.json`

## Out of scope

<things deliberately not in this PR; link follow-up issues>
```

### Required CI checks

- `lint-and-type`
- `test-unit-meta (ubuntu-latest)`
- `test-unit-meta (macos-latest)`
- `test-integration`
- `gitleaks`
- `docs-consistency`
- `review-artifact-exists`

`test-e2e` runs conditionally (on PRs touching `erebus/`,
`presets/`, or `tests/e2e/`) and is not in the required list. It
must still be green when it runs.

### Merging

Squash-merging is **disabled** at the repo level (it flattens the
red-green-refactor sequence). Merge commits use the default
`gh pr merge --merge` and preserve commit history.

Only the human merges. The agent never merges its own PRs.

## 4. The journal — `NOTES.md`

Every agent turn appends one line:

```
<ISO-8601 timestamp> | <stage|area> | <what changed> | <result/anchor>
```

Example:

```
2026-05-24T18:42:11-04:00 | grade | reduced edge opacity 0.30→0.20; rebuilt lab clip | anchor green; clip cleaner
2026-05-24T18:55:03-04:00 | mix   | added loudnorm to music path; mix dominance now -6 dB → -10 dB | REQ-MIX-004 still red, music too loud now
```

`NOTES.md` lives at the repo root and is committed. It is the audit
trail used for blocker triage and post-mortems. Multiple lines per
PR are normal.

## 5. Cross-vendor review checkpoints

Logan's pattern is to use Codex as the primary developer agent and
Claude Code (or another vendor) as the reviewer. The asymmetry —
different model family, different prompt, different incentive
structure — catches drift and tautologies that the developer agent
would miss in its own output.

### When to run a checkpoint

| Checkpoint                | When                                        | Required? |
| ------------------------- | ------------------------------------------- | --------- |
| Stage review              | Before merging a stage-completion PR        | Yes       |
| Phase completion review   | At the end of a phase, before tagging       | Yes       |
| Architectural review      | Before adopting a new dependency or pattern | Recommended |
| Recovery review           | After invoking the recovery procedure       | Yes       |
| Pre-setup audit (Goal 0)  | First action of Goal 0                      | Yes (by setup goal) |

**Enforcement:** The stage review checkpoint is required by PR
checklist (manual). A CI job `review-artifact-exists` verifies that
a review file exists at
`docs/decisions/reviews/<PR-NUMBER>-*.{json,md}` and is non-empty
before the PR can merge. The job does NOT inspect content; a
reviewer with no MUST-fix findings produces a valid artifact
equally with a reviewer that finds many. Content gating
(auto-block on MUST-fix items) is a Phase-2 enhancement.

**Fallback paths:** If `claude -p` is rate-limited, run with
`--model claude-haiku-4-5` as a degraded fallback and note the
model choice in the review file. If the reviewer is unavailable
entirely (Anthropic API outage), document the skip in `NOTES.md`
and proceed with an explicit human signoff in the PR; the review
must be run retrospectively within 24 hours.

### How to run a checkpoint with `claude -p`

The reviewer is invoked headless via `claude -p` with strict
allowlists. The choice of model and reasoning effort depends on the
review type:

| Review type                     | Model              | Notes                       |
| ------------------------------- | ------------------ | --------------------------- |
| Stage-level diff review         | `claude-sonnet-4-6`| Fast, catches obvious issues |
| Tautological-test audit         | `claude-sonnet-4-6`| Specific prompt; see below   |
| Security review                 | `claude-opus-4-7`  | Subprocess, paths, secrets   |
| Phase completion architectural  | `claude-opus-4-7`  | Slow, deep; reads everything |
| Pre-setup gap analysis          | `claude-opus-4-7`  | Reads all docs              |

Concrete invocations:

#### Stage review checkpoint

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

# Extract a markdown summary for the PR comment. Requires the
# review-prompt (docs/review-prompts/stage-review.md) to instruct
# the reviewer to emit JSON with .summary, .must_fix[], and
# .should_fix[] keys.
jq -r '
  "## Review summary\n\n" + .summary + "\n\n" +
  "**MUST-fix (\(.must_fix | length)):**\n" +
  ((.must_fix // []) | map("- " + .description) | join("\n")) +
  "\n\n**SHOULD-fix (\(.should_fix | length)):**\n" +
  ((.should_fix // []) | map("- " + .description) | join("\n"))
' "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.json" \
  > "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.md"

# Post the review as a PR comment.
gh pr comment "$PR_NUMBER" \
  --body-file "docs/decisions/reviews/${PR_NUMBER}-${STAGE_NAME}.md"
```

The review prompt (`docs/review-prompts/stage-review.md`) checks for:
- subprocess injection / shell escapes (REQ-SEC-001, REQ-SEC-002)
- path traversal (REQ-SEC-004)
- presence of the corresponding test anchor before the
  implementation commit (red-green discipline)
- tautological tests (TESTING.md §1)
- alignment with the listed REQ-IDs
- whether the lab clip was rendered + linked in the PR body

Outputs MUST be classified as `MUST-fix`, `SHOULD-fix`, or
`CONSIDER`. MUST-fix items block the merge.

#### Phase completion review

```bash
PHASE="1"

claude -p "Review the Phase-${PHASE} completion of the erebus project. \
  Read PROJECT.md, REQUIREMENTS.md, TEST_SPEC.md, NOTES.md, and the \
  git log since Goal 0 was completed. Audit: (1) whether every \
  Phase-${PHASE} REQ has a green anchor; (2) whether any anchors are \
  tautological; (3) whether the architectural constraints in \
  REQUIREMENTS.md §Architecture hold across the codebase; (4) any \
  technical debt that should be retired before Phase $((PHASE+1)) \
  begins. Report by REQ-ID with MUST/SHOULD/CONSIDER tags." \
  --allowedTools "Read,Grep,Glob,Bash(uv run pytest *),Bash(git log *),Bash(git diff *)" \
  --model claude-opus-4-7 \
  --output-format json \
  --max-turns 50 \
  > "docs/decisions/reviews/phase-${PHASE}-completion.json"
```

Note the model choice (`claude-opus-4-7`) and the higher `max-turns`
— this is a deep review.

#### Pre-setup gap analysis (Goal 0)

```bash
claude -p "$(cat docs/review-prompts/pre-setup-audit.md)" \
  --allowedTools "Read,Grep,Glob" \
  --model claude-opus-4-7 \
  --output-format text \
  --max-turns 30 \
  > docs/decisions/0001-pre-setup-gap-analysis.md
```

This runs against the docs only (read-only) before any setup
work begins. Goal 0 explicitly stops after writing this file and
waits for the human.

### Permissions for headless review

The reviewer uses `--allowedTools Read,Grep,Glob` (read-only) for
audits. Write access is never granted to the reviewer — reviewers
report, they don't fix. When the reviewer suggests a fix that's
worth making, the human (or the developer agent) implements it on
the developer branch.

`--dangerously-skip-permissions` is **never** used for review
invocations. The whole point is bounded execution.

### Storing review outputs

Reviews live under `docs/decisions/reviews/` and are committed to
the repo. They serve as the audit trail for the goal's completion
and are referenced in the PR that merged the change.

Naming:
- `docs/decisions/reviews/<PR-NUM>-<stage>.md` for stage reviews
- `docs/decisions/reviews/phase-<N>-completion.md` for phase reviews
- `docs/decisions/<NNNN>-<topic>.md` for ADRs
- `docs/decisions/archive/` for resolved gap analyses

## 6. Permissions

### Local development

Run interactively. Approve tool uses per-call. Don't approve broad
patterns like `Bash(*)`. Approve narrow ones: `Bash(uv run *)`,
`Bash(pytest *)`, `Bash(git status)`, `Bash(git diff *)`,
`Bash(ffmpeg *)` (for the lab).

### CI

GitHub Actions runs with the default minimal token scope. The
workflow files set explicit `permissions:` at the top of each job —
no implicit `contents: write`. Secrets (yt-dlp API key, AcoustID
API key when added, etc.) are stored in GitHub Secrets and exposed
only to the jobs that need them.

### Headless agent invocations

For any `claude -p` (or equivalent vendor) call:

1. Set `--allowedTools` to the narrowest set that the task needs.
2. Set `--max-turns` to a reasonable cap (5–10 for reviews; 30–50
   for deep work).
3. Use `--output-format json` when piping to scripts; `text` when
   piping to a human.
4. Never `--dangerously-skip-permissions` outside an isolated
   container.

A list of standard allow-sets lives in
`docs/review-prompts/permissions.md` for reference.

### git worktrees for parallel agent work

When running multiple agent sessions, put each in its own worktree:

```bash
git worktree add ../erebus-feat-grade feat/grade-cyberpsycho
git worktree add ../erebus-feat-mix feat/mix-stage
```

The agent operates in `../erebus-feat-grade` without colliding with
the human's main checkout or with other agent sessions. Worktrees
are also the place where `--dangerously-skip-permissions` becomes
defensible if the rest of the safety stack is in place.

## 7. Blocker protocol

When stuck, **stop**. The temptation to "just try one more thing"
is how agents (and humans) burn through context and produce
worse-than-useless commits. Instead:

1. **Stop editing.** No more commits until the blocker is reported.
2. **Write a blocker note** in `NOTES.md`:
   ```
   <timestamp> | BLOCKED | <stage> | <what failed; what you tried; the exact error>
   ```
3. **Open a draft PR comment** (if a PR exists) with the same content.
4. **Tag the human** in the PR comment.
5. **Wait.** Don't keep working; the human or a higher-reasoning
   reviewer agent will respond.

A good blocker report has:
- The exact command attempted (copy-paste, not paraphrase).
- The actual output (stderr, exit code).
- The expected output.
- The hypothesis about why they diverge.
- The smallest next experiment that would unblock.

A bad blocker report says "ffmpeg won't work" or "tests are failing"
without any of the above. Reviewers can't help with bad reports.

## 8. Recovery

When something has gone wrong — agent went off the rails, secret
got committed, CI broken on main, work lost — these are the
recovery paths in increasing order of severity.

### 8.1 Agent went off the rails (still on a branch, not merged)

Symptoms: agent has been making commits but the code keeps getting
worse; tests are red; the branch has diverged from intent.

```bash
# Find a known-good commit
git log --oneline

# Reset the branch
git reset --hard <known-good-sha>

# Force-push (allowed on feature branches; never on main)
git push --force-with-lease
```

After reset, write an ADR explaining what went wrong and what the
narrower next goal will be: `docs/decisions/NNNN-restart-<topic>.md`.

### 8.2 Bad commits on a feature branch (but the branch is salvageable)

```bash
# Interactive rebase to drop/edit specific commits
git rebase -i <good-sha>

# Or surgically revert one commit
git revert <bad-sha>
git push --force-with-lease
```

### 8.3 Secret committed (any branch, even already pushed)

This is a serious incident. Treat the secret as compromised
*regardless* of how quickly you remove it from git — assume it's
been scraped.

1. **Rotate the secret immediately.** Revoke the API key, generate
   a new one, update GitHub Secrets. This is step one. Removing
   the secret from git is step two.
2. Remove the secret from the current HEAD (if it's there):
   ```bash
   # Edit the file to remove the secret
   git add <file>
   git commit -m "fix(security): remove leaked credential"
   ```
3. Rewrite history if the secret is in older commits:
   ```bash
   # Use git-filter-repo (not the older filter-branch)
   pip install --user git-filter-repo
   git filter-repo --replace-text <(echo "OLDSECRET==>REDACTED")
   ```
4. Force-push and notify all collaborators to rebase.
5. Open an ADR documenting the incident:
   `docs/decisions/NNNN-secret-leak-<short-date>.md`.
6. Run a security review checkpoint to verify cleanup.

### 8.4 CI broken on main

Treat as a stop-the-world event. Don't open any new PRs that
depend on main passing.

1. Identify the breaking commit: `git bisect` between the last
   known-green CI run and the current HEAD.
2. Open a `fix/<broken-thing>` branch from the breaking commit's
   parent.
3. Either fix forward (cheap) or revert the breaking commit
   (`git revert`).
4. Merge the fix via the normal PR process; CI must go green.
5. ADR if the breakage reveals a process gap.

### 8.5 Lost work

`git reflog` is the first stop. Most "lost" work is reachable from
the reflog for ~30 days.

```bash
git reflog
git checkout -b recovered-work <reflog-sha>
```

Stash recovery: `git stash list` then `git stash apply
stash@{N}`.

For genuinely-lost work (force-pushed over with no reflog entry),
check GitHub's web UI under "Insights → Network" — sometimes orphan
commits are still reachable via the API.

### 8.6 Permissions accidentally too broad

Symptoms: an agent invocation used `--allowedTools "*"` or
`--dangerously-skip-permissions` on a non-disposable environment.

1. Stop the running invocation.
2. Audit what the agent did: `git log` since the invocation
   started; `git diff <pre-invocation-sha>`.
3. Roll back any commits that don't pass the normal red-green
   discipline.
4. Add a permissions-incident ADR.
5. If the agent had shell access, audit shell history
   (`~/.bash_history` or equivalent) and reflog.

### 8.7 The "panic button"

If the situation is bad enough that none of the above feels safe:

1. Stop all running agents.
2. Create a backup branch from the current state:
   ```bash
   git branch backup/$(date +%Y%m%d-%H%M%S)
   ```
3. Reset main to the last known-green CI run:
   ```bash
   git reset --hard <last-green-sha>
   ```
4. Open an ADR explaining what happened and what the new goal
   command will be.
5. Resume with a narrowed goal.

The backup branch preserves evidence for the post-mortem without
keeping the bad state in main.

## 9. Tagging and releases

Phase completions get a git tag: `phase-1-complete`,
`phase-2-complete`, etc. The tag is created only after the phase
completion review checkpoint passes with no MUST-fix items.

Versioning follows SemVer, but bumps come at phase boundaries:
- Pre-1.0 phases bump the minor version: 0.1.0 after Phase 1,
  0.2.0 after Phase 2, etc.
- The 1.0.0 tag awaits "the project is genuinely usable by someone
  who isn't Logan" — likely Phase 3 or 4.

## 10. References

- Conventional Commits: https://www.conventionalcommits.org/
- pre-commit framework: https://pre-commit.com/
- git-filter-repo: https://github.com/newren/git-filter-repo
- gitleaks: https://github.com/gitleaks/gitleaks
- Claude Code headless mode:
  https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-headless
- AGENTS.md spec: https://agents.md/
- Codex Goals primer:
  https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex
- The empirical observation about agents bypassing pre-commit:
  https://pydevtools.com/handbook/how-to/how-to-set-up-pre-commit-hooks-for-a-python-project/
