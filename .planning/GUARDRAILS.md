# Guardrails

The cross-cutting rules an autonomous executor must obey during
Phase-1. These override individual task specs in conflict.

This file is scoped to **orchestration discipline** — the rules
that exist because /goal is running autonomously. General dev
discipline (anchor-first TDD, builder-only ffmpeg, no raw
subprocess, NOTES.md journaling, commit-message format) lives in
[`AGENTS.md`](../AGENTS.md) and is not duplicated here. Both
files are in force; AGENTS.md is the broader contract.

## Hard rules (NEVER violate)

1. **Never push to main directly.** Every change goes through a
   PR. Branch protection enforces this; the rule still appears
   here so any bypass is intentional.

2. **Never force-push.** Tags excepted (e.g., if a future
   `v0.1` floating tag is introduced, force-update is allowed
   per a future ADR). Branches are append-only.

3. **Never bypass CI.** PRs cannot be merged unless their CI
   is green. No `--no-verify`, no `--no-gpg-sign`, no other
   hook-bypass flags. Inherited from AGENTS.md; restated here
   because /goal could otherwise rationalize a bypass to "make
   progress".

4. **Never merge from the orchestrator session.** Codex /goal
   opens PRs; the Claude monitor session merges them. The
   role asymmetry is the cross-vendor hedge. If /goal believes
   a PR is merge-ready, it signals via task postcondition
   (write a status comment on the PR, then invoke
   `wait-for-pr-merge.sh`). The monitor reads the signal and
   merges.

5. **Never skip a checkpoint.** Each phase ends with a
   `checkpoints/CHECKPOINT-PN.md` file before the next phase
   starts. The checkpoint is what makes phase boundaries
   recoverable.

6. **Never invent state.** STATE.md is the single source of
   truth. If reality contradicts STATE (e.g., STATE says PR
   #N is open, `gh pr view N` returns merged), escalate with
   `kind: state-mismatch`. Do not edit STATE to match reality
   silently.

7. **Never silently fall back.** If a task can't complete as
   specified, retry per the retry policy → escalate. No "make
   it work somehow" or quietly removing a postcondition.

8. **Never expand scope mid-phase.** If something useful
   surfaces, log it as a future-work item in NOTES.md but do
   not implement during the current phase. Scope expansions
   require an escalation with `kind: scope-expansion-request`.

9. **Never skip postcondition verification.** Even if a task
   "feels done," verify postconditions explicitly. Mechanical
   postconditions are how phase completion is auditable.

10. **Never commit secrets.** No API keys, OAuth tokens, PATs,
    `.env` files, etc., in any committed file. Use repo
    secrets only. `gitleaks` runs in pre-commit and CI; this
    rule is the policy that those checks enforce.

11. **Never modify SETUP / archive ADRs / past audit
    artifacts.** Files under `docs/decisions/archive/`,
    `docs/decisions/reviews/`, and the merged content of past
    PRs are immutable historical records. Corrections happen
    in new ADRs that supersede.

## Dormancy contract (load-bearing)

12. **When STATE.md flips to `AWAITING_EXTERNAL` or
    `AWAITING_HUMAN`, the same turn must end with a
    `wait-for-X.sh` invocation in foreground.** This is the
    F-007 systemic fix; see
    [`EXECUTION-MODEL.md` §"Dormancy contract"](EXECUTION-MODEL.md).
    Without it, codex's continuation hook burns tokens
    polling. With it, zero tokens are consumed while waiting.

13. **During DORMANT state (escalation written, wait script
    running), do not do "ready" work.** The pause is the
    contract; parallel work creates shadow-replacement
    collisions with the supervisor.

14. **On wait-script return, verify the resolution scope
    matches the task that triggered the wait.** A `RESOLVED:`
    line that names a different task means the wait should
    not exit; write a clarification escalation instead.

## Soft rules (escalate if unclear)

1. **Prefer minimal diffs** scoped to one stage per PR. One
   PR per anchor test landed.
2. **Prefer reusing existing patterns** in `erebus/ffmpeg/builder.py`
   over inventing new ones.
3. **Prefer pinned action SHAs** to floating tags in
   `.github/workflows/`.
4. **Prefer named scripts** to inline shell when logic exceeds
   ~5 lines.
5. **Prefer the dormancy contract** for any wait exceeding 60
   seconds. Below 60s, a simple `sleep` in the same turn is
   fine (no token waste worth the script overhead).
6. **Prefer escalation over guessing** when a task spec is
   ambiguous.
7. **Prefer the `@codex review` bot's findings** as a first
   filter on PR quality, but do not treat the bot as
   load-bearing — its absence is an `AWAITING_EXTERNAL`
   state, not a free pass.

## Forbidden behaviors

- Running `pytest`, `pip install`, `uv pip install` against
  unverified inputs (per REQ-SEC-001, builder-only is required
  for subprocess; pip-style installs of arbitrary packages
  outside the locked `uv.lock` are not allowed).
- Reading or exfiltrating `~/.ssh/`, `~/.aws/`,
  `/proc/self/environ`, `.env` files, host credential stores.
- Using `--no-verify`, `--no-gpg-sign`, or other hook-bypass
  flags.
- Modifying repo settings (branch protection, secrets,
  auto-merge config). Those are HUMAN-GATEs.
- Calling `gh pr merge` directly. Only the monitor session
  may merge, and only via `scripts/wait-for-pr-merge.sh`
  preconditions.
- Deleting tracked files outside the orchestrator's own
  task scope (e.g., archive ADRs, past reviews).
- Using `git commit --amend` on commits that have been
  pushed to a PR branch. Amend before push only.
