// SPDX-License-Identifier: GPL-3.0-only

import Testing

@testable import KeyfariCore

@Suite struct TimeSavedTests {
    @Test func oneActionSavesFiveSeconds() {
        #expect(TimeSaved.seconds(actions: 1) == 5)
        #expect(TimeSaved.seconds(actions: 0) == 0)
        #expect(TimeSaved.seconds(actions: -3) == 0)
    }

    @Test func splitsIntoHoursMinutesAndSeconds() {
        #expect(TimeSaved.parts(actions: 7) == TimeSaved.Parts(hours: 0, minutes: 0, seconds: 35))
        #expect(TimeSaved.parts(actions: 12) == TimeSaved.Parts(hours: 0, minutes: 1, seconds: 0))
        // 1000 actions are 5000 seconds.
        #expect(TimeSaved.parts(actions: 1000) == TimeSaved.Parts(hours: 1, minutes: 23, seconds: 20))
    }
}
