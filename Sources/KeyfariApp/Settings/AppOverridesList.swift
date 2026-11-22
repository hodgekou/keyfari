// SPDX-License-Identifier: GPL-3.0-only

import KeyfariCore
import SwiftUI

/// The applications that do some things their own way, each with the settings it overrides.
struct AppOverridesList: View {
    @Bindable var store: SettingsStore
    let tint: Color

    var body: some View {
        let bundleIDs = store.settings.appOverrides.keys.sorted()
        let candidates = ApplicationInfo.running().filter { store.settings.appOverrides[$0.bundleID] == nil }

        VStack(alignment: .leading, spacing: 0) {
            ForEach(bundleIDs.map(ApplicationInfo.init)) { application in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(nsImage: application.icon).resizable().frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(application.name).font(.system(size: 13))
                            Text(application.bundleID).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.settings.appOverrides[application.bundleID] = nil
                        } label: {
                            Image(systemName: "minus.circle.fill").font(.system(size: 16)).foregroundStyle(.red.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        .help(tr("Remove"))
                    }
                    HStack(spacing: 14) {
                        choice("Detect text", selection: binding(application.bundleID, \.visionMode)) {
                            Text(tr("Same as general")).tag(VisionMode?.none)
                            Text(tr("Off")).tag(VisionMode?.some(.off))
                            Text(tr("When needed")).tag(VisionMode?.some(.fallback))
                            Text(tr("Always")).tag(VisionMode?.some(.always))
                        }
                        choice("Detect icon buttons", selection: binding(application.bundleID, \.iconDetection)) { onOff }
                        choice("Compatibility mode", selection: binding(application.bundleID, \.compatibilityMode)) { onOff }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                RowDivider()
            }

            HStack(alignment: .top, spacing: 12) {
                Text(
                    tr(
                        "An application listed here uses its own choices while it is in front. What is left at “Same as general” follows the settings above."
                    )
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Menu {
                    if candidates.isEmpty {
                        Text(tr("No other applications are running"))
                    }
                    ForEach(candidates) { application in
                        Button {
                            // Starts empty; it is kept for as long as the pane shows it and dropped
                            // from what the app acts on until something is chosen.
                            store.settings.appOverrides[application.bundleID] = AppOverride()
                        } label: {
                            Label {
                                Text(application.name)
                            } icon: {
                                Image(nsImage: application.icon)
                            }
                        }
                    }
                } label: {
                    Label(tr("Add application"), systemImage: "plus")
                }
                .menuStyle(.borderedButton)
                .fixedSize()
                .tint(tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var onOff: some View {
        Text(tr("Same as general")).tag(Bool?.none)
        Text(tr("On")).tag(Bool?.some(true))
        Text(tr("Off")).tag(Bool?.some(false))
    }

    private func choice<Value: Hashable, Options: View>(
        _ title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tr(title)).font(.system(size: 10)).foregroundStyle(.secondary)
            Picker("", selection: selection, content: options)
                .labelsHidden()
                .fixedSize()
        }
    }

    private func binding<Value>(_ bundleID: String, _ keyPath: WritableKeyPath<AppOverride, Value>) -> Binding<Value> {
        Binding(
            get: { (store.settings.appOverrides[bundleID] ?? AppOverride())[keyPath: keyPath] },
            set: { newValue in
                var override = store.settings.appOverrides[bundleID] ?? AppOverride()
                override[keyPath: keyPath] = newValue
                store.settings.appOverrides[bundleID] = override
            }
        )
    }
}
