#!/usr/bin/env bash
# Moves one or more backups to the Proton Drive trash (reversible — not a
# permanent delete). Usage: delete-backups.sh <cli-path> <name1> [name2...]
# Names are bare filenames under /my-files/Backups, not full paths.
set -uo pipefail

CLI="$1"
shift
REMOTE_DIR="/my-files/Backups"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

FAILED=()
for name in "$@"; do
  ESCAPED="${name//\//\\/}"
  if ! OUT=$("$CLI" filesystem trash "$REMOTE_DIR/$ESCAPED" 2>&1); then
    FAILED+=("$(json_escape "$name"): $(json_escape "$OUT")")
  fi
done

if [ "${#FAILED[@]}" -eq 0 ]; then
  printf '{"ok":true,"failed":[]}\n'
else
  printf '{"ok":false,"failed":['
  for i in "${!FAILED[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '"%s"' "${FAILED[$i]}"
  done
  printf ']}\n'
fi
