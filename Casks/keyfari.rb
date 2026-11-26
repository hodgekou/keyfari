cask "keyfari" do
  version "0.5.1"
  sha256 "a9f9835a40971d5de0109d7b9d9d4155494db5d06c9d3662f589378038c10e80"

  url "https://github.com/hodgekou/keyfari/releases/download/v#{version}/Keyfari-#{version}.dmg"
  name "Keyfari"
  desc "Keyboard-driven navigation with hint labels"
  homepage "https://github.com/hodgekou/keyfari"

  # Keyfari updates itself, so Homebrew leaves the installed version alone.
  auto_updates true
  depends_on macos: :sonoma

  app "Keyfari.app"

  zap trash: "~/Library/Preferences/app.keyfari.Keyfari.plist"

  caveats <<~EOS
    Keyfari is not signed with an Apple Developer ID. The first time you open it,
    macOS blocks it: go to System Settings > Privacy & Security and choose Open Anyway.

    It needs the Accessibility permission, and Screen Recording for text detection.
    When upgrading from 0.3.0 or earlier, macOS may ask for these permissions once more.
  EOS
end
