// SPDX-License-Identifier: GPL-3.0-only

public enum ScrollDirection: Equatable, Sendable {
    case left, down, up, right
}

public enum ScrollEvent: Equatable, Sendable {
    /// Scroll continuously until `stop`. `dash` asks for the faster speed.
    case start(ScrollDirection, dash: Bool)
    case stop
    /// Scroll by half the height of the scroll area.
    case halfPage(ScrollDirection)
    case top
    case bottom
    case selectArea(Int)
    case exit
    case ignored
}

/// The letters that scroll. The other keys of scroll mode are fixed.
public struct ScrollKeys: Equatable, Sendable {
    public let left: Character
    public let down: Character
    public let up: Character
    public let right: Character
    public let halfPageDown: Character
    public let halfPageUp: Character

    public static let standardScroll = "hjkl"
    public static let standardHalfPage = "du"
    public static let standard = ScrollKeys(left: "h", down: "j", up: "k", right: "l", halfPageDown: "d", halfPageUp: "u")

    private init(left: Character, down: Character, up: Character, right: Character, halfPageDown: Character, halfPageUp: Character) {
        self.left = left
        self.down = down
        self.up = up
        self.right = right
        self.halfPageDown = halfPageDown
        self.halfPageUp = halfPageUp
    }

    /// Reads the keys from the two settings, or returns nil when they cannot be used.
    /// - Parameters:
    ///   - scroll: four letters for left, down, up and right.
    ///   - halfPage: two letters for half a page down and up.
    ///
    /// All six must be different letters, and none may be `g`, which goes to the top and the bottom.
    public init?(scroll: String, halfPage: String) {
        let scroll = Array(scroll.lowercased())
        let halfPage = Array(halfPage.lowercased())
        let all = scroll + halfPage
        guard scroll.count == 4, halfPage.count == 2, Set(all).count == all.count,
            all.allSatisfy({ $0.isLetter && $0.isASCII && $0 != "g" })
        else { return nil }
        self.init(left: scroll[0], down: scroll[1], up: scroll[2], right: scroll[3], halfPageDown: halfPage[0], halfPageUp: halfPage[1])
    }
}

/// The input state machine of scroll mode.
public struct ScrollSession: Sendable {
    /// How long the second `g` of `gg` may take, in seconds.
    public static let sequenceTimeout = 0.5

    public let areaCount: Int
    public let keys: ScrollKeys
    /// Whether the arrow keys scroll, instead of going from one scroll area to the next.
    public let arrowsScroll: Bool
    public private(set) var areaIndex = 0
    private var firstGTime: Double?
    private var scrollingKey: UInt16?

    public init(areaCount: Int, keys: ScrollKeys = .standard, arrowsScroll: Bool = false) {
        self.areaCount = max(areaCount, 1)
        self.keys = keys
        self.arrowsScroll = arrowsScroll
    }

    /// `time` is a monotonic timestamp in seconds.
    public mutating func keyDown(_ stroke: KeyStroke, at time: Double) -> ScrollEvent {
        if stroke.keyCode == KeyCode.escape
            || (stroke.keyCode == KeyCode.leftBracket && stroke.modifiers.contains(.control))
        {
            return .exit
        }
        // Continuous scrolling is driven by a timer, not by key repeat.
        if stroke.isRepeat { return .ignored }

        let pendingG = firstGTime
        firstGTime = nil
        let shift = stroke.modifiers.contains(.shift)
        let control = stroke.modifiers.contains(.control)

        switch stroke.keyCode {
        case KeyCode.tab:
            return select(areaIndex + (shift ? -1 : 1))
        case KeyCode.downArrow:
            return arrowsScroll ? start(.down, stroke, dash: shift) : select(areaIndex + 1)
        case KeyCode.upArrow:
            return arrowsScroll ? start(.up, stroke, dash: shift) : select(areaIndex - 1)
        case KeyCode.leftArrow where arrowsScroll:
            return start(.left, stroke, dash: shift)
        case KeyCode.rightArrow where arrowsScroll:
            return start(.right, stroke, dash: shift)
        default:
            break
        }

        guard let character = stroke.character else { return .ignored }

        if control {
            switch character {
            case "n": return select(areaIndex + 1)
            case "p": return select(areaIndex - 1)
            default: return .ignored
            }
        }

        switch character {
        case keys.left: return start(.left, stroke, dash: shift)
        case keys.down: return start(.down, stroke, dash: shift)
        case keys.up: return start(.up, stroke, dash: shift)
        case keys.right: return start(.right, stroke, dash: shift)
        case keys.halfPageDown: return .halfPage(.down)
        case keys.halfPageUp: return .halfPage(.up)
        case "g":
            if shift { return .bottom }
            if let pendingG, time - pendingG <= Self.sequenceTimeout { return .top }
            firstGTime = time
            return .ignored
        default:
            if let digit = character.wholeNumberValue, digit < areaCount {
                areaIndex = digit
                return .selectArea(digit)
            }
            return .ignored
        }
    }

    public mutating func keyUp(keyCode: UInt16) -> ScrollEvent {
        guard keyCode == scrollingKey else { return .ignored }
        scrollingKey = nil
        return .stop
    }

    private mutating func start(_ direction: ScrollDirection, _ stroke: KeyStroke, dash: Bool) -> ScrollEvent {
        scrollingKey = stroke.keyCode
        return .start(direction, dash: dash)
    }

    private mutating func select(_ index: Int) -> ScrollEvent {
        // Wraps around in both directions.
        areaIndex = ((index % areaCount) + areaCount) % areaCount
        return .selectArea(areaIndex)
    }
}
