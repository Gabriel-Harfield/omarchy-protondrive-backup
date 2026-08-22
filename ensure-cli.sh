#!/usr/bin/env bash
# Ensures a specific, pre-tested version of the Proton Drive CLI is present
# at this plugin's OWN dedicated path — never the system/AUR copy, never
# "whatever proton.me/download/drive/cli/version.json currently calls
# Stable". The version, URL and checksum below are pinned deliberately: bump
# them by hand, only after testing the new release against this plugin, and
# never automatically. That is the whole point — this plugin's behavior
# should never change just because the CLI updated out from under it (e.g.
# via `omarchy update` touching an AUR package, which this plugin does not
# use for exactly that reason).
#
# Prints one JSON object on stdout:
#   {"ok":true,"path":"...","version":"0.8.0","fresh":true|false}
#   {"ok":false,"message":"..."}
# fresh:true means a real download just happened; fresh:false means the
# pinned binary was already in place and its SHA-512 matched.
set -uo pipefail

PINNED_VERSION="0.8.0"
TARGET_DIR="$HOME/.local/share/omarchy-protondrive-backup/bin"
TARGET="$TARGET_DIR/proton-drive"
# Comfortably above the real ~118MB binary; a hard ceiling so a compromised
# or misbehaving response can't exhaust disk space before the checksum
# check below ever gets to run.
MAX_DOWNLOAD_BYTES=209715200

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
  exit 1
}

case "$(uname -s)" in
  Linux) ;;
  *) fail "Unsupported OS: $(uname -s) — this plugin only supports Linux." ;;
esac

case "$(uname -m)" in
  x86_64)
    URL="https://proton.me/download/drive/cli/0.8.0/linux-x64/proton-drive"
    SHA512="cf61c2688c45e1055d8add6221d9471a5a5b64bf3bcdb86460f5cb18414596cc4df3cdb6627c9097c94bec32a3c9915ada3211ef2ae5be33c46ebbc996ccaa28"
    ;;
  aarch64 | arm64)
    URL="https://proton.me/download/drive/cli/0.8.0/linux-arm64/proton-drive"
    SHA512="27a1aec1d2095fd4a1a81e1d47cd1f9fd4901bd579ffe50342d15e2e52078d6e8b2dddcf58a4a386438dc7562017778be26c1ba62399f901ae82c7430e2140a3"
    ;;
  *) fail "Unsupported architecture: $(uname -m)" ;;
esac

# Already in place with the right bytes? Nothing to do. A self-reported
# `--version` string is not proof of anything — it's exactly as easy to
# forge as the string itself, so trusting one instead of the checksum would
# mean any user-writable replacement at this path that prints the expected
# version gets executed with Proton Drive access. Only a byte-for-byte
# SHA-512 match short-circuits the download below; hashing the ~118MB
# binary costs well under a second, so there's no real tradeoff for
# skipping it.
if [ -x "$TARGET" ]; then
  CURRENT_SHA=$(sha512sum "$TARGET" 2>/dev/null | awk '{print $1}')
  if [ "$CURRENT_SHA" = "$SHA512" ]; then
    printf '{"ok":true,"path":"%s","version":"%s","fresh":false}\n' "$(json_escape "$TARGET")" "$PINNED_VERSION"
    exit 0
  fi
fi

mkdir -p "$TARGET_DIR"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL --max-time 180 --max-filesize "$MAX_DOWNLOAD_BYTES" -o "$tmp" "$URL" || fail "Download failed: $URL"

got_sha=$(sha512sum "$tmp" | awk '{print $1}')
if [ "$got_sha" != "$SHA512" ]; then
  fail "Checksum mismatch for the pinned Proton Drive CLI $PINNED_VERSION — expected $SHA512, got $got_sha. Refusing to install."
fi

mv "$tmp" "$TARGET"
chmod +x "$TARGET"
trap - EXIT

printf '{"ok":true,"path":"%s","version":"%s","fresh":true}\n' "$(json_escape "$TARGET")" "$PINNED_VERSION"
