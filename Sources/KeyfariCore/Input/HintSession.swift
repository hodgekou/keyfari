// SPDX-License-Identifier: GPL-3.0-only
/// What a completed hint does to its element.
public enum ClickAction: Equatable, Sendable {
    case left
    case right
    case double
    /// A left click with the Command flag, which opens links in a new tab.
    case commandLeft
    case moveOnly

    /// Number of click events this action sends; moving the pointer alone is not a click.
    public var clickCount: Int {
        switch self {
        case .double: 2
        case .moveOnly: 0
        case .left, .right, .commandLeft: 1
        }
    }

    /// The action selected by the modifiers held on the final label key.
    public init(modifiers: Modifiers) {
        if modifiers.contains(.shift) {
            self = .right
        } else if modifiers.contains(.command) {
            self = .double
        } else if modifiers.contains(.control) {
            self = .commandLeft
        } else if modifiers.contains(.option) {
            self = .moveOnly
        } else {
            self = .left
        }
    }
}

public enum HintEvent: Equatable, Sendable {
    /// The typed prefix changed. `visible` holds the indices of labels that still match.
    case updated(prefix: String, visible: [Int])
    /// The key would leave no matching label. The prefix is unchanged.
    case rejected
    /// Cycle the stacking order of overlapping labels.
    case rotate
    /// The element is the start of a drag: nothing is clicked, and the next label names where it ends.
    case pickedUp(index: Int)
    case matched(index: Int, action: ClickAction)
    case exit
    case ignored
}

/// The input state machine of label click mode.
public struct HintSession: Sendable {
    /// Held on the last letter of a label to start a drag there.
    public static let pickUpModifiers: Modifiers = [.control, .shift]

    public private(set) var labels: [String]
    public private(set) var prefix = ""

    /// `labels` must be uppercase and prefix-free, as produced by `HintLabelGenerator`.
    public init(labels: [String]) {
        self.labels = labels
    }

    /// Adds labels for elements found after the first ones were shown. Together with the
    /// existing labels they must still be prefix-free.
    public mutating func append(labels more: [String]) {
        labels.append(contentsOf: more)
    }

    /// Forgets what was typed, so a second label can follow the first.
    public mutating func clearPrefix() {
        prefix = ""
    }

    public var visible: [Int] {
        labels.indices.filter { labels[$0].hasPrefix(prefix) }
    }

    public mutating func handle(_ stroke: KeyStroke) -> HintEvent {
        if stroke.keyCode == KeyCode.escape
            || (stroke.keyCode == KeyCode.leftBracket && stroke.modifiers.contains(.control))
        {
            return .exit
        }
        // Auto-repeat would otherwise type a label character many times.
        if stroke.isRepeat { return .ignored }

        switch stroke.keyCode {
        case KeyCode.delete:
            guard !prefix.isEmpty else { return .ignored }
            prefix.removeLast()
            return .updated(prefix: prefix, visible: visible)
        case KeyCode.space:
            return .rotate
        default:
            break
        }

        guard let character = stroke.character, character.isLetter else { return .ignored }
        let candidate = prefix + character.uppercased()
        let matching = labels.indices.filter { labels[$0].hasPrefix(candidate) }
        guard !matching.isEmpty else { return .rejected }

        if let index = matching.first(where: { labels[$0] == candidate }) {
            if stroke.modifiers == Self.pickUpModifiers {
                return .pickedUp(index: index)
            }
            return .matched(index: index, action: ClickAction(modifiers: stroke.modifiers))
        }
        prefix = candidate
        return .updated(prefix: prefix, visible: matching)
    }
}
