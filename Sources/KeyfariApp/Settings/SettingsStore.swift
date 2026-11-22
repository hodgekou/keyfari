// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KeyfariCore
import Observation
import ServiceManagement
import os

/// Loads and saves the user's settings, and applies the ones that live outside the app.
@MainActor
@Observable
final class SettingsStore {
    private static let key = "settings"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "settings")
    let usageStats: UsageStatsStore
    let labelMemory: LabelMemory

    /// Called after the settings changed.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    /// Called after the setting for the daily update check changed.
    @ObservationIgnored var onUpdateCheckChange: (@MainActor () -> Void)?

    /// Called after the setting that shows or hides the menu bar icon changed.
    @ObservationIgnored var onMenuBarIconChange: (@MainActor () -> Void)?

    /// The values as edited, which may be temporarily invalid while the user types.
    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            save()
            if settings.launchAtLogin != oldValue.launchAtLogin {
                applyLaunchAtLogin()
            }
            applyLanguage()
            if settings.showMenuBarIcon != oldValue.showMenuBarIcon {
                onMenuBarIconChange?()
            }
            if settings.updateCheckEnabled != oldValue.updateCheckEnabled {
                onUpdateCheckChange?()
            }
            onChange?()
        }
    }

    /// The values the app acts on.
    var effective: Settings { settings.validated() }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        usageStats = UsageStatsStore(defaults: defaults)
        labelMemory = LabelMemory(defaults: defaults)
        if let data = defaults.data(forKey: Self.key),
            let stored = try? JSONDecoder().decode(Settings.self, from: data)
        {
            settings = stored.validated()
        } else {
            settings = Settings()
        }
        applyLanguage()
    }

    /// Makes the chosen language the one `tr` translates into.
    private func applyLanguage() {
        L10n.language = settings.language.resolved(preferredLanguages: Locale.preferredLanguages)
    }

    func toggleIgnored(bundleID: String) {
        if let index = settings.ignoredBundleIDs.firstIndex(of: bundleID) {
            settings.ignoredBundleIDs.remove(at: index)
        } else {
            settings.ignoredBundleIDs.append(bundleID)
        }
    }

    func recordAction(bundleID: String, clicks: Int, isNewAction: Bool) {
        guard effective.usageStatisticsEnabled else { return }
        usageStats.record(bundleID: bundleID, clicks: clicks, isNewAction: isNewAction)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    private func applyLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Could not change launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }
}
