// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Foundation

public enum SpaceDirection: Sendable, Hashable, CaseIterable {
    case previous
    case next
}

/// The shortcut macOS itself uses to move one Space left or right.
///
/// Keyfari changes Spaces by pressing that shortcut, so it has to know which keys the user gave it
/// and whether it is switched on. Both are stored under `AppleSymbolicHotKeys` in the
/// `com.apple.symbolichotkeys` preferences.
public enum SystemSpaceShortcut {
    /// The key of the entry in `AppleSymbolicHotKeys`.
    public static func symbolicHotKeyID(for direction: SpaceDirection) -> String {
        switch direction {
        case .previous: "79"
        case .next: "81"
        }
    }

    /// What the system uses until the user changes it: Control with an arrow key.
    public static func standard(for direction: SpaceDirection) -> Shortcut {
        Shortcut(keyCode: direction == .previous ? KeyCode.leftArrow : KeyCode.rightArrow, modifiers: .control)
    }

    /// The shortcut in force, or nil when the user switched it off.
    /// - Parameter entry: the stored value for this direction, or nil when nothing is stored.
    public static func resolve(entry: [String: Any]?, direction: SpaceDirection) -> Shortcut? {
        // The system writes an entry only once the user touches the setting.
        guard let entry else { return standard(for: direction) }
        if let enabled = entry["enabled"] as? NSNumber, !enabled.boolValue { return nil }

        // Parameters are the character, the virtual key code and the modifier flags.
        guard let value = entry["value"] as? [String: Any],
            let parameters = value["parameters"] as? [NSNumber],
            parameters.count >= 3
        else { return standard(for: direction) }

        let keyCode = parameters[1].intValue
        // 65535 stands for "no key".
        guard (0..<0xFFFF).contains(keyCode) else { return nil }
        let flags = parameters[2].intValue
        var modifiers: Modifiers = []
        if flags & (1 << 17) != 0 { modifiers.insert(.shift) }
        if flags & (1 << 18) != 0 { modifiers.insert(.control) }
        if flags & (1 << 19) != 0 { modifiers.insert(.option) }
        if flags & (1 << 20) != 0 { modifiers.insert(.command) }
        return Shortcut(keyCode: UInt16(keyCode), modifiers: modifiers)
    }
}

/// Geometry of the Spaces actions. Everything uses accessibility coordinates.
public enum SpaceGeometry {
    /// Where the pointer has to be so that the system changes the Space of the display that
    /// holds the focused window, or nil when it is there already.
    ///
    /// When displays have separate Spaces the system acts on the display under the pointer,
    /// which need not be the one the user is typing on.
    public static func pointerTarget(
        pointer: CGPoint,
        focusedWindowFrame: CGRect?,
        displays: [CGRect],
        displaysHaveSeparateSpaces: Bool
    ) -> CGPoint? {
        guard displaysHaveSeparateSpaces, displays.count > 1, let focusedWindowFrame,
            let wanted = ScreenGeometry.indexOfScreen(containing: focusedWindowFrame, screenFrames: displays)
        else { return nil }
        if displays[wanted].contains(pointer) { return nil }
        let visible = displays[wanted].intersection(focusedWindowFrame)
        return CGPoint(x: visible.midX, y: visible.midY)
    }
}
