#!/usr/bin/env bash
# Uploads a local file OR folder to Proton Drive's /my-files/Backups and
# renames it to a caller-supplied, already-timestamped name. Two steps
# because the CLI's upload command always keeps the local basename;
# -f replace / -d replace guarantee a deterministic post-upload path (any
# stray leftover from a previous run that crashed between upload and rename
# gets replaced, not left to collide) — replace applies to whichever kind is
# actually being uploaded, the other flag is simply unused.
# Usage: upload-backup.sh <cli-path> <local-path> <remote-name>
set -uo pipefail

CLI="$1"
LOCAL="$2"
REMOTE_NAME="$3"
REMOTE_DIR="/my-files/Backups"
BASENAME="$(basename -- "$LOCAL")"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

"$CLI" filesystem create-folder /my-files Backups >/dev/null 2>&1

UPLOAD_OUT=$("$CLI" filesystem upload -f replace -d replace "$LOCAL" "$REMOTE_DIR" 2>&1)
UPLOAD_CODE=$?
if [ "$UPLOAD_CODE" -ne 0 ]; then
  printf '{"ok":false,"message":"%s"}\n' "$(json_escape "$UPLOAD_OUT")"
  exit 0
fi

RENAME_OUT=$("$CLI" filesystem rename "$REMOTE_DIR/$BASENAME" "$REMOTE_NAME" 2>&1)
RENAME_CODE=$?
if [ "$RENAME_CODE" -ne 0 ]; then
  printf '{"ok":false,"message":"uploaded but rename failed: %s"}\n' "$(json_escape "$RENAME_OUT")"
  exit 0
fi

printf '{"ok":true,"message":"%s"}\n' "$(json_escape "$REMOTE_NAME")"
