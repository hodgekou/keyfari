// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation
import KeyfariCore
import Observation

struct AppClickStats: Identifiable {
    let bundleID: String
    let name: String
    let clicks: Int

    var id: String { bundleID }
}

/// Keeps the usage counts in the user defaults, on this Mac only. The counting lives in `UsageLedger`.
@MainActor
@Observable
final class UsageStatsStore {
    private static let key = "usageStats"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var appNames: [String: String] = [:]
    private var ledger: UsageLedger

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ledger = (try? JSONDecoder().decode(UsageLedger.self, from: defaults.data(forKey: Self.key) ?? Data())) ?? UsageLedger()
    }

    var totalClicks: Int { ledger.totalClicks }
    var totalActions: Int { ledger.totalActions }
    var activeDays: Int { ledger.activeDays }
    var currentStreak: Int { ledger.currentStreak(today: .now, calendar: .autoupdatingCurrent) }
    var longestStreak: Int { ledger.longestStreak(calendar: .autoupdatingCurrent) }

    var topApps: [AppClickStats] {
        ledger.appsByClicks.map { AppClickStats(bundleID: $0.bundleID, name: appName($0.bundleID), clicks: $0.clicks) }
    }

    func record(bundleID: String, clicks: Int, isNewAction: Bool) {
        ledger.record(bundleID: bundleID, clicks: clicks, isNewAction: isNewAction, on: .now, calendar: .autoupdatingCurrent)
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        ledger = UsageLedger()
        defaults.removeObject(forKey: Self.key)
    }

    /// The name to show for an application, looked up once.
    private func appName(_ bundleID: String) -> String {
        if let name = appNames[bundleID] { return name }
        let name = ApplicationInfo(bundleID: bundleID).name
        appNames[bundleID] = name
        return name
    }
}
