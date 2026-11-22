// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct DiagnosticsTests {
    func diagnostics(_ settings: Settings = Settings()) -> Diagnostics {
        Diagnostics(
            appVersion: "0.3.0", systemVersion: "15.1", architecture: "arm64",
            displays: [CGSize(width: 1470, height: 956), CGSize(width: 1920, height: 1080)],
            hasAccessibility: true, hasScreenRecording: false, installsUpdates: true, settings: settings
        )
    }

    @Test func unchangedSettingsAreReportedAsNone() {
        #expect(Diagnostics.changedSettings(Settings()).isEmpty)
        #expect(diagnostics().report.contains("Settings changed from their defaults: none"))
    }

    @Test func namesTheChangedSettings() {
        var settings = Settings()
        settings.chainClicks = true
        settings.scrollSpeed = 40
        settings.nextSpaceShortcut = Shortcut(keyCode: KeyCode.rightArrow, modifiers: [.control, .option])
        #expect(Diagnostics.changedSettings(settings) == ["chainClicks", "nextSpaceShortcut", "scrollSpeed"])
    }

    @Test func saysWhatABugReportNeeds() {
        let report = diagnostics().report
        #expect(report.contains("Keyfari 0.3.0"))
        #expect(report.contains("macOS 15.1, arm64"))
        #expect(report.contains("Displays: 2 (1470×956, 1920×1080)"))
        #expect(report.contains("Accessibility permission: granted"))
        #expect(report.contains("Screen Recording permission: not granted"))
    }

    @Test func leavesOutWhatTheSettingsHold() {
        var settings = Settings()
        settings.ignoredBundleIDs = ["com.example.private-app"]
        settings.hintAlphabet = "qwertyu"
        let report = diagnostics(settings).report
        #expect(report.contains("hintAlphabet"))
        #expect(report.contains("ignoredBundleIDs"))
        #expect(!report.contains("com.example.private-app"))
        #expect(!report.contains("qwertyu"))
    }
}
