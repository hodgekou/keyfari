// SPDX-License-Identifier: GPL-3.0-only

import Observation
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, hints, labels, scrolling, desktops, stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .hints: "Hints"
        case .labels: "Stable Labels"
        case .scrolling: "Scrolling"
        case .desktops: "Desktops"
        case .stats: "Stats"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Shortcuts, startup, permissions and ignored apps"
        case .hints: "How labels look and behave"
        case .labels: "The same label for the same element, every time"
        case .scrolling: "Speed and direction"
        case .desktops: "Desktops and Mission Control"
        case .stats: "Activity counts that stay on this Mac"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .hints: "tag.fill"
        case .labels: "pin.fill"
        case .scrolling: "arrow.up.arrow.down"
        case .desktops: "rectangle.3.group.fill"
        case .stats: "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: Color(red: 0.23, green: 0.51, blue: 0.96)
        case .hints: Color(red: 0.96, green: 0.45, blue: 0.09)
        case .labels: Color(red: 0.85, green: 0.58, blue: 0.05)
        case .scrolling: Color(red: 0.06, green: 0.65, blue: 0.47)
        case .desktops: Color(red: 0.03, green: 0.60, blue: 0.75)
        case .stats: Color(red: 0.22, green: 0.58, blue: 0.42)
        }
    }
}

/// The selected pane. An observable object rather than view state, because the
/// Command Line Tools ship without the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class SettingsNavigation {
    var pane = SettingsPane.general
    let labelEditing = StableLabelEditing()
}
