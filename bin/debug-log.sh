#!/usr/bin/env bash
# Debug instrumentation for npm install lifecycle (session 17c5b8).
_debug_log() {
  local hypothesis_id="$1" location="$2" message="$3" data="$4"
  local log_path="${WFW_DEBUG_LOG:-/Users/sylvesterlim/CodingFun/optimizeWrkFlow/.cursor/debug-17c5b8.log}"
  local ts
  ts="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s000)"
  printf '{"sessionId":"17c5b8","hypothesisId":"%s","location":"%s","message":"%s","data":%s,"timestamp":%s,"runId":"%s"}\n' \
    "$hypothesis_id" "$location" "$message" "$data" "$ts" "${WFW_DEBUG_RUN_ID:-pre-fix}" >>"$log_path"
}
