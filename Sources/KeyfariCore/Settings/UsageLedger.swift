// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// Aggregate counts of what the modes did: nothing about which element was clicked, or when in a day.
public struct UsageLedger: Codable, Equatable, Sendable {
    /// Clicks per day, keyed `yyyy-MM-dd` in the user's calendar. A day with an entry was an active day.
    public private(set) var clicksByDay: [String: Int] = [:]
    public private(set) var clicksByApp: [String: Int] = [:]
    /// Missing in data written before actions were counted; the clicks stand in for it then.
    private var actions: Int?

    public init() {}

    public var totalClicks: Int {
        clicksByDay.values.reduce(0, +)
    }

    /// How many times a mode did something for the user. A double click is one action.
    public var totalActions: Int {
        actions ?? totalClicks
    }

    public var activeDays: Int {
        clicksByDay.count
    }

    /// Bundle identifiers with their clicks, most clicked first.
    public var appsByClicks: [(bundleID: String, clicks: Int)] {
        clicksByApp
            .map { (bundleID: $0.key, clicks: $0.value) }
            .sorted { $0.clicks == $1.clicks ? $0.bundleID < $1.bundleID : $0.clicks > $1.clicks }
    }

    /// Records the clicks an action sent, which are none when it only moved the pointer or opened
    /// something without a click.
    /// - Parameters:
    ///   - isNewAction: false for the second click of a double click that is sent later,
    ///     which belongs to the action already counted.
    ///   - date: when it happened.
    public mutating func record(bundleID: String, clicks: Int, isNewAction: Bool, on date: Date, calendar: Calendar) {
        if isNewAction {
            actions = totalActions + 1
        } else if actions == nil {
            // Pin the count down before the clicks grow, or they would stand in for one action more.
            actions = totalClicks
        }
        clicksByDay[Self.dayKey(date, calendar: calendar), default: 0] += max(clicks, 0)
        if !bundleID.isEmpty, clicks > 0 {
            clicksByApp[bundleID, default: 0] += clicks
        }
    }

    /// The run of active days that ends today, or yesterday when today has nothing yet:
    /// a streak is not lost before the day is over.
    public func currentStreak(today: Date, calendar: Calendar) -> Int {
        let start =
            clicksByDay[Self.dayKey(today, calendar: calendar)] == nil
            ? calendar.date(byAdding: .day, value: -1, to: today) ?? today
            : today
        var day = start
        var count = 0
        while clicksByDay[Self.dayKey(day, calendar: calendar)] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// The longest run of consecutive active days.
    public func longestStreak(calendar: Calendar) -> Int {
        let days = clicksByDay.keys.compactMap { Self.date(fromDayKey: $0, calendar: calendar) }.sorted()
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

    /// The clicks of each day of the last `weeks` weeks, for a calendar-style chart.
    ///
    /// One inner array per week, oldest first, each with seven entries that start on the
    /// calendar's first weekday. A day that has not come yet is nil; a day without activity is 0.
    public func activity(weeks: Int, today: Date, calendar: Calendar) -> [[Int?]] {
        guard weeks > 0 else { return [] }
        let start = calendar.startOfDay(for: today)
        // How many days into its week today is, counted from the calendar's first weekday.
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        guard let firstDay = calendar.date(byAdding: .day, value: -(offset + (weeks - 1) * 7), to: start) else { return [] }
        return (0..<weeks).map { week in
            (0..<7).map { day in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstDay), date <= start else { return nil }
                return clicksByDay[Self.dayKey(date, calendar: calendar)] ?? 0
            }
        }
    }

    /// How strongly to colour a day with `clicks`, from 0 (nothing) to 4, relative to the busiest day shown.
    public static func activityLevel(clicks: Int, busiest: Int) -> Int {
        guard clicks > 0, busiest > 0 else { return 0 }
        // Quarters of the busiest day shown.
        return max(1, min(4, Int((Double(clicks) / Double(busiest) * 4).rounded(.up))))
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// The start of the day a key names, or nil when the key is malformed.
    static func date(fromDayKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
