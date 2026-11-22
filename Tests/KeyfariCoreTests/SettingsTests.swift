// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct SettingsTests {
    @Test func defaultsAreValid() {
        #expect(Settings().validated() == Settings())
    }

    @Test func outOfRangeValuesFallBack() {
        var settings = Settings()
        settings.hintAlphabet = "abc"
        settings.hintFontSize = 200
        settings.scrollSpeed = 0
        settings.dashMultiplier = 50
        #expect(settings.validated() == Settings())
    }

    @Test func alphabetIsLowercasedAndMustBeLetters() {
        var settings = Settings()
        settings.hintAlphabet = "ASDFGHJ"
        #expect(settings.validated().hintAlphabet == "asdfghj")
        settings.hintAlphabet = "asdf123"
        #expect(settings.validated().hintAlphabet == HintLabelGenerator.defaultAlphabet)
    }

    @Test func ignoredAppsAreTrimmedAndDeduplicated() {
        var settings = Settings()
        settings.ignoredBundleIDs = [" com.example.a ", "", "com.example.a", "com.example.b"]
        #expect(settings.validated().ignoredBundleIDs == ["com.example.a", "com.example.b"])
    }

    @Test func shortcutsMustBeDistinctAndModified() {
        var settings = Settings()
        settings.scrollShortcut = settings.hintShortcut
        #expect(settings.validated().scrollShortcut == Settings().scrollShortcut)

        settings = Settings()
        settings.hintShortcut = Shortcut(keyCode: KeyCode.space, modifiers: .shift)
        #expect(settings.validated().hintShortcut == Settings().hintShortcut)

        settings = Settings()
        settings.hintShortcut = Shortcut(keyCode: 3, modifiers: .control)
        #expect(settings.validated().hintShortcut == Shortcut(keyCode: 3, modifiers: .control))
    }

    @Test func spaceShortcutsAreOffByDefaultAndSurviveEncoding() throws {
        var settings = Settings()
        #expect(settings.previousSpaceShortcut == nil)
        #expect(settings.nextSpaceShortcut == nil)

        let shortcut = Shortcut(keyCode: KeyCode.rightArrow, modifiers: [.control, .option])
        settings.nextSpaceShortcut = shortcut
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.nextSpaceShortcut == shortcut)
        #expect(decoded.previousSpaceShortcut == nil)
        #expect(decoded.validated() == decoded)
    }

    @Test func aSpaceShortcutThatIsUnusableOrTakenIsSwitchedOff() {
        var settings = Settings()
        settings.previousSpaceShortcut = Shortcut(keyCode: KeyCode.leftArrow, modifiers: .shift)
        settings.nextSpaceShortcut = settings.hintShortcut
        #expect(settings.validated().previousSpaceShortcut == nil)
        #expect(settings.validated().nextSpaceShortcut == nil)
        #expect(settings.validated().hintShortcut == Settings().hintShortcut)

        // The first of two equal shortcuts keeps it.
        let shared = Shortcut(keyCode: KeyCode.leftArrow, modifiers: [.control, .option])
        settings.previousSpaceShortcut = shared
        settings.nextSpaceShortcut = shared
        #expect(settings.validated().previousSpaceShortcut == shared)
        #expect(settings.validated().nextSpaceShortcut == nil)
    }

    @Test func missionControlLabelsWaitForTheShortcutByDefault() throws {
        var settings = Settings()
        #expect(!settings.missionControlAutoHints)
        settings.missionControlAutoHints = true
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.missionControlAutoHints)
    }

    @Test func usageStatisticsAreOnUnlessSwitchedOff() throws {
        #expect(Settings().usageStatisticsEnabled)
        // The key the opt-in setting used before is not read, so an earlier build's "off" does not carry over.
        let earlier = try JSONDecoder().decode(Settings.self, from: Data(#"{"statisticsEnabled": false}"#.utf8))
        #expect(earlier.usageStatisticsEnabled)

        var settings = Settings()
        settings.usageStatisticsEnabled = false
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(!decoded.usageStatisticsEnabled)
    }

    @Test func allVisibleWindowsAreLabelledUnlessSwitchedOff() throws {
        #expect(Settings().hintAllWindows)
        var settings = Settings()
        settings.hintAllWindows = false
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(!decoded.hintAllWindows)
    }

    @Test func updatesAreCheckedUnlessSwitchedOff() throws {
        var settings = Settings()
        #expect(settings.updateCheckEnabled)
        settings.updateCheckEnabled = false
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        #expect(!decoded.updateCheckEnabled)
    }

    @Test func theWelcomeGuideIsForAFirstLaunchOnly() {
        #expect(FirstLaunch.shouldWelcome(hasSeenWelcome: false, hasStoredSettings: false))
        #expect(!FirstLaunch.shouldWelcome(hasSeenWelcome: true, hasStoredSettings: false))
        // Someone who used the app before the guide existed.
        #expect(!FirstLaunch.shouldWelcome(hasSeenWelcome: false, hasStoredSettings: true))
    }

    @Test func scrollModeOptionsKeepTheirDefaultsAndBounds() throws {
        var settings = Settings()
        #expect(!settings.arrowKeysScroll)
        #expect(settings.showScrollAreaNumbers)
        #expect(settings.scrollIdleTimeout == 0)

        settings.arrowKeysScroll = true
        settings.showScrollAreaNumbers = false
        settings.scrollIdleTimeout = 5
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)).validated()
        #expect(decoded.arrowKeysScroll)
        #expect(!decoded.showScrollAreaNumbers)
        #expect(decoded.scrollIdleTimeout == 5)

        settings.scrollIdleTimeout = -3
        #expect(settings.validated().scrollIdleTimeout == 0)
    }

    @Test func anApplicationOverridesOnlyWhatItNames() {
        var settings = Settings()
        settings.visionMode = .always
        settings.appOverrides = ["org.mozilla.firefox": AppOverride(visionMode: .off, compatibilityMode: true)]

        let firefox = settings.resolved(for: "org.mozilla.firefox")
        #expect(firefox.visionMode == .off)
        #expect(firefox.compatibilityMode)
        #expect(!firefox.iconDetection)
        // Everything else is the general setting.
        #expect(firefox.hintAlphabet == settings.hintAlphabet)

        #expect(settings.resolved(for: "com.apple.Safari") == settings)
        #expect(settings.resolved(for: nil) == settings)
    }

    @Test func overridesThatChangeNothingAreNotKept() throws {
        var settings = Settings()
        #expect(!settings.compatibilityMode)
        settings.appOverrides = ["a": AppOverride(), "  ": AppOverride(iconDetection: true), "b": AppOverride(iconDetection: false)]
        #expect(settings.validated().appOverrides == ["b": AppOverride(iconDetection: false)])

        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings.validated()))
        #expect(decoded.appOverrides == ["b": AppOverride(iconDetection: false)])
    }

    @Test func shortcutDisplayAndMatching() {
        let shortcut = Shortcut(keyCode: KeyCode.space, modifiers: [.command, .shift])
        #expect(shortcut.displayString == "⇧⌘Space")
        #expect(Shortcut(keyCode: 3, modifiers: [.control, .option]).displayString == "⌃⌥F")
        #expect(shortcut.matches(KeyStroke(keyCode: KeyCode.space, modifiers: [.command, .shift])))
        #expect(!shortcut.matches(KeyStroke(keyCode: KeyCode.space, modifiers: .command)))
    }

    @Test func decodingAnOlderDocumentKeepsDefaultsForMissingFields() throws {
        let json = Data(#"{"scrollSpeed": 35}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: json)
        #expect(settings.scrollSpeed == 35)
        #expect(settings.hintAlphabet == HintLabelGenerator.defaultAlphabet)
    }
}
