#!/usr/bin/env bash
# Downloads and installs the official Proton Drive CLI binary to
# ~/.local/bin/proton-drive (a path find-cli.sh already auto-detects).
# Reads Proton's own release manifest rather than hardcoding a version, so
# this keeps working as new CLI releases ship, and verifies the SHA-512
# checksum the manifest publishes before installing anything.
# Usage: install-cli.sh
set -uo pipefail

MANIFEST_URL="https://proton.me/download/drive/cli/version.json"
TARGET="$HOME/.local/bin/proton-drive"

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
  Linux) os="linux" ;;
  *) fail "Unsupported OS: $(uname -s) — this only installs the Linux build." ;;
esac

case "$(uname -m)" in
  x86_64) arch="x64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *) fail "Unsupported architecture: $(uname -m)" ;;
esac

platform="$os/$arch"

manifest=$(curl -fsSL --max-time 20 "$MANIFEST_URL") || fail "Could not reach $MANIFEST_URL"

entry=$(printf '%s' "$manifest" | jq -e --arg p "$platform" \
  '.Releases[] | select(.CategoryName == "Stable") | .Files[] | select(.Platform == $p)') \
  || fail "No Stable build found for platform $platform in Proton's manifest"

url=$(printf '%s' "$entry" | jq -r '.Url')
sha512=$(printf '%s' "$entry" | jq -r '.Sha512CheckSum')
version=$(printf '%s' "$manifest" | jq -r '.Releases[] | select(.CategoryName == "Stable") | .Version')

[ -n "$url" ] && [ "$url" != "null" ] || fail "Manifest entry had no download URL"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL --max-time 180 -o "$tmp" "$url" || fail "Download failed: $url"

got_sha=$(sha512sum "$tmp" | awk '{print $1}')
if [ "$got_sha" != "$sha512" ]; then
  fail "Checksum mismatch for $url — expected $sha512, got $got_sha. Refusing to install."
fi

mkdir -p "$(dirname "$TARGET")"
mv "$tmp" "$TARGET"
chmod +x "$TARGET"
trap - EXIT

printf '{"ok":true,"path":"%s","version":"%s"}\n' "$(json_escape "$TARGET")" "$(json_escape "$version")"
