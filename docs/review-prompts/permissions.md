# Permissions reference

Standard `--allowedTools` allow-sets for headless agent invocations
on this project. Use the narrowest set that the task requires. This
file is consulted by humans wiring up new automations and by agents
that need to launch sub-invocations.

Source for the `claude -p` flag semantics:
[Claude Code headless mode docs](https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-headless).

---

## The rule

The default posture is **deny everything; permit narrowly**. Never
use `--allowedTools "*"` outside an explicitly disposable container.
Never use `--dangerously-skip-permissions` on a host that contains
anything you'd be sad to lose.

`--allowedTools` accepts tool names (`Read`, `Bash`, `Write`, `Edit`,
`Grep`, `Glob`), and supports prefix matching with `*`. The trailing
space matters: `Bash(git diff *)` matches `git diff anything`, while
`Bash(git diff*)` would also match `git diff-index`. Be deliberate.

---

## Allow-set 1: Read-only audit

Use for: gap analyses, code reviews, security audits, any
investigation that produces a report and doesn't change state.

```bash
--allowedTools "Read,Grep,Glob"
```

This is the safest set. The reviewer can read any file in the repo,
grep through them, and use glob patterns. It cannot run shell
commands, cannot edit, cannot write new files (the output is
captured via stdout redirection, not via tool calls).

Used by:
- Pre-setup gap analysis (`docs/review-prompts/pre-setup-audit.md`)
- Stage review checkpoint (`docs/review-prompts/stage-review.md`)
- Ad-hoc "explain this code to me" invocations

---

## Allow-set 2: Read + narrow Bash for inspection

Use for: phase completion reviews, deep architectural audits, any
review that needs to run tests or inspect git history.

```bash
--allowedTools "Read,Grep,Glob,\
Bash(uv run pytest *),\
Bash(git log *),\
Bash(git diff *),\
Bash(git show *),\
Bash(ffprobe *)"
```

Notes:
- The `Bash(uv run pytest *)` pattern lets the reviewer run the test
  suite without permitting arbitrary `uv` commands (which could
  install packages or write to the env).
- `git log/diff/show` are read-only operations.
- `ffprobe` is read-only on its input files.

Used by:
- Phase completion review (`docs/review-prompts/phase-completion.md`)
- Recovery audits (after invoking the recovery procedure in
  `WORKFLOW.md` §8)

---

## Allow-set 3: Stage development (interactive only)

Use for: implementing a stage. Run interactively, not headless.

```bash
# Interactive — Claude prompts per call.
claude
# (no --allowedTools; permissions granted per-call as prompted)
```

Or if you want pre-approved patterns for an interactive session:

```bash
claude \
  --allowedTools "Read,Write,Edit,Grep,Glob,\
Bash(uv *),\
Bash(pytest *),\
Bash(pre-commit *),\
Bash(ruff *),\
Bash(mypy *),\
Bash(ffmpeg *),\
Bash(ffprobe *),\
Bash(yt-dlp *),\
Bash(git status),\
Bash(git diff *),\
Bash(git add *),\
Bash(git commit *)"
```

Note that `git commit` is included but `git push` is not. Pushing is
a human decision.

Used by:
- Developer agent (Codex CLI, or Claude Code in interactive mode)
  working on a stage.

---

## Allow-set 4: CI automation

Use for: tasks the CI workflow itself invokes, e.g. an auto-PR
comment on test failure.

```bash
--allowedTools "Read,Grep,Glob,\
Bash(gh pr view *),\
Bash(gh pr comment *),\
Bash(gh issue create *)"
```

In CI, the GitHub token is scoped via the workflow's `permissions:`
block. The token determines what `gh` can actually do; the
`--allowedTools` is the defence-in-depth layer ON TOP of that.

Used by:
- GitHub Actions jobs that invoke `claude -p` to comment on PRs or
  open follow-up issues.

---

## Allow-set 5: Disposable container (the "agent fleet" pattern)

