// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Works out which parts of a window other windows leave visible.
public enum WindowOcclusion {
    /// Whether `point` shows through, given the frames of the windows in front of it.
    public static func isVisible(_ point: CGPoint, behind occluders: [CGRect]) -> Bool {
        !occluders.contains { $0.contains(point) }
    }

    /// Roughly how much of `frame` shows through, from 0 to 1, sampled on a grid.
    public static func visibleFraction(of frame: CGRect, behind occluders: [CGRect], samplesPerSide: Int = 6) -> Double {
        guard frame.width > 0, frame.height > 0, samplesPerSide > 0 else { return 0 }
        guard !occluders.isEmpty else { return 1 }
        var visible = 0
        for row in 0..<samplesPerSide {
            for column in 0..<samplesPerSide {
                // Sample the middle of each cell, so the very edges do not decide.
                let point = CGPoint(
                    x: frame.minX + frame.width * (CGFloat(column) + 0.5) / CGFloat(samplesPerSide),
                    y: frame.minY + frame.height * (CGFloat(row) + 0.5) / CGFloat(samplesPerSide)
                )
                if isVisible(point, behind: occluders) { visible += 1 }
            }
        }
        return Double(visible) / Double(samplesPerSide * samplesPerSide)
    }
}
