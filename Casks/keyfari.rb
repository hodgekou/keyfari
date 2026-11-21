cask "keyfari" do
  version "0.1.0"
  sha256 "2c877a53af2d3850076b8a75848f893419268f10bed303ddbee3bd978e674f84"

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
