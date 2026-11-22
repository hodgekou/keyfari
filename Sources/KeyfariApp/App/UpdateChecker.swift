// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import KeyfariCore
import os

/// Asks GitHub once a day whether a newer version exists and, if so, asks the user what to do.
///
/// This is the only network request the app makes. It sends nothing about the user or the Mac,
/// downloads nothing, and can be switched off.
@MainActor
final class UpdateChecker {
    private static let lastCheckedKey = "updateLastChecked"
    /// How often the timer looks whether a check is due. The checks themselves are a day apart.
    private static let pollInterval: TimeInterval = 60 * 60
    /// How long after launch the first check waits, so it never delays startup.
    private static let launchDelay: TimeInterval = 20

    enum Outcome {
        case upToDate
        case available(ReleaseInfo)
        case failed
    }

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "update")
    private let store: SettingsStore
    private let defaults: UserDefaults
    private var timer: Timer?
    private var isChecking = false

    /// The running version, or nil in a build that has none, which is then never told to update.
    static var currentVersion: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
    }

    init(store: SettingsStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// Starts the daily checks. They only run while the setting is on.
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        Timer.scheduledTimer(withTimeInterval: Self.launchDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
    }

    private func checkIfDue() {
        guard store.effective.updateCheckEnabled,
            UpdateCheck.isDue(lastChecked: defaults.object(forKey: Self.lastCheckedKey) as? Date, now: .now)
        else { return }
        Task {
            guard case let .available(release) = await check() else { return }
            if UpdateCheck.shouldOffer(release, current: Self.currentVersion, skipped: store.effective.skippedVersion) {
                offer(release, allowsSkipping: true)
            }
        }
    }

    /// The check the user asked for: it always answers, and offers a version even if it was skipped.
    func checkNow() {
        Task {
            switch await check() {
            case let .available(release):
                if UpdateCheck.shouldOffer(release, current: Self.currentVersion, skipped: nil) {
                    offer(release, allowsSkipping: false)
                } else {
                    inform(tr("Keyfari is up to date."), detail: tr("Version %@ is the newest one.", Self.currentVersion?.description ?? "–"))
                }
            case .upToDate:
                inform(tr("Keyfari is up to date."), detail: tr("Version %@ is the newest one.", Self.currentVersion?.description ?? "–"))
            case .failed:
                inform(tr("Could not check for updates."), detail: tr("GitHub could not be reached. Try again later."))
            }
        }
    }

    private func check() async -> Outcome {
        guard !isChecking, let url = URL(string: UpdateCheck.latestReleaseURL) else { return .failed }
        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // Nothing that tells one Mac from another: no cookies, and a fixed client name.
        request.setValue("Keyfari", forHTTPHeaderField: "User-Agent")
        request.httpShouldHandleCookies = false

        do {
            let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            // Also after a failure of the server's making, so a broken answer is not asked for every hour.
            defaults.set(Date.now, forKey: Self.lastCheckedKey)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                let release = UpdateCheck.release(fromLatestReleaseJSON: data)
            else {
                log.error("The answer to the update check could not be used")
                return .failed
            }
            log.notice("Newest release is \(release.version.description, privacy: .public)")
            guard let current = Self.currentVersion, release.version > current else { return .upToDate }
            return .available(release)
        } catch {
            log.notice("Update check failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    private func offer(_ release: ReleaseInfo, allowsSkipping: Bool) {
        let alert = NSAlert()
        alert.messageText = tr("Keyfari %@ is available", release.version.description)
        alert.informativeText = tr(
            "You have %@. The download page opens in your browser; Keyfari downloads nothing by itself.",
            Self.currentVersion?.description ?? "–")
        alert.addButton(withTitle: tr("Download"))
        alert.addButton(withTitle: tr("Later"))
        if allowsSkipping {
            alert.addButton(withTitle: tr("Skip This Version"))
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = tr("Do not check for updates")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            store.settings.updateCheckEnabled = false
        }
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.page)
        case .alertThirdButtonReturn:
            store.settings.skippedVersion = release.version.description
        default:
            break
        }
    }

    private func inform(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
