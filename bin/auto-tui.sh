#!/usr/bin/env bash
# Animated terminal TUI for wfw auto. Reads .wfw/auto/status until outcome is set.
set -euo pipefail

AUTO_DIR="${1:-.wfw/auto}"
STATUS_FILE="$AUTO_DIR/status"
CONTEXT_FILE="$AUTO_DIR/context.md"

restore_cursor() {
  printf '\033[?25h'
  tput cnorm 2>/dev/null || true
}

trap restore_cursor EXIT INT TERM

hide_cursor() {
  printf '\033[?25l'
  tput civis 2>/dev/null || true
}

read_status_value() {
  local key="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    printf '%s\n' ""
    return 0
  fi
  awk -F= -v k="$key" '$1 == k { sub(/^[^=]+=/, ""); print; exit }' "$file"
}

mascot_spin() {
  local frame="$1"
  case "$frame" in
    0)
      cat <<'EOF'
   (\_/)
   ( o.o)  *
   / >o< \ ===
    ~~~~~  looping
EOF
      ;;
    1)
      cat <<'EOF'
   (\_/)
   ( -.-) *
   / >o< \==
    ~ ~ ~  looping
EOF
      ;;
    2)
      cat <<'EOF'
   (\_/)
   ( o.o)   *
   / >o< \  ===
    ~~~~~  looping
EOF
      ;;
    *)
      cat <<'EOF'
   (\_/)
   ( O.O)*
   / >o< \===
    ~.~.~  looping
EOF
      ;;
  esac
}

mascot_sleep() {
  cat <<'EOF'
   (\_/)
   ( -.-) z
   /  u  \
    .....  napping. objective verified.
EOF
}

mascot_fail() {
  cat <<'EOF'
   (\_/)
   ( x.x)
   /  ~  \
    .....  stopped. see context.md
EOF
}

spinner_char() {
  case "$1" in
    0) printf '%s' "|" ;;
    1) printf '%s' "/" ;;
    2) printf '%s' "-" ;;
    *) printf '%s' "\\" ;;
  esac
}

draw_frame() {
  local frame="$1"
  local outcome phase iter max last_tests message pulse
  outcome="$(read_status_value outcome "$STATUS_FILE")"
  phase="$(read_status_value phase "$STATUS_FILE")"
  iter="$(read_status_value iter "$STATUS_FILE")"
  max="$(read_status_value max "$STATUS_FILE")"
  last_tests="$(read_status_value last_tests "$STATUS_FILE")"
  message="$(read_status_value message "$STATUS_FILE")"
  pulse="$(spinner_char $((frame % 4)))"

  printf '\033[H\033[J'
  echo "wfw auto"
  echo ""
  case "$outcome" in
    success) mascot_sleep ;;
    failed) mascot_fail ;;
    *) mascot_spin $((frame % 4)) ;;
  esac
  echo ""
  echo "  ${pulse} still alive"
  echo "  iteration: ${iter:-?} / ${max:-?}"
  echo "  phase:     ${phase:-starting}"
  echo "  tests:     ${last_tests:-pending}"
  echo "  status:    ${message:-waiting}"
  echo ""
  echo "  recent context:"
  if [ -f "$CONTEXT_FILE" ]; then
    tail -n 5 "$CONTEXT_FILE" | sed 's/^/    /'
  else
    echo "    (none yet)"
  fi
}

hide_cursor
frame=0
while true; do
  draw_frame "$frame"
  outcome="$(read_status_value outcome "$STATUS_FILE")"
  if [ "$outcome" = "success" ] || [ "$outcome" = "failed" ]; then
    draw_frame "$frame"
    sleep 0.4
    exit 0
  fi
  frame=$((frame + 1))
  sleep 0.12
done
