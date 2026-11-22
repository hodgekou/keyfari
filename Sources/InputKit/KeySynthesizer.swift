// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import KeyfariCore

/// Posts synthesized key presses. This app's own event taps let them through.
@MainActor
public enum KeySynthesizer {
    private static let arrowKeys: Set<UInt16> = [KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.downArrow, KeyCode.upArrow]

    /// Presses and releases one key with exactly these modifiers.
    public static func press(keyCode: UInt16, modifiers: Modifiers = []) {
        var flags: CGEventFlags = []
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        // A real arrow key carries these two flags, and the system's shortcuts only match with them.
        if arrowKeys.contains(keyCode) { flags.formUnion([.maskSecondaryFn, .maskNumericPad]) }

        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: isDown) else { continue }
            // Set explicitly: the user may still hold the modifiers of the shortcut that led here.
            event.flags = flags
            SyntheticEvent.post(event)
        }
    }

    public static func press(_ shortcut: Shortcut) {
        press(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }
}
