// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import KeyfariCore

/// What the modes share when they reach into windows that do not have the keyboard focus.
@MainActor
enum BackgroundWindows {
    /// How long a window that was brought forward needs before it takes a click.
    static let settleDelay: Duration = .milliseconds(150)
    /// The most background windows read in one activation, counted from the front.
    static let limit = 12

    /// The application an element of the frontmost application's query belongs to. Most belong
    /// to the frontmost application itself; the Dock's icons are the Dock's.
    static func owner(of element: ElementSnapshot, frontmost bundleID: String) -> String {
        element.source == .dock ? "com.apple.dock" : bundleID
    }

    /// Applications whose windows are never read: this one, and the ones the user ignores.
    static func excludedPIDs(ignoredBundleIDs: [String]) -> Set<pid_t> {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ignored = Set(ignoredBundleIDs)
        return Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.processIdentifier == ownPID || ignored.contains($0.bundleIdentifier ?? "") }
                .map(\.processIdentifier)
        )
    }

    /// Brings `window` and its application to the front and waits until it listens.
    ///
    /// A click on a window in the background only brings it forward in most applications,
    /// so it comes forward first, like it would under a real pointer.
    static func bringForward(_ window: BackgroundWindow) async {
        await Task.detached { window.raise() }.value
        NSRunningApplication(processIdentifier: window.pid)?.activate()
        try? await Task.sleep(for: settleDelay)
    }
}
