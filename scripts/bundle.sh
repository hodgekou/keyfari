#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Builds the package and assembles Keyfari.app.
#
# Usage: scripts/bundle.sh [debug|release]
#
# Environment:
#   KEYFARI_SIGN_IDENTITY  Code signing identity. Defaults to "-" (ad hoc). An ad hoc signature
#                          changes on every build, so macOS asks for the permissions again;
#                          a stable identity from the keychain avoids that.
#   KEYFARI_VERSION        Version written into the bundle, for example 0.2.0. Defaults to the
#                          one in Resources/Info.plist.
#   KEYFARI_UNIVERSAL      Set to 1 to build for both Apple silicon and Intel.
#   KEYFARI_OUTPUT         Directory that receives Keyfari.app. Defaults to build/.
set -euo pipefail

configuration="${1:-debug}"
case "$configuration" in
  debug | release) ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
identity="${KEYFARI_SIGN_IDENTITY:--}"
output="${KEYFARI_OUTPUT:-$root/build}"
app="$output/Keyfari.app"

build_flags=(-c "$configuration")
if [ "${KEYFARI_UNIVERSAL:-0}" = "1" ]; then
  build_flags+=(--arch arm64 --arch x86_64)
fi

cd "$root"
swift build "${build_flags[@]}" --product Keyfari
binary="$(swift build "${build_flags[@]}" --show-bin-path)/Keyfari"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Keyfari"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
# Regenerate the icon with scripts/make-icon.swift and iconutil.
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp -R "$root/Resources/Sounds" "$app/Contents/Resources/Sounds"

# Sparkle, which installs updates, is a prebuilt framework that the package manager downloads.
sparkle="$root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "$sparkle" ]; then
  echo "Sparkle.framework is missing at $sparkle" >&2
  exit 66
fi
mkdir -p "$app/Contents/Frameworks"
# ditto keeps the symbolic links a framework is made of.
ditto "$sparkle" "$app/Contents/Frameworks/Sparkle.framework"
# The binary looks for the framework next to the build products; in the bundle it is here.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/Keyfari"

if [ -n "${KEYFARI_VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $KEYFARI_VERSION" "$app/Contents/Info.plist"
  # Sparkle compares this one to tell a newer version from an older one.
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $KEYFARI_VERSION" "$app/Contents/Info.plist"
fi

# Signed from the inside out: the helpers inside the framework, the framework, then the app.
framework="$app/Contents/Frameworks/Sparkle.framework"
for helper in \
  "$framework/Versions/B/XPCServices/Installer.xpc" \
  "$framework/Versions/B/XPCServices/Downloader.xpc" \
  "$framework/Versions/B/Autoupdate" \
  "$framework/Versions/B/Updater.app"; do
  codesign --force --sign "$identity" "$helper"
done
codesign --force --sign "$identity" "$framework"
codesign --force --sign "$identity" --identifier app.keyfari.Keyfari "$app"

echo "Built $app"
