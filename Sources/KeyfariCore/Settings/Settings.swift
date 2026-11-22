// SPDX-License-Identifier: GPL-3.0-only
/// When on-screen text recognition adds labels.
public enum VisionMode: String, Codable, Sendable, CaseIterable {
    case off
    /// Only when the accessibility tree of the window is nearly empty.
    case fallback
    case always
}

public enum HintTheme: String, Codable, Sendable, CaseIterable {
    /// Each label takes one of several bright colours.
    case vivid
    case yellow
    case dark
    case light
    case liquidGlass

    public var isAvailable: Bool {
        switch self {
        case .liquidGlass:
            if #available(macOS 26.0, *) { return true }
            return false
        case .vivid, .yellow, .dark, .light:
            return true
        }
    }

    public static var available: [HintTheme] {
        allCases.filter(\.isAvailable)
    }
}

/// What one application does differently from the general settings. Nil follows the general setting.
public struct AppOverride: Codable, Equatable, Sendable {
    public var visionMode: VisionMode?
    public var iconDetection: Bool?
    public var compatibilityMode: Bool?

    public init(visionMode: VisionMode? = nil, iconDetection: Bool? = nil, compatibilityMode: Bool? = nil) {
        self.visionMode = visionMode
        self.iconDetection = iconDetection
        self.compatibilityMode = compatibilityMode
    }

    /// Whether it changes nothing, in which case it need not be kept.
    public var isEmpty: Bool {
        visionMode == nil && iconDetection == nil && compatibilityMode == nil
    }
}

/// User preferences. Stored as one JSON document.
public struct Settings: Codable, Equatable, Sendable {
    public var hintAlphabet = HintLabelGenerator.defaultAlphabet
    public var hintFontSize = 11.0
    public var hintTheme = HintTheme.vivid
    public var hintCornerRadius = 5.0
    public var hintShortcut = Shortcut(keyCode: KeyCode.space, modifiers: [.command, .shift])
    public var searchShortcut = Shortcut(keyCode: KeyCode.slash, modifiers: [.command, .shift])
    public var scrollShortcut = Shortcut(keyCode: KeyCode.j, modifiers: [.command, .shift])
    /// Shortcuts that go one Space to the left or right. Nil means off.
    public var previousSpaceShortcut: Shortcut?
    public var nextSpaceShortcut: Shortcut?
    /// Clicks the element that was clicked last through a label once more. Nil means off.
    public var repeatClickShortcut: Shortcut?
    /// Show labels in Mission Control as soon as it opens, without pressing the hint shortcut.
    public var missionControlAutoHints = false
    /// Keep the mode open after a click so several elements can be clicked in a row.
    public var chainClicks = false
    /// Label every visible window on every display, not only the focused one.
    public var hintAllWindows = true
    /// Label the icons in the Dock.
    public var hintDock = true
    /// Give an element the label it had the last time it was clicked.
    public var stableLabels = true
    public var visionMode = VisionMode.always
    /// Also label shapes in the window's pixels that look like icon buttons. Experimental.
    public var iconDetection = false
    public var language = AppLanguage.system
    /// Tell applications that an assistive app is present, which some need before they expose
    /// their interface. It can disturb window managers, so it is off unless asked for.
    public var compatibilityMode = false
    /// Settings that single applications override, by bundle identifier.
    public var appOverrides: [String: AppOverride] = [:]
    /// Collect aggregate usage counts on this Mac only.
    public var usageStatisticsEnabled = true
    public var successSoundEnabled = false
    public var warningSoundEnabled = false
    /// Four letters that scroll left, down, up and right.
    public var scrollKeys = ScrollKeys.standardScroll
    /// Two letters that scroll half a page down and up.
    public var halfPageKeys = ScrollKeys.standardHalfPage
    /// Whether the arrow keys scroll, instead of going from one scroll area to the next.
    public var arrowKeysScroll = false
    /// Show each scroll area's number next to its outline.
    public var showScrollAreaNumbers = true
    /// Leave scroll mode after this many seconds without a key. Zero means never.
    public var scrollIdleTimeout = 0.0
    /// Pixels scrolled per frame while a scroll key is held.
    public var scrollSpeed = 20
    /// Speed factor applied while Shift is held.
    public var dashMultiplier = 3.0
    public var reverseHorizontal = false
    public var reverseVertical = false
    /// Bundle identifiers of applications in which no mode activates.
    public var ignoredBundleIDs: [String] = []
    public var launchAtLogin = false
    /// Show the icon in the menu bar. Hidden, the settings are reached by opening the app again.
    public var showMenuBarIcon = true
    /// Look for a newer version once a day.
    public var updateCheckEnabled = true

