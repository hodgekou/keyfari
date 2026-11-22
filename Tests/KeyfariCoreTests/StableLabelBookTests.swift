// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Foundation
import Testing

@testable import KeyfariCore

@Suite struct StableLabelBookTests {
    let terminal = "com.apple.Terminal"
    let start = Date(timeIntervalSinceReferenceDate: 1000)

    func button(_ text: String) -> ElementSnapshot {
        ElementSnapshot(role: "AXButton", frame: .zero, searchText: text)
    }

    func later(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    @Test func aFirstClickAddsAnEntryUsedOnce() {
        var book = StableLabelBook()
        let result1 = book.remember("S", for: button("Save"), bundleID: terminal, now: start)
        #expect(result1)
        #expect(book.entries.count == 1)
        #expect(book.entries[0].label == "S")
        #expect(book.entries[0].title == "Save")
        #expect(book.entries[0].useCount == 1)
        #expect(!book.entries[0].isCustom)
    }

    @Test func everyFurtherClickCountsAndTakesTheNewLabel() {
        var book = StableLabelBook()
        book.remember("S", for: button("Save"), bundleID: terminal, now: start)
        book.remember("D", for: button("Save"), bundleID: terminal, now: later(60))
        #expect(book.entries.count == 1)
        #expect(book.entries[0].label == "D")
        #expect(book.entries[0].useCount == 2)
        #expect(book.entries[0].lastUsed == later(60))
    }

    @Test func theSameTextInAnotherApplicationIsAnotherEntry() {
        var book = StableLabelBook()
        book.remember("S", for: button("Save"), bundleID: terminal, now: start)
        book.remember("S", for: button("Save"), bundleID: "com.apple.TextEdit", now: start)
        #expect(book.entries.count == 2)
    }

    @Test func anElementThatCannotBeToldApartIsNotRemembered() {
        var book = StableLabelBook()
        let result2 = book.remember("S", for: button(""), bundleID: terminal, now: start)
        #expect(!result2)
        let result3 = book.remember("S", for: button("Save"), bundleID: "", now: start)
        #expect(!result3)
        #expect(book.entries.isEmpty)
    }

    @Test func anElementWithoutTextIsListedByItsRole() {
        var book = StableLabelBook()
        let icon = ElementSnapshot(role: "AXButton", frame: .zero, stableIdentity: "AXWindow[0]/AXButton[2]")
        book.remember("S", for: icon, bundleID: terminal, now: start)
        #expect(book.entries[0].title == "Button")
    }

    @Test func listsTheMostUsedFirstAndTheLatestOfEquals() {
        var book = StableLabelBook()
        book.remember("S", for: button("Once, early"), bundleID: terminal, now: start)
        book.remember("D", for: button("Twice"), bundleID: terminal, now: later(10))
        book.remember("D", for: button("Twice"), bundleID: terminal, now: later(20))
        book.remember("F", for: button("Once, late"), bundleID: terminal, now: later(30))
        #expect(book.byUse.map(\.title) == ["Twice", "Once, late", "Once, early"])
    }

    @Test func aChosenLabelStaysWhenTheElementIsClickedUnderAnother() throws {
        var book = StableLabelBook()
        book.remember("S", for: button("Save"), bundleID: terminal, now: start)
        let id = try #require(book.entries.first?.id)
        let result4 = book.setCustomLabel("JK", id: id, alphabet: "sdfjk")
        #expect(result4 == nil)
        book.remember("D", for: button("Save"), bundleID: terminal, now: later(5))
        #expect(book.entries[0].label == "JK")
        #expect(book.entries[0].isCustom)
        #expect(book.entries[0].useCount == 2)
    }

    @Test func aChosenLabelMustNotClashWithAnotherOfTheSameApplication() {
        var book = StableLabelBook()
        book.remember("S", for: button("Save"), bundleID: terminal, now: start)
        book.remember("D", for: button("Open"), bundleID: terminal, now: start)
        book.remember("F", for: button("Open"), bundleID: "com.apple.TextEdit", now: start)
        let ids = book.entries.map(\.id)
        let result5 = book.setCustomLabel("JK", id: ids[0], alphabet: "sdfjk")
        #expect(result5 == nil)
        let result6 = book.setCustomLabel("J", id: ids[1], alphabet: "sdfjk")
        #expect(result6 == .conflicts(with: "JK"))
        #expect(book.entries[1].label == "D")
        // Another application has labels of its own.
        let result7 = book.setCustomLabel("J", id: ids[2], alphabet: "sdfjk")
        #expect(result7 == nil)
        let result8 = book.setCustomLabel("JK", id: "no such entry", alphabet: "sdfjk")
        #expect(result8 == nil)
    }

    @Test func assignsChosenAndRememberedLabelsPerApplication() throws {
        var book = StableLabelBook()
        book.remember("F", for: button("Save"), bundleID: terminal, now: start)
        book.remember("D", for: button("Open"), bundleID: terminal, now: start)
        let open = try #require(book.entries.first { $0.title == "Open" }?.id)
        let result9 = book.setCustomLabel("JJ", id: open, alphabet: "sdfj")
        #expect(result9 == nil)

        let elements = [button("Save"), button("Open"), button("Save")]
        let labels = book.assign(to: elements, bundleIDs: [terminal, terminal, "com.apple.TextEdit"], alphabet: "sdfj")
        #expect(labels[0] == "F")
        #expect(labels[1] == "JJ")
        // The same text in another application has no remembered label.
        #expect(labels[2] != "F")
        #expect(Set(labels).count == 3)

        let fresh = book.assign(to: elements, bundleIDs: [terminal, terminal, terminal], alphabet: "sdfj", useMemory: false)
        #expect(!fresh.contains("JJ"))
        #expect(book.assign(to: elements, bundleIDs: [terminal, terminal, terminal], alphabet: "sdfj", reserve: 4).count == 7)
    }

    @Test func dropsTheEntriesUnusedLongestButKeepsChosenOnes() throws {
        var book = StableLabelBook(capacity: 2)
        book.remember("S", for: button("Oldest, chosen"), bundleID: terminal, now: start)
        let chosen = try #require(book.entries.first?.id)
        let result10 = book.setCustomLabel("J", id: chosen, alphabet: "sdfj")
        #expect(result10 == nil)
        book.remember("D", for: button("Old"), bundleID: terminal, now: later(10))
        book.remember("F", for: button("New"), bundleID: terminal, now: later(20))
        #expect(Set(book.entries.map(\.title)) == ["Oldest, chosen", "New"])
    }

    @Test func removesOneOrAll() throws {
        var book = StableLabelBook()
        book.remember("S", for: button("Save"), bundleID: terminal, now: start)
        book.remember("D", for: button("Open"), bundleID: terminal, now: start)
        book.remove(id: try #require(book.entries.first?.id))
        #expect(book.entries.map(\.title) == ["Open"])
        book.removeAll()
        #expect(book.entries.isEmpty)
    }

    @Test func anEntryStoredBeforeUsesWereCountedWasUsedOnce() throws {
        let json = #"[{"bundleID":"a","fingerprint":"AXButton|save","label":"S","title":"Save","isCustom":false,"lastUsed":0}]"#
        let entries = try JSONDecoder().decode([StableLabelEntry].self, from: Data(json.utf8))
        #expect(entries.first?.useCount == 1)
        let again = try JSONDecoder().decode([StableLabelEntry].self, from: JSONEncoder().encode(entries))
        #expect(again == entries)
    }
}
