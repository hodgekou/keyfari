// SPDX-License-Identifier: GPL-3.0-only

import AppKit

@MainActor
enum SoundFeedback {
    private static var sounds: [String: NSSound] = [:]

    static func success() {
        play("Success")
    }

    static func warning() {
        play("Warning")
    }

    static func warningIfEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return }
        warning()
    }

    private static func play(_ name: String) {
        if let sound = sounds[name] {
            sound.stop()
            sound.currentTime = 0
            sound.play()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds"),
            let sound = NSSound(contentsOf: url, byReference: false)
        else { return }
        sounds[name] = sound
        sound.play()
    }
}