    public init() {}

    // Decodes field by field so that a document written by an older version keeps its values.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        hintAlphabet = try container.decodeIfPresent(String.self, forKey: .hintAlphabet) ?? fallback.hintAlphabet
        hintFontSize = try container.decodeIfPresent(Double.self, forKey: .hintFontSize) ?? fallback.hintFontSize
        hintTheme = (try? container.decodeIfPresent(HintTheme.self, forKey: .hintTheme)) ?? fallback.hintTheme
        hintCornerRadius = try container.decodeIfPresent(Double.self, forKey: .hintCornerRadius) ?? fallback.hintCornerRadius
        hintShortcut = (try? container.decodeIfPresent(Shortcut.self, forKey: .hintShortcut)) ?? fallback.hintShortcut
        searchShortcut = (try? container.decodeIfPresent(Shortcut.self, forKey: .searchShortcut)) ?? fallback.searchShortcut
        scrollShortcut = (try? container.decodeIfPresent(Shortcut.self, forKey: .scrollShortcut)) ?? fallback.scrollShortcut
        previousSpaceShortcut = try? container.decodeIfPresent(Shortcut.self, forKey: .previousSpaceShortcut)
        nextSpaceShortcut = try? container.decodeIfPresent(Shortcut.self, forKey: .nextSpaceShortcut)
        repeatClickShortcut = try? container.decodeIfPresent(Shortcut.self, forKey: .repeatClickShortcut)
        missionControlAutoHints = try container.decodeIfPresent(Bool.self, forKey: .missionControlAutoHints) ?? fallback.missionControlAutoHints
        chainClicks = try container.decodeIfPresent(Bool.self, forKey: .chainClicks) ?? fallback.chainClicks
        hintAllWindows = try container.decodeIfPresent(Bool.self, forKey: .hintAllWindows) ?? fallback.hintAllWindows
        hintDock = try container.decodeIfPresent(Bool.self, forKey: .hintDock) ?? fallback.hintDock
        stableLabels = try container.decodeIfPresent(Bool.self, forKey: .stableLabels) ?? fallback.stableLabels
        visionMode = (try? container.decodeIfPresent(VisionMode.self, forKey: .visionMode)) ?? fallback.visionMode
        iconDetection = try container.decodeIfPresent(Bool.self, forKey: .iconDetection) ?? fallback.iconDetection
        compatibilityMode = try container.decodeIfPresent(Bool.self, forKey: .compatibilityMode) ?? fallback.compatibilityMode
        appOverrides = (try? container.decodeIfPresent([String: AppOverride].self, forKey: .appOverrides)) ?? fallback.appOverrides
        language = (try? container.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? fallback.language
        usageStatisticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .usageStatisticsEnabled) ?? fallback.usageStatisticsEnabled
        successSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .successSoundEnabled) ?? fallback.successSoundEnabled
        warningSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .warningSoundEnabled) ?? fallback.warningSoundEnabled
        scrollKeys = try container.decodeIfPresent(String.self, forKey: .scrollKeys) ?? fallback.scrollKeys
        halfPageKeys = try container.decodeIfPresent(String.self, forKey: .halfPageKeys) ?? fallback.halfPageKeys
        arrowKeysScroll = try container.decodeIfPresent(Bool.self, forKey: .arrowKeysScroll) ?? fallback.arrowKeysScroll
        showScrollAreaNumbers = try container.decodeIfPresent(Bool.self, forKey: .showScrollAreaNumbers) ?? fallback.showScrollAreaNumbers
        scrollIdleTimeout = try container.decodeIfPresent(Double.self, forKey: .scrollIdleTimeout) ?? fallback.scrollIdleTimeout
        scrollSpeed = try container.decodeIfPresent(Int.self, forKey: .scrollSpeed) ?? fallback.scrollSpeed
        dashMultiplier = try container.decodeIfPresent(Double.self, forKey: .dashMultiplier) ?? fallback.dashMultiplier
        reverseHorizontal = try container.decodeIfPresent(Bool.self, forKey: .reverseHorizontal) ?? fallback.reverseHorizontal
        reverseVertical = try container.decodeIfPresent(Bool.self, forKey: .reverseVertical) ?? fallback.reverseVertical
        ignoredBundleIDs = try container.decodeIfPresent([String].self, forKey: .ignoredBundleIDs) ?? fallback.ignoredBundleIDs
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? fallback.showMenuBarIcon
        updateCheckEnabled = try container.decodeIfPresent(Bool.self, forKey: .updateCheckEnabled) ?? fallback.updateCheckEnabled
    }

    /// Where the shortcut that changes the Space in `direction` is stored.
    public static func spaceShortcut(_ direction: SpaceDirection) -> WritableKeyPath<Settings, Shortcut?> {
        switch direction {
        case .previous: \.previousSpaceShortcut
        case .next: \.nextSpaceShortcut
        }
    }

    /// The settings in force while the application `bundleID` is in front: the general ones
    /// with that application's overrides on top.
    public func resolved(for bundleID: String?) -> Settings {
        guard let bundleID, let override = appOverrides[bundleID] else { return self }
        var result = self
        if let visionMode = override.visionMode { result.visionMode = visionMode }
        if let iconDetection = override.iconDetection { result.iconDetection = iconDetection }
        if let compatibilityMode = override.compatibilityMode { result.compatibilityMode = compatibilityMode }
        return result
    }

    /// A copy in which every out-of-range value is replaced by its default.
    public func validated() -> Settings {
        let fallback = Settings()
        var result = self

        let alphabet = hintAlphabet.lowercased()
        result.hintAlphabet =
            HintLabelGenerator.isValid(alphabet: alphabet) && alphabet.allSatisfy(\.isLetter)
            ? alphabet
            : fallback.hintAlphabet
        if !(8...32).contains(hintFontSize) { result.hintFontSize = fallback.hintFontSize }
        if !(0...10).contains(hintCornerRadius) { result.hintCornerRadius = fallback.hintCornerRadius }

        // Shortcuts must be distinct and carry a real modifier; otherwise all three return to their defaults.
        let shortcuts = [hintShortcut, searchShortcut, scrollShortcut]
        if Set(shortcuts).count != shortcuts.count || !shortcuts.allSatisfy(\.isUsable) {
            result.hintShortcut = fallback.hintShortcut
            result.searchShortcut = fallback.searchShortcut
            result.scrollShortcut = fallback.scrollShortcut
        }
        // An optional shortcut that is unusable or already taken is switched off; the modes come first.
        var taken = Set([result.hintShortcut, result.searchShortcut, result.scrollShortcut])
        for keyPath in SpaceDirection.allCases.map(Self.spaceShortcut) + [\.repeatClickShortcut] {
            guard let shortcut = self[keyPath: keyPath] else { continue }
            if !shortcut.isUsable || !taken.insert(shortcut).inserted {
                result[keyPath: keyPath] = nil
            }
        }
        // The two sets of scroll keys only make sense together.
        if ScrollKeys(scroll: scrollKeys, halfPage: halfPageKeys) == nil {
            result.scrollKeys = fallback.scrollKeys
            result.halfPageKeys = fallback.halfPageKeys
        } else {
            result.scrollKeys = scrollKeys.lowercased()
            result.halfPageKeys = halfPageKeys.lowercased()
        }
        if !(0...60).contains(scrollIdleTimeout) { result.scrollIdleTimeout = fallback.scrollIdleTimeout }
        if !(1...100).contains(scrollSpeed) { result.scrollSpeed = fallback.scrollSpeed }
        if !(0.25...10).contains(dashMultiplier) { result.dashMultiplier = fallback.dashMultiplier }
        // An override that changes nothing, or belongs to no application, is not kept.
        result.appOverrides = appOverrides.filter { !$0.key.filter { !$0.isWhitespace }.isEmpty && !$0.value.isEmpty }

        var seen = Set<String>()
        result.ignoredBundleIDs =
            ignoredBundleIDs
            .map { $0.filter { !$0.isWhitespace } }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return result
    }
}
