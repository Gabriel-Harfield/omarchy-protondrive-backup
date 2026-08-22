#!/usr/bin/env bash
# Prints "folder" or "file" for a local path. Used right after
# omarchy-file-select returns a path: the underlying desktop file chooser
# doesn't reliably distinguish the two when invoked without --directory (in
# practice, many portal implementations let you select a folder without
# entering it even in plain "open file" mode), so the picker alone can't
# tell the caller which kind was picked.
# Usage: stat-kind.sh <local-path>
set -uo pipefail

if [ -d "$1" ]; then
  printf 'folder'
else
  printf 'file'
fi
