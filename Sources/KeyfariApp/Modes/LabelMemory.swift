// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KeyfariCore
import Observation

struct PinnedLabelBinding: Codable, Identifiable, Equatable {
    var bundleID: String
    var fingerprint: String
    var label: String
    var targetDescription: String
    var id: String { "\(bundleID)|\(fingerprint)" }
}

enum PinResult {
    case saved
    case unsupported
    case ambiguous
    case conflict
}

/// Remembers which label each clicked element had, per application.
@MainActor
@Observable
final class LabelMemory {
    private static let key = "labelMemory"
    private static let pinsKey = "pinnedLabelBindings"
    private static let capacity = 3000

    @ObservationIgnored
    private let defaults: UserDefaults
    @ObservationIgnored
    private var labels: [String: String]
    private(set) var pinnedBindings: [PinnedLabelBinding]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        labels = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
        pinnedBindings = (try? JSONDecoder().decode([PinnedLabelBinding].self, from: defaults.data(forKey: Self.pinsKey) ?? Data())) ?? []
    }

    /// Labels for `elements`, reusing remembered ones where possible.
    /// `reserve` extra labels follow, for elements that are not known yet.
    func assign(to elements: [ElementSnapshot], bundleID: String, alphabet: String, reserve: Int = 0, keepAutomatic: Bool) -> [String] {
        StableLabels.assign(
            fingerprints: elements.map { key(for: $0, bundleID: bundleID) } + [String?](repeating: nil, count: reserve),
            alphabet: alphabet,
            memory: keepAutomatic ? labels : [:],
            pinned: Dictionary(
                pinnedBindings.filter { $0.bundleID == bundleID }.map { ("\(bundleID)|\($0.fingerprint)", $0.label) },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }

    func pin(_ label: String, element: ElementSnapshot, elements: [ElementSnapshot], bundleID: String, alphabet: String) -> PinResult {
        guard element.source == .window, let fingerprint = StableLabels.fingerprint(of: element),
            element.stableIdentity != nil, !bundleID.isEmpty
        else { return .unsupported }
        let count = elements.filter { StableLabels.fingerprint(of: $0) == fingerprint }.count
        guard count == 1 else { return .ambiguous }
        let normalizedLabel = label.uppercased()
        guard normalizedLabel.allSatisfy({ alphabet.uppercased().contains($0) }) else { return .unsupported }
        let conflict = pinnedBindings.contains {
            $0.bundleID == bundleID && $0.fingerprint != fingerprint
                && ($0.label.hasPrefix(normalizedLabel) || normalizedLabel.hasPrefix($0.label))
        }
        guard !conflict else { return .conflict }
        let key = "\(bundleID)|\(fingerprint)"
        pinnedBindings.removeAll { $0.id == key }
        pinnedBindings.append(
            PinnedLabelBinding(
                bundleID: bundleID,
                fingerprint: fingerprint,
                label: normalizedLabel,
                targetDescription: element.searchText.isEmpty ? element.role : element.searchText
            ))
        savePins()
        return .saved
    }

    func removePin(id: String) {
        pinnedBindings.removeAll { $0.id == id }
        savePins()
    }

    private func savePins() {
        guard let data = try? JSONEncoder().encode(pinnedBindings) else { return }
        defaults.set(data, forKey: Self.pinsKey)
    }

    func remember(_ label: String, for element: ElementSnapshot, bundleID: String) {
        guard let key = key(for: element, bundleID: bundleID), labels[key] != label else { return }
        // Simple bound: starting over is cheaper than tracking which entries are oldest.
        if labels.count >= Self.capacity { labels.removeAll() }
        labels[key] = label
        defaults.set(labels, forKey: Self.key)
    }

    private func key(for element: ElementSnapshot, bundleID: String) -> String? {
        StableLabels.fingerprint(of: element).map { "\(bundleID)|\($0)" }
    }
}
