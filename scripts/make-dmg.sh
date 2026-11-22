#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Packs Keyfari.app into a disk image with a shortcut to the Applications folder.
#
# Usage: scripts/make-dmg.sh <path to Keyfari.app> <output.dmg>
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <path to Keyfari.app> <output.dmg>" >&2
  exit 64
fi

app="$1"
dmg="$2"
if [ ! -d "$app" ]; then
  echo "$app is not an application bundle" >&2
  exit 66
fi

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# ditto keeps the code signature and extended attributes intact.
ditto "$app" "$staging/Keyfari.app"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
if diskutil image create from --help >/dev/null 2>&1; then
  # Newer systems deprecate `hdiutil create`, and there it fails outright.
  diskutil image create from --format UDZO --volumeName "Keyfari" "$staging" "$dmg" >/dev/null
else
  # hdiutil sometimes reports "Resource busy" while the system is still indexing the files
  # it is about to copy, so a failed attempt is repeated a few times.
  attempt=1
  until hdiutil create -volname "Keyfari" -srcfolder "$staging" -format UDZO -ov "$dmg" >/dev/null 2>&1; do
    if [ "$attempt" -ge 5 ]; then
      echo "hdiutil could not create $dmg after $attempt attempts" >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
fi

echo "Created $dmg"
shasum -a 256 "$dmg"
