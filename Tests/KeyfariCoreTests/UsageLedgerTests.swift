// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct UsageLedgerTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// Noon on a day of November 2026.
    func day(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12)) ?? .distantPast
    }

    func ledger(activeOn days: [Int]) -> UsageLedger {
        var ledger = UsageLedger()
        for day in days {
            ledger.record(bundleID: "com.example.app", clicks: 1, isNewAction: true, on: self.day(day), calendar: calendar)
        }
        return ledger
    }

    @Test func countsClicksActionsDaysAndApplications() {
        var ledger = UsageLedger()
        ledger.record(bundleID: "a", clicks: 1, isNewAction: true, on: day(1), calendar: calendar)
        // A double click is one action and two clicks.
        ledger.record(bundleID: "b", clicks: 2, isNewAction: true, on: day(1), calendar: calendar)
        ledger.record(bundleID: "b", clicks: 1, isNewAction: true, on: day(3), calendar: calendar)
        #expect(ledger.totalClicks == 4)
        #expect(ledger.totalActions == 3)
        #expect(ledger.activeDays == 2)
        #expect(ledger.appsByClicks.map(\.bundleID) == ["b", "a"])
        #expect(ledger.appsByClicks.map(\.clicks) == [3, 1])
    }

    @Test func aLaterSecondClickBelongsToTheSameAction() {
        var ledger = UsageLedger()
        ledger.record(bundleID: "a", clicks: 1, isNewAction: true, on: day(1), calendar: calendar)
        ledger.record(bundleID: "a", clicks: 1, isNewAction: false, on: day(1), calendar: calendar)
        #expect(ledger.totalClicks == 2)
        #expect(ledger.totalActions == 1)
    }

    @Test func anActionWithoutAClickStillMakesTheDayActive() {
        var ledger = UsageLedger()
        ledger.record(bundleID: "", clicks: 0, isNewAction: true, on: day(1), calendar: calendar)
        #expect(ledger.totalActions == 1)
        #expect(ledger.totalClicks == 0)
        #expect(ledger.activeDays == 1)
        #expect(ledger.appsByClicks.isEmpty)
    }

    @Test func clicksStandInForActionsInOlderData() throws {
        let json = #"{"clicksByDay":{"2026-11-01":7},"clicksByApp":{"a":7}}"#
        var ledger = try JSONDecoder().decode(UsageLedger.self, from: Data(json.utf8))
        #expect(ledger.totalActions == 7)
        // A late second click must not make that eight.
        ledger.record(bundleID: "a", clicks: 1, isNewAction: false, on: day(2), calendar: calendar)
        #expect(ledger.totalActions == 7)
        ledger.record(bundleID: "a", clicks: 1, isNewAction: true, on: day(2), calendar: calendar)
        #expect(ledger.totalActions == 8)
        #expect(try JSONDecoder().decode(UsageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
    }

    @Test func theCurrentStreakEndsTodayOrYesterday() {
        let ledger = ledger(activeOn: [3, 4, 5])
        #expect(ledger.currentStreak(today: day(5), calendar: calendar) == 3)
        // Nothing yet today: the streak still stands.
        #expect(ledger.currentStreak(today: day(6), calendar: calendar) == 3)
        // A whole day missed: it is gone.
        #expect(ledger.currentStreak(today: day(7), calendar: calendar) == 0)
        #expect(UsageLedger().currentStreak(today: day(5), calendar: calendar) == 0)
    }

    @Test func theLongestStreakIsTheLongestRunOfDays() {
        #expect(ledger(activeOn: [1, 2, 5, 6, 7, 9]).longestStreak(calendar: calendar) == 3)
        #expect(ledger(activeOn: [4]).longestStreak(calendar: calendar) == 1)
        #expect(UsageLedger().longestStreak(calendar: calendar) == 0)
    }

    @Test func aStreakRunsAcrossTheEndOfAMonth() {
        var ledger = UsageLedger()
        let october31 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12)) ?? .distantPast
        ledger.record(bundleID: "a", clicks: 1, isNewAction: true, on: october31, calendar: calendar)
        ledger.record(bundleID: "a", clicks: 1, isNewAction: true, on: day(1), calendar: calendar)
        #expect(ledger.longestStreak(calendar: calendar) == 2)
        #expect(ledger.currentStreak(today: day(1), calendar: calendar) == 2)
    }

    @Test func dayKeysRoundTripAndMalformedOnesAreSkipped() {
        #expect(UsageLedger.dayKey(day(7), calendar: calendar) == "2026-11-07")
        #expect(UsageLedger.date(fromDayKey: "2026-11-07", calendar: calendar) == calendar.startOfDay(for: day(7)))
        #expect(UsageLedger.date(fromDayKey: "yesterday", calendar: calendar) == nil)
    }

    @Test func activityIsLaidOutByWeekStartingOnTheFirstWeekday() {
        // 22 November 2026 is a Sunday; with weeks starting on Monday it ends its week.
        var monday = calendar
        monday.firstWeekday = 2
        var ledger = UsageLedger()
        ledger.record(bundleID: "a", clicks: 3, isNewAction: true, on: day(22), calendar: monday)
        ledger.record(bundleID: "a", clicks: 5, isNewAction: true, on: day(16), calendar: monday)
        ledger.record(bundleID: "a", clicks: 1, isNewAction: true, on: day(9), calendar: monday)

        let weeks = ledger.activity(weeks: 2, today: day(22), calendar: monday)
        // The week of 9 November, then the week of 16 November.
        #expect(weeks == [[1, 0, 0, 0, 0, 0, 0], [5, 0, 0, 0, 0, 0, 3]])
    }

    @Test func daysThatHaveNotComeAreLeftOut() {
        var monday = calendar
        monday.firstWeekday = 2
        // 18 November 2026 is a Wednesday.
        let weeks = ledger(activeOn: [18]).activity(weeks: 1, today: day(18), calendar: monday)
        #expect(weeks == [[0, 0, 1, nil, nil, nil, nil]])
        #expect(UsageLedger().activity(weeks: 0, today: day(18), calendar: monday).isEmpty)
    }

    @Test func activityLevelsAreQuartersOfTheBusiestDay() {
        #expect(UsageLedger.activityLevel(clicks: 0, busiest: 40) == 0)
        #expect(UsageLedger.activityLevel(clicks: 1, busiest: 40) == 1)
        #expect(UsageLedger.activityLevel(clicks: 10, busiest: 40) == 1)
        #expect(UsageLedger.activityLevel(clicks: 11, busiest: 40) == 2)
        #expect(UsageLedger.activityLevel(clicks: 30, busiest: 40) == 3)
        #expect(UsageLedger.activityLevel(clicks: 40, busiest: 40) == 4)
        #expect(UsageLedger.activityLevel(clicks: 5, busiest: 0) == 0)
    }
}
