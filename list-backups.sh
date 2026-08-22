#!/usr/bin/env bash
# Lists every backup (file or folder) under Proton Drive's /my-files/Backups,
# as a JSON array of {name, type, size, modified (epoch ms)} sorted
# newest-first. type is "file" or "folder" — folders have no totalStorageSize
# in the CLI's own output, so size comes back 0 for them. Creates the Backups
# folder first if it doesn't exist yet (idempotent — a "name already exists"
# error from create-folder just means it's already there).
# Usage: list-backups.sh <cli-path>
set -uo pipefail

CLI="$1"
REMOTE_DIR="/my-files/Backups"

"$CLI" filesystem create-folder /my-files Backups >/dev/null 2>&1

RAW=$("$CLI" filesystem list -j "$REMOTE_DIR" 2>/dev/null)
if [ -z "$RAW" ]; then
  printf '[]'
  exit 0
fi

printf '%s' "$RAW" | jq -c '
  [ .[] | {
      name: .name.value,
      type: .type,
      size: (.totalStorageSize // 0),
      modified: (.modificationTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 * 1000)
    } ]
  | sort_by(-.modified)
' 2>/dev/null || printf '[]'
