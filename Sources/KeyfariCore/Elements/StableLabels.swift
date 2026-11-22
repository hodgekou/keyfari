// SPDX-License-Identifier: GPL-3.0-only
/// Keeps the label of an element the same from one activation to the next.
public enum StableLabels {
    /// The longest label a user may choose for an element.
    public static let maximumCustomLength = 3

    /// A key that identifies an element across activations, or nil when nothing tells it apart.
    ///
    /// An element with text is known by its role and that text, wherever it sits: the window
    /// title, the open document or a banner above it must not make it a different element.
    /// One without text, such as a toolbar icon, is known by its place in the window instead.
    public static func fingerprint(of element: ElementSnapshot) -> String? {
        let text = SearchSession.normalize(element.searchText)
        if !text.isEmpty { return "\(element.role)|\(text)" }
        if let path = element.stableIdentity, !path.isEmpty { return "\(element.role)@\(path)" }
        return nil
    }

    /// Generates labels for `fingerprints.count` elements.
    ///
    /// An element with a label the user chose gets that label. Otherwise it gets its remembered
    /// label when that one is in the generated set and still free. Where several elements share
    /// a fingerprint the first one wins. Generated labels avoid every chosen label, so no label
    /// on screen is the beginning of another.
    /// - Parameters:
    ///   - memory: the label each fingerprint had when it was last used.
    ///   - custom: the labels the user chose, by fingerprint. They take priority over `memory`.
    public static func assign(
        fingerprints: [String?],
        alphabet: String,
        memory: [String: String],
        custom: [String: String] = [:]
    ) -> [String] {
        var result = [String?](repeating: nil, count: fingerprints.count)
        let letters = Set(alphabet.uppercased())

        var chosen: [String] = []
        var seen = Set<String>()
        for (index, fingerprint) in fingerprints.enumerated() {
            guard let fingerprint, let label = custom[fingerprint], seen.insert(fingerprint).inserted,
                !label.isEmpty, label.allSatisfy(letters.contains),
                !chosen.contains(where: { $0.hasPrefix(label) || label.hasPrefix($0) })
            else { continue }
            result[index] = label
            chosen.append(label)
        }

        let remainingCount = result.filter { $0 == nil }.count
        let generated = availableLabels(count: remainingCount, alphabet: alphabet, avoiding: chosen)
        var free = Set(generated)

        for (index, fingerprint) in fingerprints.enumerated() {
            guard result[index] == nil else { continue }
            guard let fingerprint, let remembered = memory[fingerprint], free.remove(remembered) != nil else { continue }
            result[index] = remembered
        }

        var remaining = generated.filter(free.contains).makeIterator()
        return result.map { $0 ?? remaining.next() ?? "" }
    }

    public enum CustomLabelProblem: Equatable, Sendable {
        case empty
        case tooLong
        /// It uses a character that is not among the label characters.
        case notInAlphabet
        /// It begins another chosen label of the same application, or the other way round,
        /// so one of the two could never be typed.
        case conflicts(with: String)
    }

    /// Brings typed text into the form of a label: uppercase letters only.
    public static func normalized(customLabel text: String) -> String {
        String(text.uppercased().filter(\.isLetter))
    }

    /// Why `label` cannot be chosen for an element, or nil when it can.
    /// - Parameter otherCustomLabels: the labels chosen for the other elements of the same application.
    public static func problem(withCustomLabel label: String, alphabet: String, otherCustomLabels: [String]) -> CustomLabelProblem? {
        guard !label.isEmpty else { return .empty }
        guard label.count <= maximumCustomLength else { return .tooLong }
        let letters = Set(alphabet.uppercased())
        guard label.allSatisfy(letters.contains) else { return .notInAlphabet }
        if let other = otherCustomLabels.first(where: { $0.hasPrefix(label) || label.hasPrefix($0) }) {
            return .conflicts(with: other)
        }
        return nil
    }

    private static func availableLabels(count: Int, alphabet: String, avoiding reserved: [String]) -> [String] {
        guard count > 0 else { return [] }
        guard !reserved.isEmpty else { return HintLabelGenerator.labels(count: count, alphabet: alphabet) }
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
