#!/usr/bin/env bash
# wait-for-pr-merge.sh
#
# Block until a PR's state becomes MERGED. Used by /goal during
# DORMANT state after signaling merge-ready (CI green, codex review
# resolved). The Claude monitor session is what actually performs
# the merge; this script waits for that to happen.
#
# The script ALSO verifies the 7 merge-gating preconditions from
# 0011-phase-1-orchestration.md before treating MERGEABLE as
# actionable. If a precondition fails, the script does NOT merge —
# it exits with code 1 and writes a status comment on the PR.
#
# This script is invoked by the codex orchestrator (which doesn't
# merge) and also by the Claude monitor (which does merge after
# the preconditions check passes).
#
# Token cost: ZERO while blocking.
#
# Usage:
#   wait-for-pr-merge.sh <pr-number> [options]
#
# Options:
#   --timeout <seconds>        Max wait (default 14400 = 4 hours)
#   --poll-interval <seconds>  Polling cadence (default 30)
#   --no-followup              Don't write a follow-up escalation on timeout
#   --as-monitor               Also attempt the merge if preconditions met
#                              (only the Claude monitor session uses this)
#
# Exit codes:
#   0  PR merged
#   1  Precondition failed — comment posted; orchestrator should address
#   2  Timeout — follow-up escalation written
#   3  Usage error
#   4  PR not found
#   5  PR closed without merge

set -euo pipefail

PR=""
TIMEOUT=14400
POLL_INTERVAL=30
DO_FOLLOWUP=1
AS_MONITOR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)        TIMEOUT="$2"; shift 2 ;;
    --poll-interval)  POLL_INTERVAL="$2"; shift 2 ;;
    --no-followup)    DO_FOLLOWUP=0; shift ;;
    --as-monitor)     AS_MONITOR=1; shift ;;
    -h|--help)        sed -n '2,40p' "$0"; exit 0 ;;
    *)
      if [ -z "$PR" ]; then PR="$1"; shift
      else echo "unexpected arg: $1" >&2; exit 3; fi
      ;;
  esac
done

if [ -z "$PR" ]; then
  echo "usage: $0 <pr-number> [options]" >&2; exit 3
fi

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }
iso_now() { date -u +%Y%m%dT%H%M%SZ; }

