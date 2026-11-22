// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct GlassHintItem: Identifiable {
    let id: Int
    let label: String
    let center: CGPoint
    let focused: Bool
    let screenIndex: Int
}

@available(macOS 26.0, *)
struct GlassHintsView: View {
    let items: [GlassHintItem]
    let prefix: String
    let fontSize: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ForEach(items.filter { $0.label.hasPrefix(prefix) }) { item in
                    label(item)
                        .position(item.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .allowsHitTesting(false)
    }

    private func label(_ item: GlassHintItem) -> some View {
        let shape = RoundedRectangle(cornerRadius: min(cornerRadius, fontSize / 2 + 2), style: .continuous)
        let glass: Glass = item.focused ? .regular.tint(.green.opacity(0.7)) : .regular
        return text(for: item)
            .font(.system(size: fontSize, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .glassEffect(glass, in: shape)
            .shadow(color: .black.opacity(0.25), radius: 2.5, y: 1)
    }

    private func text(for item: GlassHintItem) -> Text {
        let typedCount = min(prefix.count, item.label.count)
        let typed = String(item.label.prefix(typedCount))
        let remaining = String(item.label.dropFirst(typedCount))
        let color: Color = item.focused ? .black : .primary
        return Text(typed).foregroundColor(color.opacity(typedCount > 0 ? 0.4 : 1))
            + Text(remaining).foregroundColor(color)
    }
}
