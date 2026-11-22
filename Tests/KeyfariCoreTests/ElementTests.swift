// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct ElementTests {
    @Test func anElementIsClickedInTheMiddleOfWhatShows() {
        let frame = CGRect(x: 100, y: 100, width: 200, height: 40)
        #expect(ElementSnapshot(role: "AXButton", frame: frame).clickPoint == CGPoint(x: 200, y: 120))
        // Half of it is scrolled out of view.
        let clipped = CGRect(x: 100, y: 100, width: 100, height: 40)
        #expect(ElementSnapshot(role: "AXButton", frame: frame, clippedFrame: clipped).clickPoint == CGPoint(x: 150, y: 120))
    }

    @Test func aClippedLinkIsClickedInsideWhatShows() {
        let frame = CGRect(x: 100, y: 100, width: 300, height: 60)
        // Only the top-right part shows, so the usual point near the bottom-left corner is hidden.
        let clipped = CGRect(x: 250, y: 100, width: 150, height: 20)
        let point = ElementSnapshot(role: "AXLink", frame: frame, clippedFrame: clipped).clickPoint
        #expect(clipped.contains(point))
    }

    @Test func textFieldsAcceptText() {
        #expect(ElementSnapshot(role: "AXTextField", frame: .zero).acceptsText)
        #expect(ElementSnapshot(role: "AXSearchField", frame: .zero).acceptsText)
        #expect(!ElementSnapshot(role: "AXButton", frame: .zero).acceptsText)
    }

    @Test func readingOrderGoesRowByRowThenLeftToRight() {
        func button(_ name: String, x: CGFloat, y: CGFloat) -> ElementSnapshot {
            ElementSnapshot(role: "AXButton", frame: CGRect(x: x, y: y, width: 20, height: 10), searchText: name)
        }
        let elements = [button("lower", x: 0, y: 100), button("right", x: 300, y: 12), button("left", x: 10, y: 14)]
        #expect(ReadingOrder.sorted(elements).map(\.searchText) == ["left", "right", "lower"])
    }

    @Test func aShortcutNeedsARealModifier() {
        #expect(!Shortcut(keyCode: KeyCode.space, modifiers: []).isUsable)
        #expect(!Shortcut(keyCode: KeyCode.space, modifiers: .shift).isUsable)
        #expect(Shortcut(keyCode: KeyCode.space, modifiers: [.shift, .option]).isUsable)
        #expect(Shortcut(keyCode: KeyCode.leftArrow, modifiers: .control).displayParts == ["⌃", "←"])
        #expect(KeyCode.name(of: 200) == "Key 200")
    }

    @Test func clickActionsFollowTheModifiers() {
        #expect(ClickAction(modifiers: []) == .left)
        #expect(ClickAction(modifiers: .shift) == .right)
        #expect(ClickAction(modifiers: .command) == .double)
        #expect(ClickAction(modifiers: .control) == .commandLeft)
        #expect(ClickAction(modifiers: .option) == .moveOnly)
        #expect(ClickAction.double.clickCount == 2)
        #expect(ClickAction.moveOnly.clickCount == 0)
    }
}
