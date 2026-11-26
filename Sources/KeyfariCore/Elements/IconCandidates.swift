// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

/// Picks out, from the outlines found in a screenshot, the ones that are probably icon buttons.
///
/// There is no model behind this, only geometry: an icon is a small, roughly square shape that
/// sits in a row or a column of others like it, as in a toolbar. That misses lone icons and
/// lets through decoration that happens to line up, which is why the feature is optional.
public enum IconCandidates {
    public struct Limits: Sendable {
        /// Parts of one icon, such as a speaker and its waves, lie at most this far apart.
        /// Letters of a word do too, which joins them into something too wide to be an icon.
        public var mergeGap: CGFloat = 5
        public var minimumSide: CGFloat = 8
        public var maximumSide: CGFloat = 44
        /// The longer side is at most this many times the shorter one.
        public var maximumAspect: CGFloat = 2
        /// Icons of one row have their middles within this distance across the row.
        public var alignment: CGFloat = 6
        /// Neighbours in a row are at most this many icon sizes apart.
        public var maximumSpacing: CGFloat = 4
        /// A row or column needs this many icons to count.
        public var minimumRun = 3
        public var maximumCount = 80

        public init() {}
    }

    /// The frames worth a label, in reading order.
    /// - Parameters:
    ///   - outlines: bounding boxes of the outlines found in the screenshot, in any order.
    ///   - occupied: frames that already carry a label or hold text; nothing inside or over them is an icon of its own.
    public static func find(outlines: [CGRect], occupied: [CGRect], limits: Limits = Limits()) -> [CGRect] {
        let merged = merge(outlines.filter { $0.width <= limits.maximumSide && $0.height <= limits.maximumSide }, gap: limits.mergeGap)
        let sized = merged.filter { box in
            let short = min(box.width, box.height)
            let long = max(box.width, box.height)
            return short >= limits.minimumSide && long <= limits.maximumSide && long <= short * limits.maximumAspect
        }
        let free = sized.filter { box in
            let middle = CGPoint(x: box.midX, y: box.midY)
            return !occupied.contains { $0.contains(middle) || $0.intersects(box.insetBy(dx: 1, dy: 1)) }
        }
        let rows = free.indices.map { runLength(of: $0, in: free, horizontal: true, limits: limits) }
        let columns = free.indices.map { runLength(of: $0, in: free, horizontal: false, limits: limits) }
        // A sidebar often keeps a pair of icons at its far end, such as WeChat's phone and menu
        // below its tabs. Too few to count alone, they count when they continue a full run.
        func continuesRun(_ index: Int, horizontal: Bool) -> Bool {
            let runs = horizontal ? rows : columns
            return runs[index] >= 2
                && free.indices.contains { other in
                    runs[other] >= limits.minimumRun && inLine(free[index], free[other], horizontal: horizontal, limits: limits)
                }
        }
        let inRuns = free.indices.filter { index in
            rows[index] >= limits.minimumRun || columns[index] >= limits.minimumRun
                || continuesRun(index, horizontal: true) || continuesRun(index, horizontal: false)
        }
        return inRuns.map { free[$0] }
            .sorted { lhs, rhs in
                (Int((lhs.midY / 12).rounded(.down)), lhs.midX) < (Int((rhs.midY / 12).rounded(.down)), rhs.midX)
            }
            .prefix(limits.maximumCount)
            .map { $0 }
    }

    /// Joins boxes that touch or lie within `gap` of each other, until none do.
    /// A box that would grow past what an icon can be is left as it is found.
    static func merge(_ boxes: [CGRect], gap: CGFloat) -> [CGRect] {
        var result = boxes
        var changed = true
        while changed {
            changed = false
            var next: [CGRect] = []
            for box in result {
                if let index = next.firstIndex(where: { $0.insetBy(dx: -gap, dy: -gap).intersects(box) }) {
                    next[index] = next[index].union(box)
                    changed = true
                } else {
                    next.append(box)
                }
            }
            result = next
        }
        return result
    }

    /// Whether two boxes sit on one row or column and are of a like size.
    private static func inLine(_ box: CGRect, _ other: CGRect, horizontal: Bool, limits: Limits) -> Bool {
        let across = horizontal ? abs(box.midY - other.midY) : abs(box.midX - other.midX)
        let size = max(box.width, box.height)
        let otherSize = max(other.width, other.height)
        return across <= limits.alignment && otherSize <= size * 1.8 && size <= otherSize * 1.8
    }

    /// How many boxes, `index` included, line up with it along a row or a column without a wide gap.
    private static func runLength(of index: Int, in boxes: [CGRect], horizontal: Bool, limits: Limits) -> Int {
        let box = boxes[index]
        func along(_ rect: CGRect) -> CGFloat { horizontal ? rect.midX : rect.midY }
        let size = max(box.width, box.height)

        // The ones in line with it and of a like size, ordered along the line.
        let line = boxes.filter { inLine(box, $0, horizontal: horizontal, limits: limits) }.sorted { along($0) < along($1) }
        guard let position = line.firstIndex(of: box) else { return 1 }

        // Walk outward in both directions for as long as the neighbours stay close.
        var count = 1
        var previous = box
        for other in line[(position + 1)...] {
            guard along(other) - along(previous) <= size * limits.maximumSpacing else { break }
            count += 1
            previous = other
        }
        previous = box
        for other in line[..<position].reversed() {
            guard along(previous) - along(other) <= size * limits.maximumSpacing else { break }
            count += 1
            previous = other
        }
        return count
    }
}
