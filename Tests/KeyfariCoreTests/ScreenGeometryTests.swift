// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct ScreenGeometryTests {
    @Test func flipIsItsOwnInverse() {
        let rect = CGRect(x: 120, y: 40, width: 300, height: 200)
        let flipped = ScreenGeometry.flipped(rect, primaryScreenHeight: 1080)
        #expect(flipped == CGRect(x: 120, y: 840, width: 300, height: 200))
        #expect(ScreenGeometry.flipped(flipped, primaryScreenHeight: 1080) == rect)
    }

    @Test func picksTheScreenHoldingMostOfTheRect() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 1000, y: 0, width: 1000, height: 800),
        ]
        let mostlyOnSecond = CGRect(x: 900, y: 100, width: 400, height: 100)
        #expect(ScreenGeometry.indexOfScreen(containing: mostlyOnSecond, screenFrames: screens) == 1)
    }

    @Test func returnsNilWhenNoScreenIntersects() {
        let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800)]
        let offscreen = CGRect(x: 5000, y: 5000, width: 10, height: 10)
        #expect(ScreenGeometry.indexOfScreen(containing: offscreen, screenFrames: screens) == nil)
    }

    @Test func tellsWhatShowsFromWhatIsParkedBeyondTheEdge() {
        let displays = [CGRect(x: 0, y: 0, width: 1920, height: 1080), CGRect(x: -1470, y: 124, width: 1470, height: 956)]
        // A Dock icon at the bottom of the first display.
        #expect(ScreenGeometry.isOnScreen(CGRect(x: 91, y: 1000, width: 59, height: 75), displays: displays))
        // The same icon while the Dock is hidden below the edge.
        #expect(!ScreenGeometry.isOnScreen(CGRect(x: 91, y: 1076, width: 59, height: 75), displays: displays))
        // Half way out.
        #expect(!ScreenGeometry.isOnScreen(CGRect(x: 91, y: 1040, width: 59, height: 75), displays: displays))
        #expect(ScreenGeometry.isOnScreen(CGRect(x: -1400, y: 1000, width: 59, height: 75), displays: displays))
        #expect(!ScreenGeometry.isOnScreen(.zero, displays: displays))
        #expect(!ScreenGeometry.isOnScreen(CGRect(x: 0, y: 0, width: 10, height: 10), displays: []))
    }
}
