#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copies Casks/keyfari.rb to the Homebrew tap, so `brew install --cask hodgekou/keyfari/keyfari`
# installs the release the cask in this repository points at.
#
# Usage: scripts/sync-tap.sh
#
# Environment:
#   HOMEBREW_TAP_TOKEN  A token that may write to the tap repository. Without it nothing is done.
#                       It is handed to gh through the environment and never printed.
set -euo pipefail

cd "$(dirname "$0")/.."
tap="hodgekou/homebrew-keyfari"
path="Casks/keyfari.rb"

if [ -z "${HOMEBREW_TAP_TOKEN:-}" ]; then
  echo "::warning::No HOMEBREW_TAP_TOKEN, so $tap is not updated. Copy $path there by hand."
  exit 0
fi
export GH_TOKEN="$HOMEBREW_TAP_TOKEN"

version="$(sed -nE 's/^  version "([0-9.]+)"$/\1/p' "$path")"
if [ -z "$version" ]; then
  echo "error: $path names no version" >&2
  exit 65
fi

# The file's current state in the tap: its identifier, needed to replace it, and its content.
current="$(gh api "repos/$tap/contents/$path" --jq '.sha' 2>/dev/null || true)"
if [ -n "$current" ] && [ "$(gh api "repos/$tap/contents/$path" --jq '.content' | base64 --decode)" = "$(cat "$path")" ]; then
  echo "The tap already has the cask for $version"
  exit 0
fi

arguments=(--method PUT "repos/$tap/contents/$path" -f "message=Update Keyfari to $version" -f "content=$(base64 < "$path" | tr -d '\n')")
if [ -n "$current" ]; then
  arguments+=(-f "sha=$current")
fi
gh api "${arguments[@]}" --jq '.commit.sha' >/dev/null
echo "Updated the cask in $tap to $version"
