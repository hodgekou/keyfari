// SPDX-License-Identifier: GPL-3.0-only

import AppKit

/// A short message near the bottom of the screen that goes away by itself.
/// Used when an action could not be carried out and nothing else on screen would say why.
@MainActor
public enum Toast {
    private static var panel: NSPanel?
    private static var dismissal: Task<Void, Never>?

    public static func show(_ message: String, for duration: Duration = .seconds(4)) {
        dismissal?.cancel()
        panel?.orderOut(nil)

        // The screen with the keyboard focus, where the user is looking.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let maxWidth = min(560, screen.visibleFrame.width - 80)

        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.preferredMaxLayoutWidth = maxWidth - 36
        let textSize = label.sizeThatFits(NSSize(width: maxWidth - 36, height: .greatestFiniteMagnitude))
        let size = NSSize(width: ceil(textSize.width) + 36, height: ceil(textSize.height) + 22)

        let frame = NSRect(
            x: (screen.visibleFrame.midX - size.width / 2).rounded(),
            y: screen.visibleFrame.minY + 90,
            width: size.width,
            height: size.height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(srgbRed: 0.09, green: 0.10, blue: 0.14, alpha: 0.94).cgColor
        content.layer?.cornerRadius = min(size.height / 2, 16)
        label.frame = NSRect(x: 18, y: 11, width: size.width - 36, height: ceil(textSize.height))
        content.addSubview(label)
        panel.contentView = content
        panel.orderFrontRegardless()
        self.panel = panel

        dismissal = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
            if self.panel === panel { self.panel = nil }
        }
    }
}
