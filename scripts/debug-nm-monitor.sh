#!/usr/bin/env bash
# Debug monitor: poll no-mistakes step timing and log to Cursor debug session.
# Usage: bash scripts/debug-nm-monitor.sh [run_id]
set -euo pipefail

LOG_PATH="/Users/sylvesterlim/CodingFun/optimizeWrkFlow/.cursor/debug-ffd42e.log"
SESSION_ID="ffd42e"
RUN_ID="${1:-}"
POLL_SECS="${POLL_SECS:-15}"

dbg_log() {
  local hypothesis_id="$1"
  local location="$2"
  local message="$3"
  local data_json="$4"
  # #region agent log
  printf '{"sessionId":"%s","hypothesisId":"%s","location":"%s","message":"%s","data":%s,"timestamp":%s}\n' \
    "$SESSION_ID" "$hypothesis_id" "$location" "$message" "$data_json" "$(date +%s000)" >>"$LOG_PATH"
  # #endregion
}

if [ -z "$RUN_ID" ]; then
  RUN_ID="$(no-mistakes axi status 2>/dev/null | sed -n 's/^  id: "\(.*\)"/\1/p' | head -1 || true)"
fi

dbg_log "H0" "debug-nm-monitor.sh:start" "monitor started" "{\"runId\":\"${RUN_ID:-unknown}\",\"pollSecs\":$POLL_SECS}"

prev_review_status=""
prev_test_status=""
review_log_lines=0

while true; do
  status_out="$(no-mistakes axi status 2>/dev/null || true)"
  review_status="$(printf '%s\n' "$status_out" | awk '/review,/{print $2}')"
  review_ms="$(printf '%s\n' "$status_out" | awk '/review,/{print $4}')"
  test_status="$(printf '%s\n' "$status_out" | awk '/test,/{print $2}')"
  test_ms="$(printf '%s\n' "$status_out" | awk '/test,/{print $4}')"
  findings="$(printf '%s\n' "$status_out" | sed -n 's/^  findings: //p' | head -1)"

  if [ -n "$RUN_ID" ] && [ -f "$HOME/.no-mistakes/logs/$RUN_ID/review.log" ]; then
    cur_lines="$(wc -l <"$HOME/.no-mistakes/logs/$RUN_ID/review.log" | tr -d ' ')"
  else
    cur_lines=0
  fi

  dbg_log "H1" "debug-nm-monitor.sh:poll" "step snapshot" \
    "{\"reviewStatus\":\"$review_status\",\"reviewMs\":$review_ms,\"testStatus\":\"$test_status\",\"testMs\":$test_ms,\"findings\":\"$findings\",\"reviewLogLines\":$cur_lines}"

  # H2: fix-round thrash — review log grows while status stays fixing
  if [ "$review_status" = "fixing" ] && [ "$cur_lines" -gt "$review_log_lines" ]; then
    delta=$((cur_lines - review_log_lines))
    dbg_log "H2" "debug-nm-monitor.sh:thrash" "review log grew during fixing" \
      "{\"deltaLines\":$delta,\"totalLines\":$cur_lines}"
  fi

  # H3: re-review loop — review completes then returns to running/fixing
  if [ -n "$prev_review_status" ] && [ "$prev_review_status" = "completed" ] && [ "$review_status" != "completed" ]; then
    dbg_log "H3" "debug-nm-monitor.sh:loop" "review left completed state" \
      "{\"from\":\"$prev_review_status\",\"to\":\"$review_status\"}"
  fi

  # H4: test uses agent fallback
  if [ "$test_status" = "running" ] && [ -n "$RUN_ID" ]; then
    first_test_line="$(head -1 "$HOME/.no-mistakes/logs/$RUN_ID/test.log" 2>/dev/null || true)"
    if printf '%s' "$first_test_line" | grep -q "no test command configured"; then
      dbg_log "H4" "debug-nm-monitor.sh:test" "agent test fallback detected" \
        "{\"firstLine\":\"no test command configured\"}"
    fi
  fi

  review_log_lines=$cur_lines
  prev_review_status="$review_status"
  prev_test_status="$test_status"

  if printf '%s\n' "$status_out" | grep -q "outcome:"; then
    dbg_log "H0" "debug-nm-monitor.sh:end" "run terminal outcome seen" "{}"
    break
  fi
  if [ "$review_status" = "completed" ] && [ "$test_status" = "completed" ] && [ "$prev_test_status" = "completed" ]; then
    : # keep polling for document/lint
  fi

  sleep "$POLL_SECS"
done
