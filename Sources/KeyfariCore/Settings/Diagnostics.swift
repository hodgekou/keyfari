// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Foundation

/// What a bug report needs to know about the Mac and the app, as plain text for the clipboard.
///
/// It names the settings that differ from their defaults but none of their contents: no
/// application names, no labels, no statistics.
public struct Diagnostics: Sendable {
    public var appVersion: String
    public var systemVersion: String
    public var architecture: String
    /// The size of each display in points.
    public var displays: [CGSize]
    public var hasAccessibility: Bool
    public var hasScreenRecording: Bool
    public var installsUpdates: Bool
    public var settings: Settings

    public init(
        appVersion: String, systemVersion: String, architecture: String, displays: [CGSize],
        hasAccessibility: Bool, hasScreenRecording: Bool, installsUpdates: Bool, settings: Settings
    ) {
        self.appVersion = appVersion
        self.systemVersion = systemVersion
        self.architecture = architecture
        self.displays = displays
        self.hasAccessibility = hasAccessibility
        self.hasScreenRecording = hasScreenRecording
        self.installsUpdates = installsUpdates
        self.settings = settings
    }

    /// The names of the settings whose value is not the default, in alphabetical order.
    public static func changedSettings(_ settings: Settings) -> [String] {
        func fields(_ value: Settings) -> [String: String] {
            guard let data = try? JSONEncoder().encode(value),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return [:] }
            // Compared as text: the values themselves never leave this function.
            return object.mapValues { String(describing: $0) }
        }
        let current = fields(settings)
        let standard = fields(Settings())
        return Set(current.keys).union(standard.keys).filter { current[$0] != standard[$0] }.sorted()
    }

    public var report: String {
        let changed = Self.changedSettings(settings)
        let screens = displays.map { "\(Int($0.width))×\(Int($0.height))" }.joined(separator: ", ")
        return [
            "Keyfari \(appVersion)",
            "macOS \(systemVersion), \(architecture)",
            "Displays: \(displays.count) (\(screens))",
            "Accessibility permission: \(hasAccessibility ? "granted" : "not granted")",
            "Screen Recording permission: \(hasScreenRecording ? "granted" : "not granted")",
            "Installs updates: \(installsUpdates ? "yes" : "no")",
            "Language: \(settings.language.rawValue)",
            "Text detection: \(settings.visionMode.rawValue)",
            "Settings changed from their defaults: \(changed.isEmpty ? "none" : changed.joined(separator: ", "))",
        ].joined(separator: "\n")
    }
}
