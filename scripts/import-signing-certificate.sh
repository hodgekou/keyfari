#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Makes the project's code signing certificate available to codesign on a build machine and
# prints the name of the identity to sign with. Prints "-" when there is no certificate,
# which makes scripts/bundle.sh sign ad hoc as before.
#
# Usage: identity="$(scripts/import-signing-certificate.sh)"
#
# Environment:
#   KEYFARI_SIGNING_P12       The certificate with its private key, as base64 of a .p12 file.
#   KEYFARI_SIGNING_PASSWORD  The password the .p12 file was exported with.
#
# The certificate goes into a keychain of its own that lasts for the build. Nothing of it
# is printed, and the decoded file is removed as soon as it is imported.
set -euo pipefail

if [ -z "${KEYFARI_SIGNING_P12:-}" ]; then
  echo "::warning::No KEYFARI_SIGNING_P12, so the app is signed ad hoc and asks for its permissions again after this update" >&2
  echo "-"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
keychain="$work/signing.keychain-db"
# The keychain only guards the certificate for the length of this build.
keychain_password="$(uuidgen)"

if ! printf '%s' "$KEYFARI_SIGNING_P12" | tr -d '[:space:]' | base64 --decode > "$work/certificate.p12" 2>/dev/null; then
  echo "::error::KEYFARI_SIGNING_P12 is not base64" >&2
  exit 1
fi

security create-keychain -p "$keychain_password" "$keychain" >/dev/null
security set-keychain-settings "$keychain" >/dev/null
security unlock-keychain -p "$keychain_password" "$keychain" >/dev/null
if ! security import "$work/certificate.p12" -k "$keychain" -P "${KEYFARI_SIGNING_PASSWORD:-}" -T /usr/bin/codesign >/dev/null 2>&1; then
  echo "::error::The certificate could not be imported. Check KEYFARI_SIGNING_PASSWORD." >&2
  exit 1
fi
# Lets codesign use the key without a prompt that nobody is there to answer.
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain" >/dev/null 2>&1

# The keychain has to outlive this script, so it is moved out of the directory that is removed.
kept="$HOME/Library/Keychains/keyfari-signing-$$.keychain-db"
mv "$keychain" "$kept"
security unlock-keychain -p "$keychain_password" "$kept" >/dev/null
# codesign looks for identities in the search list.
existing=()
while IFS= read -r line; do
  existing+=("$(printf '%s' "$line" | sed -e 's/^ *"//' -e 's/"$//')")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$kept" "${existing[@]}" >/dev/null

# A self-signed certificate is not a "valid" identity to the system, so every identity is listed.
identity="$(security find-identity -p codesigning "$kept" | sed -nE 's/^ *[0-9]+\) [0-9A-F]+ "(.*)".*$/\1/p' | head -n 1)"
if [ -z "$identity" ]; then
  echo "::error::The .p12 file holds no code signing identity" >&2
  exit 1
fi
echo "$identity"
