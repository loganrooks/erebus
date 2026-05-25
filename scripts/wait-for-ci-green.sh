#!/usr/bin/env bash
# wait-for-ci-green.sh
#
# Block until all required CI checks on a PR reach a terminal state.
# Used by /goal during DORMANT state after pushing to a PR branch.
#
# Token cost: ZERO while blocking. Foreground bash invocation; no
# model inference happens until this script returns.
#
# Required checks (from REPO_SETUP.md §4 / branch-protection contexts):
#   lint-and-type
#   test-unit-meta (ubuntu-latest)
#   test-unit-meta (macos-latest)
#   test-integration
#   gitleaks
#   docs-consistency
#   review-artifact-exists
#
# Usage:
#   wait-for-ci-green.sh <pr-number> [options]
#
# Options:
#   --timeout <seconds>        Max wait (default 14400 = 4 hours)
#   --poll-interval <seconds>  Polling cadence (default 30)
#   --no-followup              Don't write a follow-up escalation on timeout
#   --required <names>         Override the required-checks list (comma-separated)
#
# Exit codes:
#   0  All required checks passed
#   1  One or more required checks failed (terminal)
#   2  Timeout — follow-up escalation written
#   3  Usage error
#   4  PR not found or not accessible

set -euo pipefail

# ---------- defaults ----------
PR=""
TIMEOUT=14400
POLL_INTERVAL=30
DO_FOLLOWUP=1
REQUIRED="lint-and-type,test-unit-meta (ubuntu-latest),test-unit-meta (macos-latest),test-integration,gitleaks,docs-consistency,review-artifact-exists"

# ---------- parse args ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)        TIMEOUT="$2"; shift 2 ;;
    --poll-interval)  POLL_INTERVAL="$2"; shift 2 ;;
    --no-followup)    DO_FOLLOWUP=0; shift ;;
    --required)       REQUIRED="$2"; shift 2 ;;
    -h|--help)        sed -n '2,30p' "$0"; exit 0 ;;
    *)
      if [ -z "$PR" ]; then
        PR="$1"; shift
      else
        echo "unexpected arg: $1" >&2; exit 3
      fi
      ;;
  esac
done

if [ -z "$PR" ]; then
  echo "usage: $0 <pr-number> [options]" >&2; exit 3
fi

# ---------- helpers ----------
log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }

iso_now() { date -u +%Y%m%dT%H%M%SZ; }

# Returns 0=pass, 1=fail, 2=pending for a given check name on the PR.
check_status() {
  local name="$1"
  local rollup="$2"
  printf '%s' "$rollup" | jq -r --arg n "$name" '
    .[] | select(.name == $n) |
    if (.conclusion // "") == "SUCCESS" then "pass"
    elif (.status // "") == "COMPLETED" then "fail"
    else "pending"
    end
  ' | head -1
}

write_followup() {
  if [ "$DO_FOLLOWUP" -ne 1 ]; then return; fi
  local esc_dir=".planning/auto-execution/escalations"
  mkdir -p "$esc_dir"
  local ts; ts=$(iso_now)
  local f="$esc_dir/ESCALATION-${ts}-ci-timeout.md"
  cat > "$f" <<EOF
---
task_id: $(grep -E '^- \*\*current_task_id:\*\*' .planning/auto-execution/STATE.md 2>/dev/null | head -1 | awk '{print $NF}')
kind: task-failure
created: $(date -u +%FT%TZ)
---

# CI wait timed out on PR #${PR}

**Attempted:** wait-for-ci-green.sh ${PR} (timeout=${TIMEOUT}s)

**Observed:** at least one required check did not reach a terminal state within the timeout. Run \`gh pr checks ${PR}\` to inspect.

**Suggested resolution:** investigate the hung check (likely runner unavailability, GitHub Actions outage, or a stalled test). Maintainer signal: re-run via \`gh pr checks ${PR} --watch\` or push an empty commit to retrigger.

EOF
  log "follow-up escalation written: $f"
}

# ---------- preflight ----------
if ! gh pr view "$PR" --json number >/dev/null 2>&1; then
  log "PR #${PR} not found or not accessible"; exit 4
fi

IFS=',' read -ra REQUIRED_ARR <<< "$REQUIRED"

# ---------- loop ----------
start_ts=$(date +%s)
log "watching PR #${PR} for CI green (timeout=${TIMEOUT}s, poll=${POLL_INTERVAL}s)"

while true; do
  now=$(date +%s)
  if [ $((now - start_ts)) -ge "$TIMEOUT" ]; then
    log "timeout after ${TIMEOUT}s"
    write_followup
    exit 2
  fi

  rollup=$(gh pr view "$PR" --json statusCheckRollup --jq '.statusCheckRollup' 2>/dev/null || echo "[]")

  all_pass=1
  any_fail=0
  pending_count=0
  for name in "${REQUIRED_ARR[@]}"; do
    status=$(check_status "$name" "$rollup")
    case "$status" in
      pass) ;;
      fail) any_fail=1; all_pass=0 ;;
      *) pending_count=$((pending_count + 1)); all_pass=0 ;;
    esac
  done

  if [ "$any_fail" -eq 1 ]; then
    log "one or more required checks failed"
    gh pr checks "$PR" >&2 || true
    exit 1
  fi

  if [ "$all_pass" -eq 1 ]; then
    log "all required checks passed"
    exit 0
  fi

  log "${pending_count}/${#REQUIRED_ARR[@]} required checks still pending; sleeping ${POLL_INTERVAL}s"
  sleep "$POLL_INTERVAL"
done
