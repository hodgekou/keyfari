// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import KeyfariCore
import ScreenVision
import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 760, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        // A new identity rebuilds every view, so a language change reaches all of the text at once.
        .id(store.settings.language)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                // The application icon, which already carries its own shadow and margin.
                Image(nsImage: Brand.icon)
                    .resizable()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Keyfari").font(.system(size: 15, weight: .bold))
                    Text(tr("Keyboard navigation")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 14)

            ForEach(SettingsPane.allCases) { pane in
                SidebarItem(pane: pane, isSelected: navigation.pane == pane) {
                    navigation.pane = pane
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 44)
        .padding(.bottom, 12)
        .frame(width: 200)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }

    private var detail: some View {
        let pane = navigation.pane
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    IconBadge(symbol: pane.symbol, colors: [pane.tint, pane.tint.opacity(0.7)], size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr(pane.title)).font(.system(size: 22, weight: .bold))
                        Text(tr(pane.subtitle)).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 2)

                switch pane {
                case .general: general
                case .hints: hints
                case .scrolling: scrolling
                case .desktops:
                    desktops
                    missionControl
                case .activation: activation
                case .vision: vision
                case .stats: stats
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Panes

    @ViewBuilder
    private var general: some View {
        let tint = SettingsPane.general.tint
        Card("Shortcuts", symbol: "command", tint: tint) {
            ShortcutRecorder(title: "Show hints", detail: "Label everything clickable", shortcut: $store.settings.hintShortcut, tint: tint)
            RowDivider()
            ShortcutRecorder(title: "Search", detail: "Find an element by its text", shortcut: $store.settings.searchShortcut, tint: tint)
            RowDivider()
            ShortcutRecorder(title: "Scroll mode", detail: "Scroll with H J K L", shortcut: $store.settings.scrollShortcut, tint: tint)
            if store.effective.hintShortcut != store.settings.hintShortcut
                || store.effective.searchShortcut != store.settings.searchShortcut
                || store.effective.scrollShortcut != store.settings.scrollShortcut
            {
                RowDivider()
                Notice("Two modes share a shortcut, so the defaults are in use.", symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
        Card("Startup", symbol: "power", tint: tint) {
            ToggleRow("Launch at login", detail: "Start Keyfari when you log in", isOn: $store.settings.launchAtLogin, tint: tint)
        }
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            permissions(tint: tint)
        }
        Card("Language", symbol: "globe", tint: tint) {
            SettingRow("Interface language", detail: "Takes effect immediately") {
                Picker("", selection: $store.settings.language) {
                    Text(tr("System default")).tag(AppLanguage.system)
                    // Each language is listed under its own name, so it can be found from any other.
                    Text(Language.english.nativeName).tag(AppLanguage.english)
                    Text(Language.chinese.nativeName).tag(AppLanguage.chinese)
                    Text(Language.japanese.nativeName).tag(AppLanguage.japanese)
                }
                .labelsHidden()
                .frame(width: 180)
            }
        }
        Card("Ignored applications", symbol: "nosign", tint: tint) {
            IgnoredApplicationsList(store: store, tint: tint)
        }
        Card("Sound effects", symbol: "speaker.wave.2.fill", tint: tint) {
            ToggleRow(
                "Click sounds", detail: "Play a sound after a successful click", isOn: $store.settings.successSoundEnabled,
                tint: tint
            )
            RowDivider()
            ToggleRow(
                "Warning sounds", detail: "Play a sound for invalid or unavailable actions", isOn: $store.settings.warningSoundEnabled,
                tint: tint
            )
        }
    }

    @ViewBuilder
    private var hints: some View {
        let tint = SettingsPane.hints.tint
        let selectedTheme = store.settings.hintTheme.isAvailable ? store.settings.hintTheme : .vivid
        HintPreview(settings: store.effective)

        Card("Appearance", symbol: "paintpalette.fill", tint: tint) {
            SettingRow("Theme") {
                HStack(spacing: 8) {
                    ForEach(HintTheme.available, id: \.self) { theme in
                        ThemeSwatch(theme: theme, isSelected: selectedTheme == theme) {
                            store.settings.hintTheme = theme
                        }
                    }
                }
            }
            RowDivider()
            SliderRow("Label size", value: $store.settings.hintFontSize, range: 8...32, step: 1, tint: tint) { "\(Int($0)) pt" }
            RowDivider()
            SliderRow("Corner radius", value: $store.settings.hintCornerRadius, range: 0...10, step: 1, tint: tint) { "\(Int($0)) pt" }
        }
        Card("Label characters", symbol: "textformat.abc", tint: tint) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(tr("Label characters"), text: $store.settings.hintAlphabet)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                if store.effective.hintAlphabet != store.settings.hintAlphabet.lowercased() {
                    Notice(
                        tr(
                            "Needs at least %d different letters. Using %@ for now.", HintLabelGenerator.minimumAlphabetSize,
                            store.effective.hintAlphabet),
                        symbol: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                } else {
                    Text(tr("Letters used for labels. Home-row keys first keeps your fingers still."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        Card("Behaviour", symbol: "hand.tap.fill", tint: tint) {
            ToggleRow(
                "Keep labels stable", detail: "An element keeps the label it had when you last clicked it", isOn: $store.settings.stableLabels,
                tint: tint)
            RowDivider()
            ToggleRow(
                "Chain clicks", detail: "Stay in the mode after a click, until Esc or a text field", isOn: $store.settings.chainClicks, tint: tint)
        }
        Card("Fixed label bindings", symbol: "pin.fill", tint: tint) {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    tr(
                        "In hint mode, hold Control and Option while typing a label to bind it to that element. Fixed labels take priority over automatic label memory. Only uniquely identifiable accessibility controls can be pinned."
                    )
                )
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12).padding(.top, 10)
                let bindings = store.labelMemory.pinnedBindings
                if bindings.isEmpty {
                    Text(tr("No fixed labels yet"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.bottom, 10)
                } else {
                    ForEach(bindings) { binding in
                        HStack(spacing: 10) {
                            Text(binding.label)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .frame(width: 46, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(binding.targetDescription).font(.system(size: 12)).lineLimit(1)
                                Text(applicationName(binding.bundleID) + " · " + binding.bundleID)
                                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Button {
                                store.labelMemory.removePin(id: binding.id)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .help(tr("Remove"))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scrolling: some View {
        let tint = SettingsPane.scrolling.tint
        Card("Speed", symbol: "speedometer", tint: tint) {
            SliderRow("Scroll speed", value: scrollSpeed, range: 1...100, step: 1, tint: tint) { "\(Int($0))" }
            RowDivider()
            SliderRow("Speed with Shift", value: $store.settings.dashMultiplier, range: 0.25...10, step: 0.25, tint: tint) {
                String(format: "× %.2f", $0)
            }
        }
        Card("Direction", symbol: "arrow.left.arrow.right", tint: tint) {
            ToggleRow("Reverse horizontal", detail: nil, isOn: $store.settings.reverseHorizontal, tint: tint)
            RowDivider()
            ToggleRow("Reverse vertical", detail: nil, isOn: $store.settings.reverseVertical, tint: tint)
        }
        Card("Keys", symbol: "keyboard", tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                KeyHint(keys: ["H", "J", "K", "L"], text: "Scroll left, down, up, right")
                KeyHint(keys: ["D", "U"], text: "Half a page down, up")
                KeyHint(keys: ["G", "G"], text: "Top  ·  Shift-G for the bottom")
                KeyHint(keys: ["Tab"], text: "Next scroll area  ·  0–9 to jump")
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var desktops: some View {
        let tint = SettingsPane.desktops.tint
        let systemShortcuts = SpaceDirection.allCases.map(SystemSpaces.shortcut)
        let chosen = SpaceDirection.allCases.compactMap { store.settings[keyPath: Settings.spaceShortcut($0)] }
        let inForce = SpaceDirection.allCases.compactMap { store.effective[keyPath: Settings.spaceShortcut($0)] }
        Card("Switch desktops", symbol: "arrow.left.arrow.right", tint: tint) {
            ShortcutRecorder(
                title: "Previous desktop", detail: "Go one desktop to the left", optional: $store.settings.previousSpaceShortcut, tint: tint)
            RowDivider()
            ShortcutRecorder(title: "Next desktop", detail: "Go one desktop to the right", optional: $store.settings.nextSpaceShortcut, tint: tint)
            if chosen != inForce {
                RowDivider()
                Notice("A shortcut that is unusable or already taken is switched off.", symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
            if inForce.contains(where: { systemShortcuts.contains($0) }) {
                RowDivider()
                Notice(
                    "A shortcut that macOS already uses to change desktops is left to macOS.", symbol: "exclamationmark.triangle.fill",
                    tint: .orange)
            }
            if systemShortcuts.contains(nil) {
                RowDivider()
                Notice(
                    "Turn on “Move left a space” and “Move right a space” in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.",
                    symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
            RowDivider()
            Notice(
                "Keyfari changes desktops by pressing the system's own shortcuts, so those have to stay on. When displays have separate Spaces, the display with the focused window changes.",
                symbol: "info.circle.fill", tint: tint)
        }
    }

    @ViewBuilder
    private var missionControl: some View {
        let tint = SettingsPane.desktops.tint
        Card("Mission Control", symbol: "rectangle.3.group", tint: tint) {
            ToggleRow(
                "Show labels automatically", detail: "Label windows and desktops as soon as Mission Control opens",
                isOn: $store.settings.missionControlAutoHints, tint: tint)
            RowDivider()
            VStack(alignment: .leading, spacing: 10) {
                KeyHint(keys: store.effective.hintShortcut.displayParts, text: "Show or hide the labels in Mission Control")
                KeyHint(keys: ["A", "S"], text: "Type a label to select a window or desktop")
                KeyHint(keys: ["Return"], text: "Open the selection")
                KeyHint(keys: ["Esc"], text: "Leave Mission Control")
            }
            .padding(12)
            RowDivider()
            Notice(
                "With several displays, labels appear on the display under the pointer. Arrow keys and the system's shortcuts keep working.",
                symbol: "info.circle.fill", tint: tint)
        }
    }

    @ViewBuilder
    private var activation: some View {
        let tint = SettingsPane.activation.tint
        Card("Key sequences", symbol: "character.cursor.ibeam", tint: tint) {
            SettingRow("Show hints", detail: "For example fd") {
                TextField(tr("off"), text: $store.settings.hintKeySequence)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 90)
            }
            RowDivider()
            SettingRow("Scroll mode", detail: "For example jk") {
                TextField(tr("off"), text: $store.settings.scrollKeySequence)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 90)
            }
            RowDivider()
            SliderRow("Timeout", value: $store.settings.keySequenceResetDelay, range: 0.1...1, step: 0.05, tint: tint) {
                String(format: "%.2f s", $0)
            }
            RowDivider()
            Notice("At least two characters, and neither sequence may start with the other.", symbol: "info.circle.fill", tint: tint)
        }
    }

    @ViewBuilder
    private var vision: some View {
        let tint = SettingsPane.vision.tint
        Card("On-screen text detection", symbol: "text.viewfinder", tint: tint) {
            SettingRow("Detect text") {
                Picker("", selection: $store.settings.visionMode) {
                    Text(tr("Off")).tag(VisionMode.off)
                    Text(tr("When needed")).tag(VisionMode.fallback)
                    Text(tr("Always")).tag(VisionMode.always)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            }
            RowDivider()
            Notice(
                "Reads the window's pixels on this Mac to label text the application does not expose. Nothing is saved or sent anywhere.",
                symbol: "lock.shield.fill",
                tint: tint
            )
        }
    }

    @ViewBuilder
    private var stats: some View {
        let tint = SettingsPane.stats.tint
        Card("Usage statistics", symbol: "chart.bar.fill", tint: tint) {
            ToggleRow(
                "Enable usage statistics", detail: "Counts stay on this Mac and are never sent anywhere",
                isOn: $store.settings.statisticsEnabled, tint: tint
            )
        }

        if store.effective.statisticsEnabled {
            let usage = store.usageStats
            Card("Activity", symbol: "calendar", tint: tint) {
                HStack(spacing: 8) {
                    statMetric("Total clicks", value: "\(usage.totalClicks)")
                    statMetric("Current streak", value: "\(usage.currentStreak)")
                    statMetric("Longest streak", value: "\(usage.longestStreak)")
                    statMetric("Active days", value: "\(usage.activeDays)")
                }
                .padding(12)
            }
            Card("Top apps", symbol: "square.grid.2x2.fill", tint: tint) {
                if usage.topApps.isEmpty {
                    Text(tr("No clicks recorded yet"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    ForEach(Array(usage.topApps.prefix(10).enumerated()), id: \.element.id) { index, app in
                        if index > 0 { RowDivider() }
                        SettingRow(app.name) {
                            Text(tr("%d clicks", app.clicks))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button(role: .destructive) {
                usage.clear()
            } label: {
                Text(tr("Clear statistics"))
            }
            .buttonStyle(.bordered)
        } else {
            Notice(
                "Statistics are off. No usage is recorded until you turn them on. Only aggregate counts are stored locally.",
                symbol: "lock.shield.fill", tint: tint
            )
        }
    }

    private func statMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(tr(title)).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
    }

    private func permissions(tint: Color) -> some View {
        let accessibilityGranted = AXPermission.isGranted
        let screenRecordingGranted = ScreenTextDetector.hasPermission
        return Card("Permissions", symbol: "lock.shield.fill", tint: tint) {
            SettingRow("Accessibility permission", detail: "Required for global shortcuts and controlling apps") {
                HStack(spacing: 10) {
                    StatusPill(text: tr(accessibilityGranted ? "Granted" : "Not granted"), tint: accessibilityGranted ? .green : .orange)
                    if !accessibilityGranted {
                        Button(tr("Open System Settings…")) {
                            _ = AXPermission.request()
                            openPermissionSettings("Privacy_Accessibility")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            RowDivider()
            SettingRow("Screen Recording permission", detail: "Turn it on in System Settings, then restart Keyfari") {
                HStack(spacing: 10) {
                    StatusPill(text: tr(screenRecordingGranted ? "Granted" : "Not granted"), tint: screenRecordingGranted ? .green : .orange)
                    if !screenRecordingGranted {
                        Button(tr("Request…")) { ScreenRecordingAccess.request() }
                            .buttonStyle(.borderedProminent)
                            .tint(tint)
                        Button(tr("Restart")) { ScreenRecordingAccess.relaunch() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func openPermissionSettings(_ privacyPane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyPane)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Bindings

    private func applicationName(_ bundleID: String) -> String {
        ApplicationInfo(bundleID: bundleID).name
    }

    private var scrollSpeed: Binding<Double> {
        Binding(
            get: { Double(store.settings.scrollSpeed) },
            set: { store.settings.scrollSpeed = Int($0) }
        )
    }
}
