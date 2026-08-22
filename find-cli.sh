#!/usr/bin/env bash
# Best-effort discovery of the proton-drive CLI binary. Prints the first
# match found, or nothing if none is found.
set -uo pipefail

CANDIDATES=(
  "$(command -v proton-drive 2>/dev/null || true)"
  "$HOME/.local/bin/proton-drive"
  "$HOME/Downloads/proton-drive"
  "$HOME/Applications/proton-drive"
)

for candidate in "${CANDIDATES[@]}"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s' "$candidate"
    exit 0
  fi
done

exit 1
