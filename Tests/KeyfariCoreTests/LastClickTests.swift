// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct LastClickTests {
    func button(_ text: String, x: CGFloat = 0) -> ElementSnapshot {
        ElementSnapshot(role: "AXButton", frame: CGRect(x: x, y: 0, width: 80, height: 20), searchText: text)
    }

    @Test func remembersWhatWasClickedAndHow() {
        let click = LastClick(element: button("Next"), bundleID: "com.example.app", action: .right)
        #expect(click?.fingerprint == "AXButton|next")
        #expect(click?.action == .right)
    }

    @Test func doesNotRememberWhatCannotBeRepeated() {
        #expect(LastClick(element: button(""), bundleID: "com.example.app", action: .left) == nil)
        #expect(LastClick(element: button("Next"), bundleID: "", action: .left) == nil)
        #expect(LastClick(element: button("Next"), bundleID: "com.example.app", action: .moveOnly) == nil)
    }

    @Test func findsTheSameElementWhereverItMovedTo() throws {
        let click = try #require(LastClick(element: button("Next", x: 10), bundleID: "com.example.app", action: .left))
        let elements = [button("Previous"), button("Next", x: 400), button("Next", x: 800)]
        let app = "com.example.app"
        #expect(click.index(in: elements, bundleIDs: [app, app, app]) == 1)
        // The same text in another application is another element.
        #expect(click.index(in: elements, bundleIDs: [app, "com.apple.dock", app]) == 2)
        #expect(click.index(in: [button("Previous")], bundleIDs: [app]) == nil)
        #expect(click.index(in: [], bundleIDs: []) == nil)
    }
}
