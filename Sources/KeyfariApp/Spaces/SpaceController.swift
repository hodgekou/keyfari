// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// What the system's own settings say about Spaces.
enum SystemSpaces {
    /// The shortcut the system uses to move one Space in `direction`, or nil when it is switched off.
    static func shortcut(for direction: SpaceDirection) -> Shortcut? {
        let hotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
        let entry = hotKeys?[SystemSpaceShortcut.symbolicHotKeyID(for: direction)] as? [String: Any]
        return SystemSpaceShortcut.resolve(entry: entry, direction: direction)
    }

    /// "Displays have separate Spaces" in the system's Desktop & Dock settings. On unless switched off.
    static var displaysHaveSeparateSpaces: Bool {
        UserDefaults(suiteName: "com.apple.spaces")?.bool(forKey: "spans-displays") != true
    }

    /// Bounds of the active displays, in accessibility coordinates.
    static var displayBounds: [CGRect] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }
}

/// Goes one Space to the left or right by pressing the system's own shortcut.
@MainActor
final class SpaceController {
    /// How long the pointer stays on the other display, so the system sees it there when the key arrives.
    private static let pointerDwell: Duration = .milliseconds(300)

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "spaces")
    private let store: SettingsStore
    private var isBusy = false

    init(store: SettingsStore) {
        self.store = store
    }

    func switchSpace(_ direction: SpaceDirection) {
        guard !isBusy else { return }
        guard let systemShortcut = SystemSpaces.shortcut(for: direction) else {
            log.notice("Not changing the Space: the system shortcut is off")
            SoundFeedback.warningIfEnabled(store.effective.warningSoundEnabled)
            Toast.show(
                tr("Turn on “Move left a space” and “Move right a space” in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.")
            )
            return
        }
        log.notice("Pressing \(systemShortcut.displayString, privacy: .public)")

        let displays = SystemSpaces.displayBounds
        // With one display, or one set of Spaces across all of them, there is nothing to choose.
        guard displays.count > 1, SystemSpaces.displaysHaveSeparateSpaces,
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else {
            KeySynthesizer.press(systemShortcut)
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            let frame = await Task.detached { AXElementQuery.focusedWindowFrame(pid: pid) }.value
            let pointer = CGEvent(source: nil)?.location
            let target = pointer.flatMap {
                SpaceGeometry.pointerTarget(pointer: $0, focusedWindowFrame: frame, displays: displays, displaysHaveSeparateSpaces: true)
            }
            guard let pointer, let target else {
                KeySynthesizer.press(systemShortcut)
                return
            }
            // The system changes the Space of the display under the pointer.
            MouseSynthesizer.move(to: target)
            KeySynthesizer.press(systemShortcut)
            try? await Task.sleep(for: Self.pointerDwell)
            CGWarpMouseCursorPosition(pointer)
        }
    }
}
