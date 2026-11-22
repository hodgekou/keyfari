// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import KeyfariCore
import Sparkle
import os

/// Keeps the app up to date.
///
/// With an update feed and a public key in `Info.plist`, Sparkle does the work: it reads the
/// feed once a day, shows what is new, downloads the update, checks its signature against the
/// public key, installs it and starts the new version. A build without the key cannot verify
/// an update, so it does not look for one at all.
@MainActor
final class AppUpdater: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "update")
    private let store: SettingsStore
    /// How long to wait between two checks, in seconds.
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private var sparkle: SPUStandardUpdaterController?

    /// The version of this build as people see it, or a dash when it has none.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// Whether this build can install updates by itself.
    static var installsUpdates: Bool {
        func value(_ key: String) -> String {
            (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespaces)
        }
        return !value("SUPublicEDKey").isEmpty && !value("SUFeedURL").isEmpty
    }

    init(store: SettingsStore) {
        self.store = store
        super.init()
        if Self.installsUpdates {
            sparkle = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        }
    }

    // MARK: SPUStandardUserDriverDelegate

    /// A menu bar app has no window to put an update alert in front of, so a scheduled check
    /// could find an update without the user ever seeing it. Saying this is handled here stops
    /// Sparkle from warning about it; `standardUserDriverWillHandleShowingUpdate` does the handling.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Brings the update window to the front when a scheduled check found something.
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard handleShowingUpdate, !state.userInitiated else { return }
        NSApp.activate(ignoringOtherApps: true)
    }

    func start() {
        guard let sparkle else {
            log.notice("No update key in this build, so it does not look for updates")
            return
        }
        let updater = sparkle.updater
        // Set before the updater starts, so Sparkle never asks for a permission the settings already hold.
        updater.automaticallyChecksForUpdates = store.effective.updateCheckEnabled
        updater.updateCheckInterval = Self.checkInterval
        // The user sees what is new and decides; nothing is downloaded behind their back.
        updater.automaticallyDownloadsUpdates = false
        updater.sendsSystemProfile = false
        do {
            try updater.start()
        } catch {
            log.error("The updater could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Follows the setting that switches the daily check on and off.
    func settingsChanged() {
        sparkle?.updater.automaticallyChecksForUpdates = store.effective.updateCheckEnabled
    }

    /// The check the user asked for.
    func checkNow() {
        sparkle?.checkForUpdates(nil)
    }
}
