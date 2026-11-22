cask "keyfari" do
  version "0.3.0"
  sha256 "1939da3ba4513d59dbd8406dad1df0f38a637549eec979de8ccf842bb0ac02d8"

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
    macOS asks for them again after each update.
  EOS
end