Use for: experimental work where the agent might break things and
that's fine because the container will be discarded.

```bash
# Inside a Docker container or VM with no host filesystem mounts:
claude -p "..." --dangerously-skip-permissions --max-turns 100
```

This is the only context in which `--dangerously-skip-permissions`
is acceptable. Conditions:
- The container has no access to the host's git config, SSH keys,
  AWS credentials, or other secrets.
- The container has no network access except through an explicit
  allowlist.
- The container is destroyed after the run.
- The output (commit diff, test results) is exported via a
  controlled mechanism (volume mount marked read-only from the
  host, or `docker cp`).

This pattern is appropriate when running fleets of agents in
parallel (a common "agent harness" use case). It is NOT appropriate
for any work that runs on a developer machine.

---

## Choosing `--model`

| Task                          | Model                | Reasoning |
| ----------------------------- | -------------------- | --------- |
| Per-PR diff review            | `claude-sonnet-4-6`  | Fast; catches obvious issues. |
| Test-quality audit            | `claude-sonnet-4-6`  | Specific prompt; bounded scope. |
| Security review               | `claude-opus-4-7`    | Subprocess + path + secret patterns are subtle. |
| Phase completion audit        | `claude-opus-4-7`    | Reads everything; reasons across the whole phase. |
| Pre-setup gap analysis        | `claude-opus-4-7`    | Reads everything; surfaces what the human missed. |
| Quick "explain this" lookup   | `claude-haiku-4-5`   | Cheapest model for low-stakes lookups. |

These are starting points, not gospel. If a `claude-sonnet-4-6`
review misses something a `claude-opus-4-7` rerun would catch, escalate
and document the pattern in an ADR.

`--max-turns` recommendations:

| Task                          | max-turns |
| ----------------------------- | --------- |
| One-shot lookup               | 1-3       |
| Per-PR diff review            | 8         |
| Stage development (interactive)| no cap (interactive) |
| Phase completion              | 50        |
| Pre-setup gap analysis        | 30        |

---

## Choosing `--output-format`

- `text` — when piping to a human, or when the prompt requests
  prose markdown output (e.g. the pre-setup audit).
- `json` — when piping to a script for further processing (e.g.
  rendering review reports into PR comments).
- `stream-json` — when you want to consume the response as it's
  generated (long-running reviews, dashboards).

The JSON envelope from `--output-format json` includes
`total_cost_usd`, `duration_ms`, and `num_turns` — useful for
budgeting agent spend.

---

## Other vendors

The same discipline applies to non-Anthropic reviewers. For
illustrative cross-vendor parity:

| Claude Code flag                  | Codex CLI equivalent             | Gemini CLI equivalent      |
| --------------------------------- | -------------------------------- | -------------------------- |
| `--allowedTools "Read,Grep,Glob"` | (per-tool approval modes)        | (per-tool approval modes)  |
| `--max-turns`                     | `--max-iterations`               | `--max-steps`              |
| `--model`                         | `--model`                        | `--model`                  |
| `--output-format json`            | structured output mode           | structured output mode     |
| `--append-system-prompt`          | (read AGENTS.md)                 | (read GEMINI.md)           |
| `-p`                              | `codex exec`                     | `gemini -p`                |

The cross-vendor pattern: same `AGENTS.md`, different bridges. The
prompts in `docs/review-prompts/` are written to be vendor-neutral
where possible.

---

## References

- Claude Code headless mode:
  https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-headless
- Claude Code permissions:
  https://docs.anthropic.com/en/docs/claude-code/iam
- AGENTS.md spec: https://agents.md/
- Codex CLI: https://github.com/openai/codex
- Gemini CLI: https://github.com/google-gemini/gemini-cli
- The "AI agents reach for --no-verify more than humans" observation
  (pydevtools handbook):
  https://pydevtools.com/handbook/how-to/how-to-set-up-pre-commit-hooks-for-a-python-project/
