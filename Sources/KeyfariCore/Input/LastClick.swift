// SPDX-License-Identifier: GPL-3.0-only

/// What is kept of the last click made through a label, so it can be made again.
///
/// It names the element, not a place on screen: the element is looked up again when the click
/// is repeated, so a moved window or a scrolled list does not send the click astray.
public struct LastClick: Equatable, Sendable {
    /// The application the element belongs to.
    public let bundleID: String
    public let fingerprint: String
    public let action: ClickAction

    /// Nil when the element cannot be told apart, or the action only moved the pointer.
    public init?(element: ElementSnapshot, bundleID: String, action: ClickAction) {
        guard action != .moveOnly, !bundleID.isEmpty, let fingerprint = StableLabels.fingerprint(of: element) else { return nil }
        self.bundleID = bundleID
        self.fingerprint = fingerprint
        self.action = action
    }

    /// The position of the same element among `elements`, or nil when it is not there.
    /// - Parameter bundleIDs: the application each element belongs to, one per element.
    public func index(in elements: [ElementSnapshot], bundleIDs: [String]) -> Int? {
        zip(elements, bundleIDs).enumerated().first { _, pair in
            pair.1 == bundleID && StableLabels.fingerprint(of: pair.0) == fingerprint
        }?.offset
    }
}
