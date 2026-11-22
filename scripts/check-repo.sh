#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Checks the things about the repository that neither the compiler nor the tests see:
# licence headers, translations nobody uses, paths in the documentation that do not exist,
# and version numbers that disagree.
#
# Usage: scripts/check-repo.sh
set -euo pipefail

cd "$(dirname "$0")/.."
failures=0

fail() {
  echo "error: $*" >&2
  failures=$((failures + 1))
}

# Every source file and script carries the licence identifier in its first lines.
while IFS= read -r file; do
  if ! head -n 3 "$file" | grep -q "SPDX-License-Identifier: GPL-3.0-only"; then
    fail "$file has no SPDX licence identifier in its first three lines"
  fi
done < <(git ls-files 'Sources/*.swift' 'Tests/*.swift' 'scripts/*' Package.swift)

# Every script can be run directly.
while IFS= read -r file; do
  [ -x "$file" ] || fail "$file is not executable"
done < <(git ls-files 'scripts/*.sh')

# Every translated text is used somewhere. The English text is the key, so it appears
# as a string literal wherever it is shown.
table="Sources/KeyfariCore/Settings/Localization.swift"
while IFS= read -r key; do
  if ! grep -rqF --include='*.swift' --exclude="$(basename "$table")" -- "\"$key\"" Sources; then
    fail "translation \"$key\" in $table is not used"
  fi
done < <(sed -n '/static let table/,$p' "$table" | sed -nE 's/^ {8}"(([^"\\]|\\.)+)" *:.*$/\1/p')

# Paths named in the documentation exist.
for document in README.md CONTRIBUTING.md; do
  while IFS= read -r path; do
    [ -e "$path" ] || fail "$document mentions $path, which does not exist"
  done < <(
    # shellcheck disable=SC2016 # The backticks are the ones Markdown puts around code.
    grep -oE '`[^` ]+`' "$document" | tr -d '`' \
      | grep -E '^(Sources|Tests|Resources|scripts|docs|site|Casks|\.github)/[A-Za-z0-9_./-]+$|^[A-Z_]+\.md$|^\.swift-format$|^Package\.swift$' \
      | sort -u
  )
done

# The bundle's version is the newest one in the changelog.
plist_version="$(/usr/bin/sed -n '/CFBundleShortVersionString/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' Resources/Info.plist)"
changelog_version="$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -n 1)"
if [ "$plist_version" != "$changelog_version" ]; then
  fail "Resources/Info.plist says version $plist_version, but the newest version in CHANGELOG.md is $changelog_version"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures problem(s) found" >&2
  exit 1
fi
echo "Repository checks passed"
