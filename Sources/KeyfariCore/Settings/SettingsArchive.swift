// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// The settings and the remembered labels as one file, for taking them to another Mac.
/// The usage statistics are not part of it.
public struct SettingsArchive: Codable, Equatable, Sendable {
    /// The newest layout this version writes and reads.
    public static let currentFormat = 1
    /// A file larger than this is not one of ours.
    public static let maximumSize = 5_000_000
    private static let maximumLabels = 2000

    public enum ReadError: Error, Equatable {
        case tooLarge
        /// Not a settings file at all.
        case unreadable
        /// Written by a newer version, in a layout this one does not know.
        case newerFormat(Int)
    }

    public var format: Int
    public var settings: Settings
    public var stableLabels: [StableLabelEntry]

    public init(settings: Settings, stableLabels: [StableLabelEntry]) {
        format = Self.currentFormat
        self.settings = settings
        self.stableLabels = stableLabels
    }

    /// The file's contents: JSON that a person can read and compare.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads a file written by `encoded()`. What comes back is safe to use: out-of-range
    /// settings are back at their defaults, and labels that could not have been written by
    /// this app are dropped.
    public static func read(_ data: Data) throws -> SettingsArchive {
        guard data.count <= maximumSize else { throw ReadError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // The format is read on its own first, so a newer file is recognised as such
        // rather than as broken.
        struct Header: Decodable { let format: Int }
        guard let header = try? decoder.decode(Header.self, from: data) else { throw ReadError.unreadable }
        guard header.format <= currentFormat else { throw ReadError.newerFormat(header.format) }
        guard header.format >= 1, var archive = try? decoder.decode(SettingsArchive.self, from: data) else {
            throw ReadError.unreadable
        }

        archive.settings = archive.settings.validated()
        var seen = Set<String>()
        archive.stableLabels = archive.stableLabels
            .filter { entry in
                !entry.bundleID.isEmpty && !entry.fingerprint.isEmpty && entry.useCount >= 0
                    && (1...6).contains(entry.label.count) && entry.label.allSatisfy { $0.isLetter && $0.isUppercase }
                    && entry.title.count <= 200 && seen.insert(entry.id).inserted
            }
            .prefix(maximumLabels)
            .map { $0 }
        return archive
    }
}
