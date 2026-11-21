// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import ScreenVision

@MainActor
enum ScreenRecordingAccess {
    /// Requests access once the app is otherwise ready to use.
    /// If the user has already denied it, macOS does not show the prompt again;
    /// the settings pane remains available through the explicit request button.
    static func requestIfNeeded() {
        guard !ScreenTextDetector.hasPermission else { return }
        ScreenTextDetector.requestPermission()
    }

    /// Asks for the permission and opens the place where it is granted.
    ///
    /// The system shows its own prompt only the first time an application asks. Every later
    /// request is ignored silently, so the settings pane is opened as well.
    static func request() {
        ScreenTextDetector.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Starts a fresh copy of the app and quits this one. A newly granted permission
    /// only takes effect in a new process.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}
