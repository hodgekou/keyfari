// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct SettingsArchiveTests {
    func entry(_ label: String, title: String = "Save", bundleID: String = "com.example.app") -> StableLabelEntry {
        StableLabelEntry(
            bundleID: bundleID, fingerprint: "AXButton|\(title.lowercased())", label: label, title: title, isCustom: true,
            lastUsed: Date(timeIntervalSinceReferenceDate: 1000), useCount: 3
        )
    }

    @Test func whatIsWrittenIsReadBackTheSame() throws {
        var settings = Settings()
        settings.chainClicks = true
        settings.scrollKeys = "dhtn"
        settings.halfPageKeys = "eu"
        settings.nextSpaceShortcut = Shortcut(keyCode: KeyCode.rightArrow, modifiers: [.control, .option])
        let archive = SettingsArchive(settings: settings, stableLabels: [entry("JK"), entry("S", title: "Open")])

        let data = try archive.encoded()
        #expect(try SettingsArchive.read(data) == archive)
        // Readable by a person.
        #expect(String(decoding: data, as: UTF8.self).contains("\"chainClicks\" : true"))
    }

    @Test func outOfRangeSettingsComeBackAsDefaults() throws {
        var settings = Settings()
        settings.scrollSpeed = 9000
        settings.hintAlphabet = "ab"
        let read = try SettingsArchive.read(SettingsArchive(settings: settings, stableLabels: []).encoded())
        #expect(read.settings == Settings())
    }

    @Test func labelsThisAppCouldNotHaveWrittenAreDropped() throws {
        let labels = [
            entry("JK"),
            entry("jk", title: "Lowercase"),
            entry("J1", title: "Digit"),
            entry("", title: "Empty"),
            entry("TOOLONGG", title: "Long"),
            entry("S", title: "No application", bundleID: ""),
            entry("D"),  // The same element as the first.
        ]
        let read = try SettingsArchive.read(SettingsArchive(settings: Settings(), stableLabels: labels).encoded())
        #expect(read.stableLabels.map(\.label) == ["JK"])
    }

    @Test func refusesWhatIsNotASettingsFile() {
        #expect(throws: SettingsArchive.ReadError.unreadable) { try SettingsArchive.read(Data("hello".utf8)) }
        #expect(throws: SettingsArchive.ReadError.unreadable) { try SettingsArchive.read(Data(#"{"settings":{}}"#.utf8)) }
        #expect(throws: SettingsArchive.ReadError.unreadable) {
            try SettingsArchive.read(Data(#"{"format":0,"settings":{},"stableLabels":[]}"#.utf8))
        }
        #expect(throws: SettingsArchive.ReadError.newerFormat(7)) {
            try SettingsArchive.read(Data(#"{"format":7,"settings":{},"stableLabels":[]}"#.utf8))
        }
        #expect(throws: SettingsArchive.ReadError.tooLarge) {
            try SettingsArchive.read(Data(repeating: 0x20, count: SettingsArchive.maximumSize + 1))
        }
    }

    @Test func aFileWithOnlySomeSettingsKeepsDefaultsForTheRest() throws {
        let data = Data(#"{"format":1,"settings":{"scrollSpeed":35},"stableLabels":[]}"#.utf8)
        let read = try SettingsArchive.read(data)
        #expect(read.settings.scrollSpeed == 35)
        #expect(read.settings.hintShortcut == Settings().hintShortcut)
    }
}
