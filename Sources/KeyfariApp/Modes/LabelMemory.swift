// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KeyfariCore
import Observation

/// The label one element of one application keeps.
struct StableLabel: Codable, Identifiable, Equatable {
    var bundleID: String
    var fingerprint: String
    var label: String
    /// What the element is, for the list in the settings.
    var title: String
    /// Whether the user chose the label, rather than it being the one the element happened to have.
    var isCustom: Bool
    var lastUsed: Date

    var id: String { "\(bundleID)|\(fingerprint)" }
}

/// Remembers which label each clicked element had, per application, and the labels the user chose instead.
@MainActor
@Observable
final class LabelMemory {
    private static let key = "stableLabels"
    /// Keys of the two stores this one replaces. Their fingerprints no longer match anything.
    private static let obsoleteKeys = ["labelMemory", "pinnedLabelBindings"]
    private static let capacity = 2000

    @ObservationIgnored
    private let defaults: UserDefaults
    private(set) var entries: [StableLabel]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = (try? JSONDecoder().decode([StableLabel].self, from: defaults.data(forKey: Self.key) ?? Data())) ?? []
        Self.obsoleteKeys.forEach(defaults.removeObject(forKey:))
    }

    /// Labels for `elements`, reusing chosen and remembered ones where possible.
    /// `reserve` extra labels follow, for elements that are not known yet.
    /// - Parameters:
    ///   - bundleIDs: the application each element belongs to, one per element.
    ///   - useMemory: false hands out fresh labels, as when stable labels are switched off.
    ///   - excludedLead: a letter no label may start with; see `StableLabels.assign`.
    func assign(
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

    /// Notes that `element` was just used under `label`.
    func remember(_ label: String, for element: ElementSnapshot, bundleID: String) {
        guard !bundleID.isEmpty, let fingerprint = StableLabels.fingerprint(of: element) else { return }
        if let index = entries.firstIndex(where: { $0.bundleID == bundleID && $0.fingerprint == fingerprint }) {
            // A chosen label stays, even if the element showed another one this time.
            if !entries[index].isCustom { entries[index].label = label }
            entries[index].lastUsed = .now
        } else {
            let text = element.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(
                StableLabel(
                    bundleID: bundleID,
                    fingerprint: fingerprint,
                    label: label,
                    title: text.isEmpty ? String(element.role.trimmingPrefix("AX")) : String(text.prefix(80)),
                    isCustom: false,
                    lastUsed: .now
                ))
            trim()
        }
        save()
    }

    /// Gives an element the label the user typed. Returns what is wrong with it, or nil when it was saved.
    func setCustomLabel(_ label: String, id: String, alphabet: String) -> StableLabels.CustomLabelProblem? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let others = entries.filter { $0.isCustom && $0.bundleID == entries[index].bundleID && $0.id != id }.map(\.label)
        if let problem = StableLabels.problem(withCustomLabel: label, alphabet: alphabet, otherCustomLabels: others) {
            return problem
        }
        entries[index].label = label
        entries[index].isCustom = true
        save()
        return nil
    }

    func remove(id: String) {
        entries.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        entries.removeAll()
        save()
    }

    /// Drops the labels that went unused longest once there are too many. Chosen labels stay.
    private func trim() {
        let excess = entries.count - Self.capacity
        guard excess > 0 else { return }
        let oldest = entries.filter { !$0.isCustom }.sorted { $0.lastUsed < $1.lastUsed }.prefix(excess).map(\.id)
        let dropped = Set(oldest)
        entries.removeAll { dropped.contains($0.id) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
