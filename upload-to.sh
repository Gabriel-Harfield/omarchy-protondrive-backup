#!/usr/bin/env bash
# Uploads a local file or folder to an arbitrary Proton Drive folder,
# keeping its original name — no timestamp, no rename. This is the Browse
# tab's plain "upload here", distinct from the Backup tab's dated-copy
# flow (upload-backup.sh). Conflict strategy is "rename" (never silently
# replace or merge existing content at a destination the user picked ad
# hoc, unlike the Backup tab's own dedicated, always-empty-slot folder).
# Usage: upload-to.sh <cli-path> <local-path> <remote-parent-path>
set -uo pipefail

CLI="$1"
LOCAL="$2"
REMOTE_PARENT="$3"
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

OUT=$("$CLI" filesystem upload -f rename -d rename "$LOCAL" "$REMOTE_PARENT" 2>&1 | head -c "$MAX_STATUS_BYTES")
CODE=$?

if [ "$CODE" -eq 0 ]; then
  printf '{"ok":true,"message":"%s"}\n' "$(json_escape "$OUT")"
else
  printf '{"ok":false,"message":"%s"}\n' "$(json_escape "$OUT")"
fi
