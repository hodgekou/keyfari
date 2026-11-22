// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct HintSessionTests {
    // Key codes on an ANSI keyboard.
    let a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2, one: UInt16 = 18

    func session() -> HintSession {
        HintSession(labels: ["AA", "AS", "S", "D"])
    }

    @Test func singleCharacterLabelMatchesAtOnce() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s)) == .matched(index: 2, action: .left))
    }

    @Test func narrowsThenMatches() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: a)) == .updated(prefix: "A", visible: [0, 1]))
        #expect(session.handle(KeyStroke(keyCode: s)) == .matched(index: 1, action: .left))
    }

    @Test func rejectsKeysThatMatchNothingAndKeepsPrefix() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: d)) == .rejected)
        #expect(session.prefix == "A")
    }

    @Test func deleteRemovesLastCharacter() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .ignored)
        _ = session.handle(KeyStroke(keyCode: a))
        #expect(session.handle(KeyStroke(keyCode: KeyCode.delete)) == .updated(prefix: "", visible: [0, 1, 2, 3]))
    }

    @Test func exitsOnEscapeAndControlBracket() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.escape)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket, modifiers: .control)) == .exit)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.leftBracket)) == .ignored)
    }

    @Test func spaceRotatesAndOtherKeysAreIgnored() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: KeyCode.space)) == .rotate)
        #expect(session.handle(KeyStroke(keyCode: one)) == .ignored)
        #expect(session.handle(KeyStroke(keyCode: KeyCode.tab)) == .ignored)
    }

    @Test func ignoresAutoRepeat() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: a, isRepeat: true)) == .ignored)
        #expect(session.prefix.isEmpty)
    }

    @Test(arguments: [
        (Modifiers([]), ClickAction.left),
        (Modifiers.shift, ClickAction.right),
        (Modifiers.command, ClickAction.double),
        (Modifiers.control, ClickAction.commandLeft),
        (Modifiers.option, ClickAction.moveOnly),
    ])
    func modifiersOnTheFinalKeySelectTheAction(modifiers: Modifiers, action: ClickAction) {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: d, modifiers: modifiers)) == .matched(index: 3, action: action))
    }

    @Test func controlShiftOnTheLastLetterPicksTheElementUp() {
        var session = session()
        #expect(session.handle(KeyStroke(keyCode: s, modifiers: [.control, .shift])) == .pickedUp(index: 2))
        // On a letter that only narrows, the modifiers mean nothing yet.
        #expect(session.handle(KeyStroke(keyCode: a, modifiers: [.control, .shift])) == .updated(prefix: "A", visible: [0, 1]))
        #expect(session.handle(KeyStroke(keyCode: s, modifiers: [.control, .shift])) == .pickedUp(index: 1))
        // Shift alone is still a right click.
        var other = self.session()
        #expect(other.handle(KeyStroke(keyCode: s, modifiers: .shift)) == .matched(index: 2, action: .right))
    }

    @Test func afterPickingUpAnotherLabelCanBeTyped() {
        var session = session()
        _ = session.handle(KeyStroke(keyCode: a))
        _ = session.handle(KeyStroke(keyCode: s, modifiers: [.control, .shift]))
        #expect(session.prefix == "A")
        session.clearPrefix()
        #expect(session.prefix.isEmpty)
        #expect(session.handle(KeyStroke(keyCode: d)) == .matched(index: 3, action: .left))
    }
}
