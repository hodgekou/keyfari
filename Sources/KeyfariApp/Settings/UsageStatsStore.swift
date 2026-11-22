// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation
import Observation

struct AppClickStats: Identifiable {
    let bundleID: String
    let name: String
    let clicks: Int

    var id: String { bundleID }
}

/// Stores only aggregate click counts and active dates on this Mac.
@MainActor
@Observable
final class UsageStatsStore {
    private struct Snapshot: Codable {
        var clicksByDay: [String: Int] = [:]
        var clicksByApp: [String: Int] = [:]
    }

    private static let key = "usageStats"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var appNames: [String: String] = [:]
    private var snapshot: Snapshot

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = Snapshot()
        }
    }

    var totalClicks: Int {
        snapshot.clicksByDay.values.reduce(0, +)
    }

    var activeDays: Int {
        snapshot.clicksByDay.count
    }

    var currentStreak: Int {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let start =
            snapshot.clicksByDay[dayKey(today)] == nil
            ? calendar.date(byAdding: .day, value: -1, to: today) ?? today
            : today
        return streak(startingAt: start, calendar: calendar)
    }

    var longestStreak: Int {
        let calendar = Calendar.autoupdatingCurrent
        let days = snapshot.clicksByDay.keys.compactMap(date(from:)).sorted()
        var longest = 0
        var current = 0
        var previous: Date?

        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
    }

    var topApps: [AppClickStats] {
        snapshot.clicksByApp
            .map { bundleID, clicks in AppClickStats(bundleID: bundleID, name: appNames[bundleID] ?? resolveAppName(bundleID), clicks: clicks) }
            .sorted { lhs, rhs in
                lhs.clicks == rhs.clicks ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending : lhs.clicks > rhs.clicks
            }
    }

    func recordClick(bundleID: String, count: Int) {
        guard count > 0 else { return }
        snapshot.clicksByDay[dayKey(.now), default: 0] += count
        if !bundleID.isEmpty {
            snapshot.clicksByApp[bundleID, default: 0] += count
        }
        save()
    }

    func clear() {
        snapshot = Snapshot()
        defaults.removeObject(forKey: Self.key)
    }

    private func streak(startingAt start: Date, calendar: Calendar) -> Int {
        var day = start
        var count = 0
        while snapshot.clicksByDay[dayKey(day)] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private func dayKey(_ date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    private func resolveAppName(_ bundleID: String) -> String {
        if let name = appNames[bundleID] { return name }
        if let name = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID })?.localizedName {
            appNames[bundleID] = name
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
            let bundle = Bundle(url: url),
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        {
            appNames[bundleID] = name
            return name
        }
        appNames[bundleID] = bundleID
        return bundleID
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
