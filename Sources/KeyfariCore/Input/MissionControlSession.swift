// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

public enum MissionControlEvent: Equatable, Sendable {
    /// The typed prefix changed and no label is complete yet.
    case updated(prefix: String)
    /// A label was typed in full. Its item is selected and waits for confirmation.
    case focused(index: Int)
    /// The selected item should be opened.
    case confirmed(index: Int)
    /// The key would leave no matching label, or there is nothing to confirm. Nothing changed.
    case rejected
    case exit
    case ignored
}

/// The input state machine for labels in Mission Control.
///
/// Unlike hint mode, a complete label only selects its item and Return opens it: leaving the
/// overview for the wrong window or desktop costs more than a wrong click.
public struct MissionControlSession: Sendable {
    public let labels: [String]
    public private(set) var prefix = ""
    public private(set) var focused: Int?

    /// The keys the session reads. Every other key is left to Mission Control, so its own
    /// keyboard controls, such as the arrow keys, keep working.
    public static let keyCodes: Set<UInt16> = Set(KeyCode.characters.filter { $0.value.isLetter }.keys)
        .union([KeyCode.return, KeyCode.keypadEnter, KeyCode.delete, KeyCode.escape, KeyCode.leftBracket])

    /// `labels` must be uppercase and prefix-free, as produced by `HintLabelGenerator`.
    public init(labels: [String]) {
        self.labels = labels
    }

    public mutating func handle(_ stroke: KeyStroke) -> MissionControlEvent {
        if stroke.keyCode == KeyCode.escape
            || (stroke.keyCode == KeyCode.leftBracket && stroke.modifiers.contains(.control))
        {
            return .exit
        }
        // Auto-repeat would otherwise type a label character many times, or confirm twice.
        if stroke.isRepeat { return .ignored }

        switch stroke.keyCode {
        case KeyCode.return, KeyCode.keypadEnter:
            guard let focused else { return .rejected }
            return .confirmed(index: focused)
        case KeyCode.delete:
            guard !prefix.isEmpty else { return .ignored }
            prefix.removeLast()
            focused = nil
            return .updated(prefix: prefix)
        default:
            break
        }

        guard let character = stroke.character, character.isLetter,
            stroke.modifiers.isDisjoint(with: [.command, .control, .option])
        else { return .ignored }
        // A letter typed after a selection starts a new label, so a wrong selection is easy to replace.
        let candidate = (focused == nil ? prefix : "") + character.uppercased()
        let matching = labels.indices.filter { labels[$0].hasPrefix(candidate) }
        guard !matching.isEmpty else { return .rejected }

        prefix = candidate
        if let index = matching.first(where: { labels[$0] == candidate }) {
            focused = index
            return .focused(index: index)
        }
        focused = nil
        return .updated(prefix: prefix)
    }
}

/// Geometry of the Mission Control overview. Everything uses accessibility coordinates.
public enum MissionControlLayout {
    /// Where the label of a desktop in the Spaces bar goes.
    /// - Parameters:
    ///   - button: the frame the desktop reports.
    ///   - bar: the frame of the Spaces bar.
    public static func spaceLabelPoint(button: CGRect, bar: CGRect) -> CGPoint {
        // While the bar is collapsed to a row of names, a desktop still reports the frame of the
        // thumbnail it would have, hanging below the bar, and its name is centred on that
        // frame's left edge.
        if button.height > bar.height {
            return CGPoint(x: button.minX, y: bar.midY)
        }
        let visible = button.intersection(bar)
        return visible.isNull ? CGPoint(x: button.midX, y: button.midY) : CGPoint(x: visible.midX, y: visible.midY)
    }

    /// Index of the display whose overview the user is working in: the one under the pointer,
    /// or the first one when the pointer is on none of them.
    public static func currentDisplay(pointer: CGPoint, displayFrames: [CGRect]) -> Int? {
        guard !displayFrames.isEmpty else { return nil }
        return displayFrames.firstIndex { $0.contains(pointer) } ?? 0
    }

    /// Sorts frames top to bottom in bands of `rowHeight`, and left to right within a band.
    public static func readingOrder(_ frames: [CGRect], rowHeight: CGFloat = 80) -> [Int] {
        frames.indices.sorted { lhs, rhs in
            let left = (Int((frames[lhs].midY / rowHeight).rounded(.down)), frames[lhs].midX)
            let right = (Int((frames[rhs].midY / rowHeight).rounded(.down)), frames[rhs].midX)
            return left < right
        }
    }
}
