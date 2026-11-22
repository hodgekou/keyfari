// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Converts between the two coordinate spaces the app deals with.
///
/// Accessibility and Quartz events use a top-left origin on the primary display with y growing downward.
/// AppKit uses a bottom-left origin on the primary display with y growing upward.
public enum ScreenGeometry {
    /// Flips a rectangle between the accessibility space and the AppKit space.
    /// The conversion is its own inverse.
    public static func flipped(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Index of the screen frame that contains the largest part of `rect`, or nil when none intersects it.
    public static func indexOfScreen(containing rect: CGRect, screenFrames: [CGRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, frame) in screenFrames.enumerated() {
            let overlap = frame.intersection(rect)
            guard !overlap.isNull, !overlap.isEmpty else { continue }
            let area = overlap.width * overlap.height
            // The overlap is never empty here, so any first match beats the zero default.
            if area > (best?.area ?? 0) {
                best = (index, area)
            }
        }
        return best?.index
    }

    /// Whether `frame` shows on one of the displays: its middle is on a display and most of it is too.
    ///
    /// Things that slide off the edge when hidden, like the Dock, keep reporting a frame;
    /// this tells the shown from the hidden.
    public static func isOnScreen(_ frame: CGRect, displays: [CGRect]) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }
        let middle = CGPoint(x: frame.midX, y: frame.midY)
        return displays.contains { display in
            guard display.contains(middle) else { return false }
            let visible = display.intersection(frame)
            return visible.width * visible.height >= 0.8 * frame.width * frame.height
        }
    }

    /// The area the pointer's arrow covers, given where its tip is. Coordinates grow downward.
    public static func pointerShadow(tip: CGPoint) -> CGRect {
        CGRect(x: tip.x - 1, y: tip.y - 1, width: 15, height: 21)
    }

    /// Where to centre a label of `size` that belongs at `center`, so the pointer does not cover it.
    ///
    /// A label under the arrow moves to the left of the arrow's tip, level with where it was:
    /// the arrow extends right and down from its tip, so that side is always clear.
    public static func labelCenter(_ center: CGPoint, size: CGSize, avoidingPointerAt tip: CGPoint?) -> CGPoint {
        guard let tip else { return center }
        let label = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        guard label.intersects(pointerShadow(tip: tip)) else { return center }
        return CGPoint(x: tip.x - 3 - size.width / 2, y: center.y)
    }
}
