// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import KeyfariCore

/// Marks the keyboard events this app posts, so its own event taps let them through.
enum SyntheticEvent {
    private static let marker: Int64 = 0x4B46_5249  // "KFRI"

    static func isOurs(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        event.post(tap: .cghidEventTap)
    }
}
