// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import KeyfariCore
import Observation
import ScreenVision
import SwiftUI

/// The step of the welcome guide that is showing. An observable object rather than view state,
/// because the Command Line Tools ship without the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class WelcomeNavigation {
    static let stepCount = 3
    var step = 0
}

/// The guide shown on the first launch: grant the permission, learn the shortcuts, pick the options.
struct WelcomeView: View {
    private static let tint = Color(red: 0.23, green: 0.51, blue: 0.96)

    @Bindable var store: SettingsStore
    @Bindable var navigation: WelcomeNavigation
    let onDone: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: Brand.icon).resizable().frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Welcome to Keyfari")).font(.system(size: 22, weight: .bold))
                    Text(tr("Step %d of %d", navigation.step + 1, WelcomeNavigation.stepCount))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 14) {
                switch navigation.step {
                case 0: permission
                case 1: shortcuts
                default: options
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if navigation.step > 0 {
                    Button(tr("Back")) { navigation.step -= 1 }
                        .buttonStyle(.bordered)
                }
                Spacer()
                if navigation.step < WelcomeNavigation.stepCount - 1 {
                    Button(tr("Continue")) { navigation.step += 1 }
                        .buttonStyle(.borderedProminent)
                        .tint(Self.tint)
                } else {
                    Button(tr("Done")) { onDone() }
                        .buttonStyle(.borderedProminent)
                        .tint(Self.tint)
                }
            }
        }
        .padding(28)
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        // A new identity rebuilds every view, so a language change reaches all of the text at once.
        .id(store.settings.language)
    }

    // MARK: Steps

    @ViewBuilder
    private var permission: some View {
        Text(tr("Keyfari reads what is on screen and clicks for you. macOS only lets it do that with the Accessibility permission."))
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)
        // The permission is granted in another application, so the state is looked up again and again.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let isGranted = AXPermission.isGranted
            Card("Accessibility permission", symbol: "lock.shield.fill", tint: Self.tint) {
                SettingRow("Accessibility permission", detail: "Required for global shortcuts and controlling apps") {
                    HStack(spacing: 10) {
                        StatusPill(text: tr(isGranted ? "Granted" : "Not granted"), tint: isGranted ? .green : .orange)
                        if !isGranted {
                            Button(tr("Open System Settings…")) {
                                _ = AXPermission.request()
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Self.tint)
                        }
                    }
                }
            }
        }
        Notice(
            "In System Settings, switch Keyfari on in the list. Keyfari is not signed with an Apple Developer ID, so macOS asks for this again after every update.",
            symbol: "info.circle.fill", tint: Self.tint)
    }

    @ViewBuilder
    private var shortcuts: some View {
        let settings = store.effective
        Text(tr("Three shortcuts do the work. Try them in any other application once this window is closed."))
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)
        Card("Shortcuts", symbol: "command", tint: Self.tint) {
            shortcutRow("Show hints", detail: "Every button, link and menu item gets a label. Type the label to click", settings.hintShortcut)
            RowDivider()
            shortcutRow("Search", detail: "Type part of an element's text, then Return", settings.searchShortcut)
            RowDivider()
            shortcutRow("Scroll mode", detail: "Scroll with the keyboard; Esc leaves", settings.scrollShortcut)
        }
        Notice(
            "On the last letter of a label, hold Shift for a right click, Command for a double click, Option to only move the pointer. Esc always leaves.",
            symbol: "hand.tap.fill", tint: Self.tint)
    }

    @ViewBuilder
    private var options: some View {
        Text(tr("A few choices. All of them can be changed later in the settings."))
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)
        Card("Startup", symbol: "power", tint: Self.tint) {
            ToggleRow("Launch at login", detail: "Start Keyfari when you log in", isOn: $store.settings.launchAtLogin, tint: Self.tint)
            RowDivider()
            ToggleRow(
                "Check for updates", detail: "Once a day, asks GitHub for the newest version. Nothing about you or this Mac is sent",
                isOn: $store.settings.updateCheckEnabled, tint: Self.tint)
        }
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let isGranted = ScreenTextDetector.hasPermission
            Card("On-screen text detection", symbol: "text.viewfinder", tint: Self.tint) {
                SettingRow("Screen Recording permission", detail: "Optional. Lets Keyfari label text that applications do not expose") {
                    HStack(spacing: 10) {
                        StatusPill(text: tr(isGranted ? "Granted" : "Not granted"), tint: isGranted ? .green : .orange)
                        if !isGranted {
                            Button(tr("Request…")) { ScreenRecordingAccess.request() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        Notice("Keyfari lives in the menu bar. Its menu opens the settings and this guide again.", symbol: "menubar.rectangle", tint: Self.tint)
    }

    private func shortcutRow(_ title: String, detail: String, _ shortcut: Shortcut) -> some View {
        SettingRow(title, detail: detail) {
            HStack(spacing: 4) {
                ForEach(Array(shortcut.displayParts.enumerated()), id: \.offset) { _, part in
                    Keycap(text: part, tint: Self.tint)
                }
            }
        }
    }
}
