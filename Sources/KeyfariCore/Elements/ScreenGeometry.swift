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
}
