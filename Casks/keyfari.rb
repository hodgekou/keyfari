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

  # Keyfari is not signed with an Apple Developer ID, so Gatekeeper would block the first launch.
  # Homebrew has already checked the download against the sha256 above.
  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Keyfari.app"],
        writable_paths: ["Keyfari.app"],
        writable_base:  :appdir
  end

  zap trash: "~/Library/Preferences/app.keyfari.Keyfari.plist"

  caveats <<~EOS
    Keyfari needs the Accessibility permission, and Screen Recording for labels on text
    and icons that applications do not expose.
    When upgrading from 0.3.0 or earlier, macOS may ask for these permissions once more.
  EOS
end
