// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import KeyfariCore
import Observation
import SwiftUI

/// Which shortcut field is recording, shared by all recorder buttons so only one records at a time.
///
/// Kept in an observable object rather than view state: the Command Line Tools ship without
/// the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class ShortcutRecording {
    static let shared = ShortcutRecording()

    private(set) var activeTitle: String?
    @ObservationIgnored private var monitor: Any?

    func start(title: String, onRecorded: @escaping @MainActor (Shortcut) -> Void) {
        stop()
        activeTitle = title
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode != KeyCode.escape else {
                self?.stop()
                return nil
            }
            var modifiers: Modifiers = []
            if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
            if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
            if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
            if event.modifierFlags.contains(.command) { modifiers.insert(.command) }

            let candidate = Shortcut(keyCode: event.keyCode, modifiers: modifiers)
            guard candidate.isUsable else {
                // A bare key or Shift-key would hijack ordinary typing.
                NSSound.beep()
                return nil
            }
            onRecorded(candidate)
            self?.stop()
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        activeTitle = nil
    }
}

/// A row that shows a shortcut as keycaps and records a new one when clicked.
struct ShortcutRecorder: View {
    let title: String
    let detail: String
    @Binding var shortcut: Shortcut?
    /// Whether the shortcut may be switched off.
    let isOptional: Bool
    let tint: Color

    init(title: String, detail: String, shortcut: Binding<Shortcut>, tint: Color) {
        self.title = title
        self.detail = detail
        _shortcut = Binding(
            get: { shortcut.wrappedValue },
            set: { if let value = $0 { shortcut.wrappedValue = value } }
        )
        isOptional = false
        self.tint = tint
    }

    /// A shortcut that can be off: it starts out empty and gets a button that clears it.
    init(title: String, detail: String, optional shortcut: Binding<Shortcut?>, tint: Color) {
        self.title = title
        self.detail = detail
        _shortcut = shortcut
        isOptional = true
        self.tint = tint
    }

    var body: some View {
        let recording = ShortcutRecording.shared
        let isRecording = recording.activeTitle == title
        SettingRow(title, detail: detail) {
            HStack(spacing: 6) {
                Button {
                    if isRecording {
                        recording.stop()
                    } else {
                        recording.start(title: title) { shortcut = $0 }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isRecording {
                            Image(systemName: "record.circle.fill").foregroundStyle(.red)
                            Text(tr("Press a shortcut…")).font(.system(size: 12, weight: .medium))
                        } else if let shortcut {
                            ForEach(Array(shortcut.displayParts.enumerated()), id: \.offset) { _, part in
                                Keycap(text: part, tint: tint)
                            }
                        } else {
                            Text(tr("Record shortcut")).font(.system(size: 12, weight: .medium)).foregroundStyle(tint)
                        }
                    }
                    .padding(.horizontal, isRecording || shortcut == nil ? 10 : 4)
                    .padding(.vertical, shortcut == nil ? 8 : 4)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isRecording ? Color.red.opacity(0.1) : tint.opacity(0.08))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tr("Click, then press the new shortcut. Esc cancels."))

                if isOptional, shortcut != nil, !isRecording {
                    Button {
                        shortcut = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(tr("Turn this shortcut off"))
                }
            }
        }
    }
}
