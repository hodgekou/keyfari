// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct ScrollSessionTests {
    // Key codes on an ANSI keyboard.
    let h: UInt16 = 4, j: UInt16 = 38, k: UInt16 = 40, l: UInt16 = 37
    let d: UInt16 = 2, u: UInt16 = 32, g: UInt16 = 5, n: UInt16 = 45, p: UInt16 = 35
    let two: UInt16 = 19, nine: UInt16 = 25

    @Test func directionKeysStartAndKeyUpStops() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: h), at: 0) == .start(.left, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: l), at: 0) == .start(.right, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: k), at: 0) == .start(.up, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: j), at: 0) == .start(.down, dash: false))
        // Only the key that scrolls now stops the scroll.
        #expect(session.keyUp(keyCode: k) == .ignored)
        #expect(session.keyUp(keyCode: j) == .stop)
        #expect(session.keyUp(keyCode: j) == .ignored)
    }

    @Test func shiftDashes() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: j, modifiers: .shift), at: 0) == .start(.down, dash: true))
    }

    @Test func repeatsAreIgnored() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: j, isRepeat: true), at: 0) == .ignored)
    }

    @Test func halfPagesAndEdges() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: d), at: 0) == .halfPage(.down))
        #expect(session.keyDown(KeyStroke(keyCode: u), at: 0) == .halfPage(.up))
        #expect(session.keyDown(KeyStroke(keyCode: g, modifiers: .shift), at: 0) == .bottom)
    }

    @Test func doubleGGoesToTopOnlyWithinTheTimeout() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 1.0) == .ignored)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 1.3) == .top)

        #expect(session.keyDown(KeyStroke(keyCode: g), at: 5.0) == .ignored)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 5.9) == .ignored)

        // Another key in between breaks the sequence.
        _ = session.keyDown(KeyStroke(keyCode: g), at: 10.0)
        _ = session.keyDown(KeyStroke(keyCode: d), at: 10.1)
        #expect(session.keyDown(KeyStroke(keyCode: g), at: 10.2) == .ignored)
    }

    @Test func cyclesThroughAreasAndWraps() {
        var session = ScrollSession(areaCount: 3)
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.tab), at: 0) == .selectArea(1))
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.downArrow), at: 0) == .selectArea(2))
        #expect(session.keyDown(KeyStroke(keyCode: n, modifiers: .control), at: 0) == .selectArea(0))
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.tab, modifiers: .shift), at: 0) == .selectArea(2))
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.upArrow), at: 0) == .selectArea(1))
        #expect(session.keyDown(KeyStroke(keyCode: p, modifiers: .control), at: 0) == .selectArea(0))
    }

    @Test func digitsJumpToExistingAreasOnly() {
        var session = ScrollSession(areaCount: 3)
        #expect(session.keyDown(KeyStroke(keyCode: two), at: 0) == .selectArea(2))
        #expect(session.areaIndex == 2)
        #expect(session.keyDown(KeyStroke(keyCode: nine), at: 0) == .ignored)
        #expect(session.areaIndex == 2)
    }

    @Test func exits() {
        var session = ScrollSession(areaCount: 1)
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.escape), at: 0) == .exit)
        #expect(session.keyDown(KeyStroke(keyCode: KeyCode.leftBracket, modifiers: .control), at: 0) == .exit)
    }

    @Test func readsCustomKeysAndRefusesUnusableOnes() {
        let keys = ScrollKeys(scroll: "DHTN", halfPage: "eu")
        #expect(keys?.left == "d")
        #expect(keys?.right == "n")
        #expect(keys?.halfPageDown == "e")
        #expect(ScrollKeys(scroll: "hjkl", halfPage: "du") == .standard)
        // Too few, a repeated letter, a letter shared between the two, G, a digit.
        for (scroll, halfPage) in [("hjk", "du"), ("hjkk", "du"), ("hjkl", "dl"), ("hjgl", "du"), ("hjkl", "d1"), ("hjkl", "d")] {
            #expect(ScrollKeys(scroll: scroll, halfPage: halfPage) == nil, "\(scroll) \(halfPage) should be refused")
        }
    }

    @Test func customKeysScrollAndTheStandardOnesNoLonger() throws {
        let t: UInt16 = 17, e: UInt16 = 14
        var session = ScrollSession(areaCount: 1, keys: try #require(ScrollKeys(scroll: "dhtn", halfPage: "eu")))
        #expect(session.keyDown(KeyStroke(keyCode: d), at: 0) == .start(.left, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: h), at: 0) == .start(.down, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: t, modifiers: .shift), at: 0) == .start(.up, dash: true))
        #expect(session.keyDown(KeyStroke(keyCode: n), at: 0) == .start(.right, dash: false))
        #expect(session.keyDown(KeyStroke(keyCode: e), at: 0) == .halfPage(.down))
        #expect(session.keyDown(KeyStroke(keyCode: u), at: 0) == .halfPage(.up))
        #expect(session.keyDown(KeyStroke(keyCode: j), at: 0) == .ignored)
        // The fixed keys stay.
        #expect(session.keyDown(KeyStroke(keyCode: g, modifiers: .shift), at: 0) == .bottom)
        #expect(session.keyDown(KeyStroke(keyCode: n, modifiers: .control), at: 0) == .selectArea(0))
    }

    @Test func arrowKeysSelectAreasUnlessToldToScroll() {
        var selecting = ScrollSession(areaCount: 3)
        #expect(selecting.keyDown(KeyStroke(keyCode: KeyCode.downArrow), at: 0) == .selectArea(1))
        #expect(selecting.keyDown(KeyStroke(keyCode: KeyCode.leftArrow), at: 0) == .ignored)

        var scrolling = ScrollSession(areaCount: 3, arrowsScroll: true)
        #expect(scrolling.keyDown(KeyStroke(keyCode: KeyCode.downArrow), at: 0) == .start(.down, dash: false))
        #expect(scrolling.keyUp(keyCode: KeyCode.downArrow) == .stop)
        #expect(scrolling.keyDown(KeyStroke(keyCode: KeyCode.upArrow, modifiers: .shift), at: 0) == .start(.up, dash: true))
        #expect(scrolling.keyDown(KeyStroke(keyCode: KeyCode.leftArrow), at: 0) == .start(.left, dash: false))
        #expect(scrolling.keyDown(KeyStroke(keyCode: KeyCode.rightArrow), at: 0) == .start(.right, dash: false))
        // The areas are still reached with Tab.
        #expect(scrolling.keyDown(KeyStroke(keyCode: KeyCode.tab), at: 0) == .selectArea(1))
    }
}
