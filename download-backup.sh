#!/usr/bin/env bash
# Downloads one backup (file or folder) from Proton Drive to a local folder
# (created if missing). Usage: download-backup.sh <cli-path> <name> <local-folder>
# name is a bare name under /my-files/Backups, not a full path.
set -uo pipefail

CLI="$1"
NAME="$2"
LOCAL_DIR="$3"
REMOTE_DIR="/my-files/Backups"
ESCAPED="${NAME//\//\\/}"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

mkdir -p "$LOCAL_DIR"

OUT=$("$CLI" filesystem download -f rename -d rename "$REMOTE_DIR/$ESCAPED" "$LOCAL_DIR" 2>&1)
CODE=$?

if [ "$CODE" -eq 0 ]; then
  printf '{"ok":true,"message":"%s","localPath":"%s"}\n' \
    "$(json_escape "$OUT")" "$(json_escape "$LOCAL_DIR/$NAME")"
else
  printf '{"ok":false,"message":"%s","localPath":""}\n' "$(json_escape "$OUT")"
fi