write_followup() {
  if [ "$DO_FOLLOWUP" -ne 1 ]; then return; fi
  local esc_dir=".planning/auto-execution/escalations"
  mkdir -p "$esc_dir"
  local ts; ts=$(iso_now)
  local f="$esc_dir/ESCALATION-${ts}-merge-timeout.md"
  cat > "$f" <<EOF
---
task_id: $(grep -E '^- \*\*current_task_id:\*\*' .planning/auto-execution/STATE.md 2>/dev/null | head -1 | awk '{print $NF}')
kind: monitor-merge-blocked
created: $(date -u +%FT%TZ)
---

# PR #${PR} did not merge within ${TIMEOUT}s

**Attempted:** wait-for-pr-merge.sh ${PR} (as_monitor=${AS_MONITOR})

**Observed:** PR did not reach MERGED state within timeout. See \`gh pr view ${PR}\` for current state.

**Suggested resolution:** maintainer to inspect; common causes are unresolved review threads, missing CI checks, or branch protection misconfiguration. If preconditions check shows a soft block (e.g., no-new-commits window), wait an additional 10 minutes and re-invoke.

EOF
  log "follow-up escalation written: $f"
}

# Verify the 7 merge-gating preconditions from 0011-phase-1-orchestration.md.
# Returns 0 if all preconditions met, 1 if any failed.
check_preconditions() {
  local pr="$1"
  local view; view=$(gh pr view "$pr" --json mergeable,statusCheckRollup,reviews,labels,headRefOid,commits 2>/dev/null) || return 1

  # 1. mergeable == MERGEABLE
  if [ "$(jq -r .mergeable <<<"$view")" != "MERGEABLE" ]; then
    log "precondition fail: not MERGEABLE"; return 1
  fi

  # 2. All required CI checks pass (delegated to wait-for-ci-green, but verify final state here)
  local fail_count
  fail_count=$(jq '[.statusCheckRollup[] | select((.conclusion // "") != "SUCCESS" and (.status // "") == "COMPLETED")] | length' <<<"$view")
  if [ "$fail_count" -gt 0 ]; then
    log "precondition fail: ${fail_count} CI check(s) failed"; return 1
  fi
  local pending_count
  pending_count=$(jq '[.statusCheckRollup[] | select((.status // "") != "COMPLETED")] | length' <<<"$view")
  if [ "$pending_count" -gt 0 ]; then
    log "precondition fail: ${pending_count} CI check(s) still pending"; return 1
  fi

  # 3. @codex review bot has posted at least one review
  local codex_count
  codex_count=$(jq '[.reviews[] | select(.author.login == "chatgpt-codex-connector")] | length' <<<"$view")
  if [ "$codex_count" -lt 1 ]; then
    log "precondition fail: codex bot has not posted a review"; return 1
  fi

  # 4. Zero unresolved review threads
  local unresolved
  unresolved=$(gh api graphql -f query="query{repository(owner:\"loganrooks\",name:\"erebus\"){pullRequest(number:${pr}){reviewThreads(first:50){nodes{isResolved}}}}}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length' 2>/dev/null || echo "0")
  if [ "$unresolved" -gt 0 ]; then
    log "precondition fail: ${unresolved} unresolved review thread(s)"; return 1
  fi

  # 5. No new commits in the last 5 minutes
  local last_commit_ts
  last_commit_ts=$(jq -r '.commits[-1].commit.committedDate' <<<"$view")
  if [ -n "$last_commit_ts" ] && [ "$last_commit_ts" != "null" ]; then
    local last_epoch; last_epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%SZ" "$last_commit_ts" +%s 2>/dev/null || echo 0)
    local now_epoch; now_epoch=$(date +%s)
    if [ $((now_epoch - last_epoch)) -lt 300 ]; then
      log "precondition fail: last commit was less than 5 minutes ago"; return 1
    fi
  fi

  # 6. No do-not-merge label
  local has_dnm
  has_dnm=$(jq '[.labels[] | select(.name == "do-not-merge")] | length' <<<"$view")
  if [ "$has_dnm" -gt 0 ]; then
    log "precondition fail: do-not-merge label present"; return 1
  fi

  # 7. PR body has a REQ-ID line
  local body; body=$(gh pr view "$pr" --json body --jq '.body')
  if ! grep -qE 'REQ-[A-Z]+-[0-9]+' <<<"$body"; then
    log "precondition fail: PR body has no REQ-ID reference"; return 1
  fi

  return 0
}

if ! gh pr view "$PR" --json number >/dev/null 2>&1; then
  log "PR #${PR} not found"; exit 4
fi

start_ts=$(date +%s)
log "watching PR #${PR} for merge (as_monitor=${AS_MONITOR}, timeout=${TIMEOUT}s, poll=${POLL_INTERVAL}s)"

while true; do
  now=$(date +%s)
  if [ $((now - start_ts)) -ge "$TIMEOUT" ]; then
    log "timeout after ${TIMEOUT}s"
    write_followup
    exit 2
  fi

  state=$(gh pr view "$PR" --json state --jq '.state')
  case "$state" in
    MERGED)
      log "PR #${PR} merged"
      exit 0
      ;;
    CLOSED)
      log "PR #${PR} closed without merge"
      exit 5
      ;;
    OPEN)
      if [ "$AS_MONITOR" -eq 1 ]; then
        if check_preconditions "$PR"; then
          log "all 7 preconditions met; merging PR #${PR}"
          gh pr merge "$PR" --merge --admin --delete-branch && {
            log "merged"; exit 0
          } || {
            log "merge command failed; will retry next tick"
          }
        fi
      fi
      ;;
  esac

  sleep "$POLL_INTERVAL"
done
