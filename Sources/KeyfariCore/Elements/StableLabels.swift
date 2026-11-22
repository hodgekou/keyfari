// SPDX-License-Identifier: GPL-3.0-only
/// Keeps the label of an element the same from one activation to the next.
public enum StableLabels {
    /// A key that identifies an element across activations, or nil when it has no text to tell it apart.
    public static func fingerprint(of element: ElementSnapshot) -> String? {
        let text = SearchSession.normalize(element.searchText)
        if let stableIdentity = element.stableIdentity, !stableIdentity.isEmpty {
            return "\(stableIdentity)|\(element.role)|\(text)"
        }
        guard !text.isEmpty else { return nil }
        return "\(element.role)|\(text)"
    }

    /// Generates labels for `fingerprints.count` elements, giving each element its remembered
    /// label when that label exists in the generated set and is still free.
    ///
    /// Fixed labels take priority; generated and remembered labels avoid every fixed-label prefix.
    public static func assign(
        fingerprints: [String?],
        alphabet: String,
        memory: [String: String],
        pinned: [String: String] = [:]
    ) -> [String] {
        var result = [String?](repeating: nil, count: fingerprints.count)
        var fingerprintCounts: [String: Int] = [:]
        for fingerprint in fingerprints.compactMap({ $0 }) {
            fingerprintCounts[fingerprint, default: 0] += 1
        }

        var usedPins: [String] = []
        for (index, fingerprint) in fingerprints.enumerated() {
            guard let fingerprint, fingerprintCounts[fingerprint] == 1,
                let label = pinned[fingerprint], label.allSatisfy({ alphabet.lowercased().contains($0.lowercased()) }),
                !usedPins.contains(where: { $0.hasPrefix(label) || label.hasPrefix($0) })
            else { continue }
            result[index] = label
            usedPins.append(label)
        }

        let remainingCount = result.filter { $0 == nil }.count
        let generated = availableLabels(count: remainingCount, alphabet: alphabet, avoiding: usedPins)
        var free = Set(generated)

        for (index, fingerprint) in fingerprints.enumerated() {
            guard result[index] == nil else { continue }
            guard let fingerprint, let remembered = memory[fingerprint], free.remove(remembered) != nil else { continue }
            result[index] = remembered
        }

        var remaining = generated.filter(free.contains).makeIterator()
        return result.map { $0 ?? remaining.next() ?? "" }
    }

    private static func availableLabels(count: Int, alphabet: String, avoiding reserved: [String]) -> [String] {
        guard count > 0 else { return [] }
        var candidateCount = count + reserved.count + 1
        for _ in 0..<8 {
            let candidates = HintLabelGenerator.labels(count: candidateCount, alphabet: alphabet)
                .filter { candidate in
                    !reserved.contains { $0.hasPrefix(candidate) || candidate.hasPrefix($0) }
                }
            if candidates.count >= count { return Array(candidates.prefix(count)) }
            candidateCount = max(candidateCount * 2, count + reserved.count + 1)
        }
        return []
    }
}
