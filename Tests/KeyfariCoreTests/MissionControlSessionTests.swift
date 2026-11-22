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

    @Test func aCompleteLabelSelectsWithoutOpening() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s)) == .focused(index: 2))
        #expect(session.focused == 2)
    }

    @Test func returnOpensTheSelection() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: s)) == .focused(index: 1))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return)) == .confirmed(index: 1))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.keypadEnter)) == .confirmed(index: 1))
    }

    @Test func returnWithoutASelectionIsRejected() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return)) == .rejected)
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return)) == .rejected)
        #expect(session.prefix == "A")
    }

    @Test func narrowsAndRejectsKeysThatMatchNothing() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: a)) == .updated(prefix: "A"))
        #expect(session.handle(KeyStroke(keyCode: d)) == .rejected)
        #expect(session.prefix == "A")
        #expect(session.handle(KeyStroke(keyCode: f)) == .rejected)
    }

    @Test func aLetterAfterASelectionStartsANewLabel() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: s))
        #expect(session.handle(KeyStroke(keyCode: d)) == .focused(index: 3))
        #expect(session.handle(KeyStroke(keyCode: a)) == .updated(prefix: "A"))
        #expect(session.focused == nil)
        // A letter that matches nothing leaves the selection alone.
        _ = session.handle(KeyStroke(keyCode: s))
        #expect(session.handle(KeyStroke(keyCode: f)) == .rejected)
        #expect(session.focused == 1)
    }

    @Test func deleteDropsTheSelectionAndTheLastLetter() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        _ = session.handle(KeyStroke(keyCode: s))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .updated(prefix: "A"))
        #expect(session.focused == nil)
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
        _ = session.handle(KeyStroke(keyCode: s))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.return, isRepeat: true)) == .ignored)
    }

    @Test func readsLettersAndControlKeysButLeavesTheArrowsAlone() {
        let keys = MissionControlSession.keyCodes
        #expect(keys.isSuperset(of: [a, s, KeyCode.return, KeyCode.keypadEnter, KeyCode.delete, KeyCode.escape]))
        #expect(keys.isDisjoint(with: [KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow, KeyCode.space, KeyCode.tab, one]))
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

    @Test func theCurrentDisplayIsTheOneUnderThePointer() {
        let displays = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]
        #expect(MissionControlLayout.currentDisplay(pointer: CGPoint(x: 2000, y: 500), displayFrames: displays) == 1)
        #expect(MissionControlLayout.currentDisplay(pointer: CGPoint(x: 10, y: 10), displayFrames: displays) == 0)
        // Off every display: the first one.
        #expect(MissionControlLayout.currentDisplay(pointer: CGPoint(x: -50, y: 5000), displayFrames: displays) == 0)
        #expect(MissionControlLayout.currentDisplay(pointer: .zero, displayFrames: []) == nil)
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
