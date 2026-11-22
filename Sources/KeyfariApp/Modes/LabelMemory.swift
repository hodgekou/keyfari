// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KeyfariCore
import Observation

/// Keeps the remembered labels in the user defaults. The rules live in `StableLabelBook`.
@MainActor
@Observable
final class LabelMemory {
    private static let key = "stableLabels"
    /// Keys of the two stores this one replaces. Their fingerprints no longer match anything.
    private static let obsoleteKeys = ["labelMemory", "pinnedLabelBindings"]

    @ObservationIgnored
    private let defaults: UserDefaults
    private(set) var book: StableLabelBook

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = (try? JSONDecoder().decode([StableLabelEntry].self, from: defaults.data(forKey: Self.key) ?? Data())) ?? []
        book = StableLabelBook(entries: stored)
        Self.obsoleteKeys.forEach(defaults.removeObject(forKey:))
    }

    /// Notes that `element` was just clicked under `label`.
    func remember(_ label: String, for element: ElementSnapshot, bundleID: String) {
        if book.remember(label, for: element, bundleID: bundleID, now: .now) { save() }
    }

    /// Gives an element the label the user typed. Returns what is wrong with it, or nil when it was saved.
    func setCustomLabel(_ label: String, id: String, alphabet: String) -> StableLabels.CustomLabelProblem? {
        let problem = book.setCustomLabel(label, id: id, alphabet: alphabet)
        if problem == nil { save() }
        return problem
    }

    func remove(id: String) {
        book.remove(id: id)
        save()
    }

    /// Replaces every remembered label, as when settings are imported.
    func replaceAll(with entries: [StableLabelEntry]) {
        book = StableLabelBook(entries: entries)
        save()
    }

    func removeAll() {
        book.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(book.entries) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
