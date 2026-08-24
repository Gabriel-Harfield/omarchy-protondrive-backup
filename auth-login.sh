#!/usr/bin/env bash
# Runs `<cli> auth login` with the same ceiling pattern the other scripts
# apply to CLI output (upload-to.sh, list-backups.sh, ...), plus a wall-clock
# deadline. This call used to be made directly from QML via Process +
# StdioCollector, with no cap on either axis — a stalled or malfunctioning
# CLI could hold the shared shell open indefinitely and grow stdout/stderr
# without bound. auth login legitimately opens a browser and waits on the
# user to finish signing in there, which can take a couple of minutes, so
# the deadline below is set generously above that: it's a backstop against
# a hang, not a UX timeout.
# Usage: auth-login.sh <cli-path>
set -uo pipefail

CLI="$1"
MAX_OUTPUT_BYTES=1048576
DEADLINE_SECONDS=300

OUT=$(timeout "$DEADLINE_SECONDS" "$CLI" auth login 2>&1 | head -c "$MAX_OUTPUT_BYTES")
CODE=$?

if [ "$CODE" -eq 124 ]; then
  OUT="Login timed out after ${DEADLINE_SECONDS}s — try again"
fi

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

if [ "$CODE" -eq 0 ]; then
  printf '{"ok":true,"message":"%s"}\n' "$(json_escape "$OUT")"
else
  printf '{"ok":false,"message":"%s"}\n' "$(json_escape "$OUT")"
fi
