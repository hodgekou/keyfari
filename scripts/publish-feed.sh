#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Points the Homebrew cask and the update feed at a released disk image.
#
# Usage: scripts/publish-feed.sh <version> <path to Keyfari-<version>.dmg>
#
# Environment:
#   SPARKLE_PRIVATE_KEY  The private half of the update key, as exported by Sparkle's
#                        generate_keys. Without it only the cask is updated.
#
# Changes Casks/keyfari.rb and site/appcast.xml in the working tree; committing is left
# to the caller. The key is never written to disk or printed.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <version> <path to the disk image>" >&2
  exit 64
fi
version="$1"
image="$2"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: $version is not a version of the form 1.2.3" >&2
  exit 64
fi
if [ ! -f "$image" ]; then
  echo "error: $image is not a file" >&2
  exit 66
fi

cd "$(dirname "$0")/.."

sha="$(shasum -a 256 "$image" | cut -d ' ' -f 1)"
sed -i '' -E "s/^  version \".*\"/  version \"$version\"/; s/^  sha256 \".*\"/  sha256 \"$sha\"/" Casks/keyfari.rb
echo "Pointed the cask at $version"

# A key pasted with a line break or a space at the end is still the same key.
key="$(printf '%s' "${SPARKLE_PRIVATE_KEY:-}" | tr -d '[:space:]')"
if [ -z "$key" ]; then
  echo "::warning::No SPARKLE_PRIVATE_KEY, so $version is not added to the update feed"
  exit 0
fi

# Say what is wrong with the key without showing any of it.
size="$(printf '%s' "$key" | python3 -c '
import base64, sys
try:
    print(len(base64.b64decode(sys.stdin.read(), validate=True)))
except Exception:
    print(-1)')"
case "$size" in
  32 | 64 | 96) ;;
  -1)
    echo "::error::SPARKLE_PRIVATE_KEY is not base64 (${#key} characters). It must be the contents of the file generate_keys -x writes."
    exit 1
    ;;
  *)
    echo "::error::SPARKLE_PRIVATE_KEY decodes to $size bytes; an exported key has 32, 64 or 96."
    exit 1
    ;;
esac

tool=".build/artifacts/sparkle/Sparkle/bin/sign_update"
if [ ! -x "$tool" ]; then
  echo "error: $tool is missing; run swift package resolve first" >&2
  exit 66
fi
# The tool prints its errors, key included, on standard output, so its output is only
# used when it succeeded and is never shown otherwise.
if ! signature="$(printf '%s\n' "$key" | "$tool" --ed-key-file - -p "$image" 2>/dev/null)"; then
  echo "::error::sign_update could not sign with SPARKLE_PRIVATE_KEY"
  exit 1
fi

# A signature made with another key than the one the app trusts would make every
# installed copy reject the update.
public_key="$(/usr/bin/sed -n '/SUPublicEDKey/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' Resources/Info.plist)"
if ! swift scripts/verify-update-signature.swift "$image" "$signature" "$public_key"; then
  echo "::error::The signature does not match SUPublicEDKey in Resources/Info.plist. SPARKLE_PRIVATE_KEY is not the private half of that key."
  exit 1
fi

scripts/update-appcast.py "$version" "$image" "$signature"
