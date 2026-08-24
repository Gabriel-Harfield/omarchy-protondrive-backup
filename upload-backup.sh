#!/usr/bin/env bash
# Uploads a local file OR folder to Proton Drive's /my-files/Backups and
# renames it to a caller-supplied, already-timestamped name.
#
# The CLI's upload command always keeps the local basename and has no
# "upload as this name" option, so reaching the final timestamped name
# takes more than one step.
#
# Never uses -f/-d replace against a real destination. A HANCORE marketplace
# review (2026-08-24, commit 0f5b950) correctly flagged that Proton CLI
# 0.8.0's `replace` conflict strategy trashes whatever conflicting item is
# already sitting at that basename, even if it has nothing to do with this
# plugin (a manually-uploaded file with the same name, or a stray leftover
# from an interrupted run) — and it did so before the plugin's own explicit
# "an existing backup has this name, trash it?" confirmation flow ever runs.
#
# Fix: upload into a fresh, plugin-owned staging subfolder (guaranteed empty
# — its name is randomised per run — so no conflict strategy is ever
# load-bearing there), then move the uploaded item into Backups and rename
# it to the final name using CLI calls that take no conflict-strategy flag
# at all and fail loud (non-zero exit / ok:false) rather than silently
# destroying anything if a same-name item is already there. On that failure
# the staging copy is trashed (the plugin's own transient scratch item, not
# anything pre-existing) and the caller sees an explicit error instead of a
# silent deletion.
# Usage: upload-backup.sh <cli-path> <local-path> <remote-name>
set -uo pipefail

CLI="$1"
LOCAL="$2"
REMOTE_NAME="$3"
REMOTE_DIR="/my-files/Backups"
BASENAME="$(basename -- "$LOCAL")"
# Hard ceiling on captured CLI output — a noisy or malfunctioning CLI
# shouldn't be able to force unbounded shell/QML memory use.
MAX_STATUS_BYTES=1048576
STAGING_NAME=".upload-staging-$$-$(date +%s%N)"
STAGING_DIR="$REMOTE_DIR/$STAGING_NAME"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

fail() {
  printf '{"ok":false,"message":"%s"}\n' "$(json_escape "$1")"
  exit 0
}

cleanup_staging() {
  "$CLI" filesystem trash "$STAGING_DIR" >/dev/null 2>&1
}

"$CLI" filesystem create-folder /my-files Backups >/dev/null 2>&1

CREATE_OUT=$("$CLI" filesystem create-folder "$REMOTE_DIR" "$STAGING_NAME" 2>&1 | head -c "$MAX_STATUS_BYTES")
CREATE_CODE=$?
if [ "$CREATE_CODE" -ne 0 ]; then
  fail "could not create staging folder: $CREATE_OUT"
fi

# -f/-d skip here is defence in depth only: STAGING_DIR was just created
# under a randomised name, so a real conflict inside it should never
# actually happen. --json so a same-content auto-skip (the CLI silently
# skips uploads whose content already matches) is distinguishable from a
# genuine transfer instead of trusting exit code alone, which is 0 either way.
UPLOAD_OUT=$("$CLI" filesystem upload --json -f skip -d skip "$LOCAL" "$STAGING_DIR" 2>&1 | head -c "$MAX_STATUS_BYTES")
UPLOAD_CODE=$?
TRANSFERRED=$(printf '%s' "$UPLOAD_OUT" | jq -r '.transferredItems // 0' 2>/dev/null)
if [ "$UPLOAD_CODE" -ne 0 ] || [ "${TRANSFERRED:-0}" -lt 1 ]; then
  cleanup_staging
  fail "upload failed: $UPLOAD_OUT"
fi

# Move takes no conflict-strategy flag: on a name collision at the
# destination it reports ok:false and leaves both copies untouched, never
# a silent overwrite. --json to read that per-item ok flag reliably.
MOVE_OUT=$("$CLI" filesystem move --json "$STAGING_DIR/$BASENAME" "$REMOTE_DIR" 2>&1 | head -c "$MAX_STATUS_BYTES")
MOVE_OK=$(printf '%s' "$MOVE_OUT" | jq -r 'if type=="array" then (.[0].ok // false) else (.ok // false) end' 2>/dev/null)
if [ "$MOVE_OK" != "true" ]; then
  cleanup_staging
  fail "uploaded but a same-name item already exists in Backups, move aborted: $MOVE_OUT"
fi

# Rename likewise takes no conflict-strategy flag and fails (non-zero exit,
# nothing renamed) rather than clobbering if REMOTE_NAME is somehow already
# taken. In normal use it never is: the caller's own UI already offered to
# trash any same-name existing backup before this script ever ran.
RENAME_OUT=$("$CLI" filesystem rename "$REMOTE_DIR/$BASENAME" "$REMOTE_NAME" 2>&1 | head -c "$MAX_STATUS_BYTES")
RENAME_CODE=$?
cleanup_staging
if [ "$RENAME_CODE" -ne 0 ]; then
  printf '{"ok":false,"message":"uploaded but rename failed: %s"}\n' "$(json_escape "$RENAME_OUT")"
  exit 0
fi

printf '{"ok":true,"message":"%s"}\n' "$(json_escape "$REMOTE_NAME")"
