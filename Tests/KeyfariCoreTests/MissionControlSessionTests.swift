// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct MissionControlSessionTests {
    // Key codes on an ANSI keyboard.
    let a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2, f: UInt16 = 3, one: UInt16 = 18

    func session() -> MissionControlSession {
        MissionControlSession(labels: ["AA", "AS", "S", "D"])
    }

    @Test func aCompleteLabelOpensItsItemAtOnce() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s)) == .matched(index: 2))
    }

    @Test func narrowsThenOpens() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: a)) == .updated(prefix: "A"))
        #expect(session.handle(KeyStroke(keyCode: s)) == .matched(index: 1))
    }

    @Test func rejectsKeysThatMatchNothingAndKeepsThePrefix() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: d)) == .rejected)
        #expect(session.prefix == "A")
        #expect(session.handle(KeyStroke(keyCode: f)) == .rejected)
    }

    @Test func deleteRemovesTheLastLetter() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .updated(prefix: ""))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .ignored)
    }

    @Test func escapeAndControlBracketExit() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.escape)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket, modifiers: .control)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket)) == .ignored)
    }

    @Test func repeatsModifiedLettersAndOtherKeysAreIgnored() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s, isRepeat: true)) == .ignored)
        #expect(session.handle(KeyStroke(keyCode: s, modifiers: .command)) == .ignored)
        #expect(session.handle(KeyStroke(keyCode: one)) == .ignored)
    }

    @Test func readsLettersAndControlKeysButLeavesTheRestToMissionControl() {
        let keys = MissionControlSession.keyCodes
        #expect(keys.isSuperset(of: [a, s, KeyCode.delete, KeyCode.escape]))
        #expect(
            keys.isDisjoint(with: [
                KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow, KeyCode.space, KeyCode.tab, KeyCode.return, one,
            ]))
    }

    @Test func aDesktopNameInTheCollapsedBarSitsOnTheLeftEdgeOfItsFrame() {
        let bar = CGRect(x: 0, y: 0, width: 1470, height: 72)
        let button = CGRect(x: 734, y: 0, width: 168, height: 129)
        #expect(MissionControlLayout.spaceLabelPoint(button: button, bar: bar) == CGPoint(x: 734, y: 36))
    }

    @Test func aDesktopThumbnailCarriesItsLabelInTheMiddle() {
        let bar = CGRect(x: 0, y: 0, width: 1470, height: 160)
        let button = CGRect(x: 600, y: 20, width: 168, height: 110)
        #expect(MissionControlLayout.spaceLabelPoint(button: button, bar: bar) == CGPoint(x: 684, y: 75))
    }

    @Test func readingOrderGoesRowByRow() {
        let frames = [
            CGRect(x: 900, y: 110, width: 200, height: 120),
            CGRect(x: 100, y: 400, width: 200, height: 120),
            CGRect(x: 100, y: 120, width: 200, height: 120),
        ]
        #expect(MissionControlLayout.readingOrder(frames) == [2, 0, 1])
    }
}
