cask "keyfari" do
  version "0.1.1"
  sha256 "2f57e6b120d190dc82c112e5b5dafb5e7839a384e7a85957e81e7d8e78750892"

  url "https://github.com/hodgekou/keyfari/releases/download/v#{version}/Keyfari-#{version}.dmg"
  name "Keyfari"
  desc "Keyboard-driven navigation with hint labels"
  homepage "https://github.com/hodgekou/keyfari"

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
