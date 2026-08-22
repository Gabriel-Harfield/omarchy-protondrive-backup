#!/usr/bin/env bash
# Lists the contents (files and folders) of an arbitrary Proton Drive path,
# as JSON: {"ok":bool,"message":string,"entries":[{name,type,size,modified}]}.
# Read-only — unlike list-backups.sh, this never creates anything. A listing
# failure (path doesn't exist, no access, etc.) comes back as ok:false with
# a message, so the caller can tell "empty folder" apart from "couldn't list
# this path". Entries are sorted folders-first, then alphabetically.
# Usage: list-path.sh <cli-path> <remote-path>
set -uo pipefail

CLI="$1"
REMOTE_PATH="$2"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="$(printf '%s' "$s" | tr '\n' '\036')"
  s="${s//$'\036'/\\n}"
  printf '%s' "$s"
}

RAW=$("$CLI" filesystem list -j "$REMOTE_PATH" 2>&1)
CODE=$?
if [ "$CODE" -ne 0 ]; then
  printf '{"ok":false,"message":"%s","entries":[]}\n' "$(json_escape "$RAW")"
  exit 0
fi

ENTRIES=$(printf '%s' "$RAW" | jq -c '
  [ .[] | {
      name: .name.value,
      type: .type,
      size: (.totalStorageSize // 0),
      modified: (.modificationTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 * 1000)
    } ]
  | sort_by([(.type != "folder"), .name])
' 2>/dev/null)
if [ -z "$ENTRIES" ]; then ENTRIES="[]"; fi

printf '{"ok":true,"message":"","entries":%s}\n' "$ENTRIES"
