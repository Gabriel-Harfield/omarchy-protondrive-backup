#!/usr/bin/env bash
# Downloads one file or folder from an arbitrary Proton Drive path to a
# local folder (created if missing). Usage:
#   download-path.sh <cli-path> <remote-path> <local-folder>
set -uo pipefail

CLI="$1"
REMOTE_PATH="$2"
LOCAL_DIR="$3"
# Naive suffix split — wrong only for the rare node name containing a
# literal, backslash-escaped "/", where it would cut at the escape instead
# of the real path separator. Cosmetic only: it just affects the localPath
# echoed back in the result JSON, not the download itself.
NAME="${REMOTE_PATH##*/}"
# Hard ceiling on captured CLI output — a noisy or malfunctioning CLI
# shouldn't be able to force unbounded shell/QML memory use.
MAX_STATUS_BYTES=1048576

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

mkdir -p "$LOCAL_DIR"

OUT=$("$CLI" filesystem download -f rename -d rename "$REMOTE_PATH" "$LOCAL_DIR" 2>&1 | head -c "$MAX_STATUS_BYTES")
CODE=$?

if [ "$CODE" -eq 0 ]; then
  printf '{"ok":true,"message":"%s","localPath":"%s"}\n' \
    "$(json_escape "$OUT")" "$(json_escape "$LOCAL_DIR/$NAME")"
else
  printf '{"ok":false,"message":"%s","localPath":""}\n' "$(json_escape "$OUT")"
fi
