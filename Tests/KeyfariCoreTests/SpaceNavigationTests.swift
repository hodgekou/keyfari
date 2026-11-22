// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Foundation
import Testing

@testable import KeyfariCore

@Suite struct SpaceNavigationTests {
    let controlLeft = Shortcut(keyCode: KeyCode.leftArrow, modifiers: .control)
    let controlRight = Shortcut(keyCode: KeyCode.rightArrow, modifiers: .control)

    // The modifier flags as the system stores them.
    let control = 1 << 18, option = 1 << 19, function = 1 << 23

    @Test func aMissingEntryMeansTheStandardShortcut() {
        #expect(SystemSpaceShortcut.resolve(entry: nil, direction: .previous) == controlLeft)
        #expect(SystemSpaceShortcut.resolve(entry: nil, direction: .next) == controlRight)
    }

    @Test func anEnabledEntryWithoutKeysMeansTheStandardShortcut() {
        #expect(SystemSpaceShortcut.resolve(entry: ["enabled": true], direction: .next) == controlRight)
    }

    @Test func aDisabledEntryMeansNoShortcut() {
        let entry: [String: Any] = ["enabled": false, "value": ["parameters": [65535, 123, control | function], "type": "standard"]]
        #expect(SystemSpaceShortcut.resolve(entry: entry, direction: .previous) == nil)
    }

    @Test func readsTheKeysTheUserChose() {
        let entry: [String: Any] = ["enabled": true, "value": ["parameters": [104, 4, control | option], "type": "standard"]]
        #expect(SystemSpaceShortcut.resolve(entry: entry, direction: .previous) == Shortcut(keyCode: 4, modifiers: [.control, .option]))
    }

    @Test func anEntryWithoutAKeyMeansNoShortcut() {
        let entry: [String: Any] = ["enabled": true, "value": ["parameters": [65535, 65535, 0]]]
        #expect(SystemSpaceShortcut.resolve(entry: entry, direction: .next) == nil)
    }

    @Test func thePointerStaysPutOnASingleDisplay() {
        let displays = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        let target = SpaceGeometry.pointerTarget(
            pointer: CGPoint(x: 10, y: 10), focusedWindowFrame: CGRect(x: 100, y: 100, width: 400, height: 300),
            displays: displays, displaysHaveSeparateSpaces: true
        )
        #expect(target == nil)
    }

    @Test func thePointerGoesToTheDisplayOfTheFocusedWindow() {
        let displays = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]
        let window = CGRect(x: 1540, y: 100, width: 400, height: 300)
        let onOtherDisplay = SpaceGeometry.pointerTarget(
            pointer: CGPoint(x: 10, y: 10), focusedWindowFrame: window, displays: displays, displaysHaveSeparateSpaces: true
        )
        #expect(onOtherDisplay == CGPoint(x: 1740, y: 250))

        let onSameDisplay = SpaceGeometry.pointerTarget(
            pointer: CGPoint(x: 3000, y: 900), focusedWindowFrame: window, displays: displays, displaysHaveSeparateSpaces: true
        )
        #expect(onSameDisplay == nil)
    }

    @Test func thePointerStaysPutWhenSpacesSpanDisplaysOrNoWindowHasFocus() {
        let displays = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]
        let window = CGRect(x: 1540, y: 100, width: 400, height: 300)
        let pointer = CGPoint(x: 10, y: 10)
        #expect(
            SpaceGeometry.pointerTarget(pointer: pointer, focusedWindowFrame: window, displays: displays, displaysHaveSeparateSpaces: false) == nil)
        #expect(SpaceGeometry.pointerTarget(pointer: pointer, focusedWindowFrame: nil, displays: displays, displaysHaveSeparateSpaces: true) == nil)
    }
}
