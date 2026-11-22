// SPDX-License-Identifier: GPL-3.0-only

import KeyfariCore
import SwiftUI

/// A calendar of squares, one a day and one column a week, shaded by how much was clicked that day.
struct ActivityHeatmap: View {
    /// About half a year, which fits the width of the pane.
    static let weekCount = 26
    private static let side: CGFloat = 13
    private static let gap: CGFloat = 3

    /// See `UsageLedger.activity`: oldest week first, nil for days that have not come.
    let weeks: [[Int?]]
    let tint: Color

    var body: some View {
        let busiest = weeks.joined().compactMap { $0 }.max() ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: Self.gap) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, clicks in
                            square(level: clicks.map { UsageLedger.activityLevel(clicks: $0, busiest: busiest) })
                                .help(clicks.map { tr("%d clicks", $0) } ?? "")
                        }
                    }
                }
            }
            HStack(spacing: 5) {
                Text(tr("The last %d weeks, one square a day", weeks.count))
                Spacer()
                Text(tr("Less"))
                ForEach(0..<5, id: \.self) { level in square(level: level) }
                Text(tr("More"))
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    /// One day. A day that has not come yet keeps its place but shows nothing.
    private func square(level: Int?) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color(level))
            .frame(width: Self.side, height: Self.side)
    }

    private func color(_ level: Int?) -> Color {
        guard let level else { return .clear }
        return level == 0 ? Color.primary.opacity(0.07) : tint.opacity(0.25 + 0.25 * Double(level - 1))
    }
}
