#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

fail() { echo "Keyfari: $*" >&2; exit 1; }

install_keyfari() {
  [[ "$(uname -s)" == Darwin ]] || fail "This installer requires macOS."
  local os_version version checksum release_url
  os_version="$(sw_vers -productVersion)"
  (( ${os_version%%.*} >= 14 )) || fail "Keyfari requires macOS 14 or later."

  app=/Applications/Keyfari.app
  stage=/Applications/.keyfari-install
  mkdir -m 700 "$stage" || fail "Check write access to /Applications and whether another installation is in progress."
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM

  echo "Checking the latest Keyfari release…"
  curl -fsSL https://raw.githubusercontent.com/hodgekou/keyfari/main/Casks/keyfari.rb -o "$stage/cask"
  version="$(sed -nE 's/^  version "([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p' "$stage/cask")"
  checksum="$(sed -nE 's/^  sha256 "([0-9a-f]{64})"$/\1/p' "$stage/cask")"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail "Invalid release metadata."
  release_url="https://github.com/hodgekou/keyfari/releases/download/v$version/Keyfari-$version.dmg"
  echo "Downloading Keyfari ${version}..."
  curl -fLsS "$release_url" -o "$stage/release.dmg"
  (cd "$stage" && printf '%s  release.dmg\n' "$checksum" | shasum -a 256 -c -)

  mkdir "$stage/volume"
  hdiutil attach "$stage/release.dmg" -readonly -nobrowse -mountpoint "$stage/volume" </dev/null
  ditto "$stage/volume/Keyfari.app" "$stage/Keyfari.app"
  codesign --verify --deep --strict "$stage/Keyfari.app"
  xattr -dr com.apple.quarantine "$stage/Keyfari.app"

  if [[ -e "$app" || -L "$app" ]]; then
    [[ ! -L "$app" && "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == app.keyfari.Keyfari ]] || fail "An unexpected item already exists at $app."
    if pgrep -x Keyfari >/dev/null; then
      fail "Quit Keyfari, then run this command again to update."
    fi
    mv "$app" "$stage/previous.app"
  fi
  mv "$stage/Keyfari.app" "$app"
  open "$app"
}

cleanup() {
  if [[ -e "$stage/previous.app" && ! -e "$app" ]]; then
    mv "$stage/previous.app" "$app" || return 1
  fi
  if [[ -d "$stage/volume" && "$(stat -f %d "$stage/volume")" != "$(stat -f %d "$stage")" ]]; then
    hdiutil detach "$stage/volume" || return 1
  fi
  rm -rf "$stage"
}

# Run only after bash has received the complete installer when piped from curl.
install_keyfari
