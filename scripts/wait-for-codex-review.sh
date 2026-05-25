#!/usr/bin/env bash
# wait-for-codex-review.sh
#
# Block until the @codex review bot has posted a review on a PR.
# Used by /goal during DORMANT state after CI green but before
# requesting merge — the dormancy contract requires the cross-vendor
# diff review actually happened.
#
# Token cost: ZERO while blocking.
#
# Default timeout is 1 hour (shorter than the 4h default for other
# waits — the bot is usually fast; if it's gone an hour the bot is
# likely down or rate-limited).
#
# Usage:
#   wait-for-codex-review.sh <pr-number> [options]
#
# Options:
#   --timeout <seconds>        Max wait (default 3600 = 1 hour)
#   --poll-interval <seconds>  Polling cadence (default 30)
#   --no-followup              Don't write a follow-up escalation on timeout
#   --bot <login>              Override bot login (default chatgpt-codex-connector)
#
# Exit codes:
#   0  Codex bot posted a review (any state: APPROVED, COMMENTED, REQUEST_CHANGES)
#   2  Timeout — follow-up escalation written
#   3  Usage error
#   4  PR not found

set -euo pipefail

PR=""
TIMEOUT=3600
POLL_INTERVAL=30
DO_FOLLOWUP=1
BOT="chatgpt-codex-connector"

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)        TIMEOUT="$2"; shift 2 ;;
    --poll-interval)  POLL_INTERVAL="$2"; shift 2 ;;
    --no-followup)    DO_FOLLOWUP=0; shift ;;
    --bot)            BOT="$2"; shift 2 ;;
    -h|--help)        sed -n '2,30p' "$0"; exit 0 ;;
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
  local f="$esc_dir/ESCALATION-${ts}-codex-review-timeout.md"
  cat > "$f" <<EOF
---
task_id: $(grep -E '^- \*\*current_task_id:\*\*' .planning/auto-execution/STATE.md 2>/dev/null | head -1 | awk '{print $NF}')
kind: task-failure
created: $(date -u +%FT%TZ)
---

# Codex review bot did not post on PR #${PR} within ${TIMEOUT}s

**Attempted:** wait-for-codex-review.sh ${PR}

**Observed:** no review from \`${BOT}\` on the PR within the timeout.

**Suggested resolution:** manually trigger via comment \`@codex review\` on the PR. If still no response in another hour, the bot may be down or rate-limited (HUMAN-GATE-6 → escalate to maintainer).

EOF
  log "follow-up escalation written: $f"
}

if ! gh pr view "$PR" --json number >/dev/null 2>&1; then
  log "PR #${PR} not found"; exit 4
fi

start_ts=$(date +%s)
log "watching PR #${PR} for review from ${BOT} (timeout=${TIMEOUT}s, poll=${POLL_INTERVAL}s)"

while true; do
  now=$(date +%s)
  if [ $((now - start_ts)) -ge "$TIMEOUT" ]; then
    log "timeout after ${TIMEOUT}s"
    write_followup
    exit 2
  fi

  posted=$(gh api "repos/{owner}/{repo}/pulls/${PR}/reviews" --jq "[.[] | select(.user.login == \"${BOT}\")] | length" 2>/dev/null || echo "0")

  if [ "$posted" -gt 0 ]; then
    log "${BOT} has posted ${posted} review(s)"
    exit 0
  fi

  log "no review from ${BOT} yet; sleeping ${POLL_INTERVAL}s"
  sleep "$POLL_INTERVAL"
done
