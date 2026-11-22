#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Prints the release notes for one version: its section of CHANGELOG.md, then how to install.
#
# Usage: scripts/release-notes.sh <version>
set -euo pipefail

version="${1:?usage: $0 <version>}"
cd "$(dirname "$0")/.."

# The lines between this version's heading and the next one.
awk -v heading="## [$version]" '
  index($0, heading) == 1 { printing = 1; next }
  printing && /^## \[/ { exit }
  printing { print }
' CHANGELOG.md

cat <<NOTES

## Install

Download \`Keyfari-$version.dmg\`, open it and drag Keyfari to Applications.

Keyfari is not signed with an Apple Developer ID, so macOS blocks it the first time. Open it once, then go to **System Settings > Privacy & Security** and choose **Open Anyway**. After that, grant the Accessibility permission when asked. [First-launch screenshots](https://hodgekou.github.io/keyfari/#first-launch)

With Homebrew:

\`\`\`sh
brew install --cask hodgekou/keyfari/keyfari
\`\`\`
NOTES
