// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// The label one element of one application keeps.
public struct StableLabelEntry: Codable, Identifiable, Equatable, Sendable {
    public var bundleID: String
    public var fingerprint: String
    public var label: String
    /// What the element is, for the list in the settings.
    public var title: String
    /// Whether the user chose the label, rather than it being the one the element happened to have.
    public var isCustom: Bool
    public var lastUsed: Date
    /// How many times the element was clicked by its label.
    public var useCount: Int

    public var id: String { "\(bundleID)|\(fingerprint)" }

    public init(bundleID: String, fingerprint: String, label: String, title: String, isCustom: Bool, lastUsed: Date, useCount: Int) {
        self.bundleID = bundleID
        self.fingerprint = fingerprint
        self.label = label
        self.title = title
        self.isCustom = isCustom
        self.lastUsed = lastUsed
        self.useCount = useCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        label = try container.decode(String.self, forKey: .label)
        title = try container.decode(String.self, forKey: .title)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        lastUsed = try container.decode(Date.self, forKey: .lastUsed)
        // An entry written before uses were counted exists because of one click at least.
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 1
    }
}

/// The remembered labels of every application, and the rules for changing them.
public struct StableLabelBook: Equatable, Sendable {
    public private(set) var entries: [StableLabelEntry]
    /// The most entries kept. Beyond it, the ones unused longest go first.
    public let capacity: Int

    public init(entries: [StableLabelEntry] = [], capacity: Int = 2000) {
        self.entries = entries
        self.capacity = capacity
    }

    /// The entries with the most used first; of two used equally often, the one used last comes first.
    public var byUse: [StableLabelEntry] {
        entries.sorted { lhs, rhs in
            lhs.useCount == rhs.useCount ? lhs.lastUsed > rhs.lastUsed : lhs.useCount > rhs.useCount
        }
    }

    /// Labels for `elements`, reusing chosen and remembered ones where possible.
    /// `reserve` extra labels follow, for elements that are not known yet.
    /// - Parameters:
    ///   - bundleIDs: the application each element belongs to, one per element.
    ///   - useMemory: false hands out fresh labels, as when stable labels are switched off.
    ///   - excludedLead: a letter no label may start with; see `StableLabels.assign`.
    public func assign(
        to elements: [ElementSnapshot],
        bundleIDs: [String],
        alphabet: String,
        reserve: Int = 0,
        useMemory: Bool = true,
        excludedLead: Character? = nil
    ) -> [String] {
        var memory: [String: String] = [:]
        var custom: [String: String] = [:]
        if useMemory {
            let involved = Set(bundleIDs)
            for entry in entries where involved.contains(entry.bundleID) {
                if entry.isCustom {
                    custom[entry.id] = entry.label
                } else {
                    memory[entry.id] = entry.label
                }
            }
        }
        // The same text in two applications is two different elements, so the application is part of the key.
        let fingerprints = zip(elements, bundleIDs).map { element, bundleID in
            StableLabels.fingerprint(of: element).map { "\(bundleID)|\($0)" }
        }
        return StableLabels.assign(
            fingerprints: fingerprints + [String?](repeating: nil, count: reserve),
            alphabet: alphabet,
            memory: memory,
            custom: custom,
            excludedLead: excludedLead
        )
    }

    /// Notes that `element` was just clicked under `label`. Returns false when the element
    /// cannot be told apart and nothing was noted.
    @discardableResult
    public mutating func remember(_ label: String, for element: ElementSnapshot, bundleID: String, now: Date) -> Bool {
        guard !bundleID.isEmpty, let fingerprint = StableLabels.fingerprint(of: element) else { return false }
        if let index = entries.firstIndex(where: { $0.bundleID == bundleID && $0.fingerprint == fingerprint }) {
            // A chosen label stays, even if the element showed another one this time.
            if !entries[index].isCustom { entries[index].label = label }
            entries[index].lastUsed = now
            entries[index].useCount += 1
            return true
        }

        let text = element.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = element.role.hasPrefix("AX") ? String(element.role.dropFirst(2)) : element.role
        entries.append(
            StableLabelEntry(
                bundleID: bundleID,
                fingerprint: fingerprint,
                label: label,
                title: text.isEmpty ? role : String(text.prefix(80)),
                isCustom: false,
                lastUsed: now,
                useCount: 1
            ))
        trim()
        return true
    }

    /// Gives an element the label the user typed. Returns what is wrong with it, or nil when it was saved.
    public mutating func setCustomLabel(_ label: String, id: String, alphabet: String) -> StableLabels.CustomLabelProblem? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let others = entries.filter { $0.isCustom && $0.bundleID == entries[index].bundleID && $0.id != id }.map(\.label)
        if let problem = StableLabels.problem(withCustomLabel: label, alphabet: alphabet, otherCustomLabels: others) {
            return problem
        }
        entries[index].label = label
        entries[index].isCustom = true
        return nil
    }

    public mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    /// Drops the labels that went unused longest once there are too many. Chosen labels stay.
    private mutating func trim() {
        let excess = entries.count - capacity
        guard excess > 0 else { return }
        let dropped = Set(entries.filter { !$0.isCustom }.sorted { $0.lastUsed < $1.lastUsed }.prefix(excess).map(\.id))
        entries.removeAll { dropped.contains($0.id) }
    }
}
