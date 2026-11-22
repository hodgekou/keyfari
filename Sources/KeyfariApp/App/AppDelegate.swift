// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import KeyfariCore
import OverlayKit
import ScreenVision
import SwiftUI
import UniformTypeIdentifiers
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "app")
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private let store = SettingsStore()
    private lazy var modes = ModeCoordinator(store: store)
    private lazy var updates = AppUpdater(store: store)
    private var ignoreMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var updateMenuItem: NSMenuItem?
    private var modeMenuItems: [(item: NSMenuItem, title: String, shortcut: KeyPath<KeyfariCore.Settings, Shortcut>)] = []
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var welcomeMenuItem: NSMenuItem?
    #if DEBUG
    private var debugTriggers: [DispatchSourceSignal] = []
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Alerts and the settings window then show the real icon too.
        NSApp.applicationIconImage = Brand.icon
        setUpStatusItem()
        updates.start()
        store.onUpdateCheckChange = { [weak self] in self?.updates.settingsChanged() }
        showWelcomeOnFirstLaunch()
        #if DEBUG
        if CommandLine.arguments.contains("--open-welcome") {
            openWelcome()
        }
        // `--open-settings` opens the settings window at launch, for checking it without clicking through the menu.
        if CommandLine.arguments.contains("--open-settings") {
            openSettings()
        }
        #endif

        if AXPermission.request() {
            permissionGranted()
        } else {
            log.notice("Accessibility permission missing, waiting for the user to grant it")
            waitForPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
    }

    /// Loads the text recognition models in the background, so the first activation does not wait for them.
    private func warmUpTextDetection() {
        guard store.effective.visionMode != .off else { return }
        let log = log
        Task.detached(priority: .utility) {
            let started = ContinuousClock.now
            await ScreenTextDetector.warmUp()
            let elapsed = ContinuousClock.now - started
            log.notice("Text detection warmed up after \(elapsed.description, privacy: .public)")
        }
    }

    // MARK: Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyfari")

        let menu = NSMenu()
        let hints = NSMenuItem(title: "Show Hints", action: #selector(showHints), keyEquivalent: "")
        hints.image = Self.menuSymbol("tag.fill")
        hints.target = self
        menu.addItem(hints)
        modeMenuItems.append((hints, "Show Hints", \.hintShortcut))
        let search = NSMenuItem(title: "Search", action: #selector(searchMode), keyEquivalent: "")
        search.image = Self.menuSymbol("magnifyingglass")
        search.target = self
        menu.addItem(search)
        modeMenuItems.append((search, "Search", \.searchShortcut))
        let scroll = NSMenuItem(title: "Scroll Mode", action: #selector(scrollMode), keyEquivalent: "")
        scroll.image = Self.menuSymbol("arrow.up.arrow.down")
        scroll.target = self
        menu.addItem(scroll)
        modeMenuItems.append((scroll, "Scroll Mode", \.scrollShortcut))
        menu.addItem(.separator())
        let ignore = NSMenuItem(title: "", action: #selector(toggleIgnoreFrontmost), keyEquivalent: "")
        ignore.image = Self.menuSymbol("nosign")
        ignore.target = self
        menu.addItem(ignore)
        ignoreMenuItem = ignore
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.image = Self.menuSymbol("gearshape")
        settings.target = self
        menu.addItem(settings)
        settingsMenuItem = settings
        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.image = Self.menuSymbol("arrow.down.circle")
        update.target = self
        menu.addItem(update)
        updateMenuItem = update
        let welcome = NSMenuItem(title: "Welcome Guide…", action: #selector(openWelcome), keyEquivalent: "")
        welcome.image = Self.menuSymbol("hand.wave")
        welcome.target = self
        menu.addItem(welcome)
        welcomeMenuItem = welcome
        menu.delegate = self
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Keyfari", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        quitMenuItem = quit
        item.menu = menu

        statusItem = item
        item.isVisible = store.effective.showMenuBarIcon
        store.onMenuBarIconChange = { [weak self] in
            guard let self else { return }
            self.statusItem?.isVisible = self.store.effective.showMenuBarIcon
        }
    }

    /// Opening the app again while it runs opens the settings. With the menu bar icon hidden
    /// this is the way back to them.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        openSettings()
        return false
    }

    /// Debug builds toggle a mode on a signal, so the modes can be driven from a terminal:
    /// `pkill -USR1 -x Keyfari` for hints, `pkill -USR2 -x Keyfari` for scrolling.
    private func installDebugTrigger() {
        #if DEBUG
        debugTriggers = [(SIGUSR1, Mode.hint), (SIGUSR2, Mode.scroll)].map { number, mode in
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.modes.toggle(mode) }
            }
            source.resume()
            return source
        }
        #else
        // The same signals would end a release build, which has no use for them.
        signal(SIGUSR1, SIG_IGN)
        signal(SIGUSR2, SIG_IGN)
        #endif
    }

    private static func menuSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    @objc private func showHints() {
        modes.toggle(.hint)
    }

    @objc private func searchMode() {
        modes.toggle(.search)
    }

    @objc private func scrollMode() {
        modes.toggle(.scroll)
    }

    @objc private func toggleIgnoreFrontmost() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        store.toggleIgnored(bundleID: bundleID)
    }

    @objc private func checkForUpdates() {
        updates.checkNow()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let content = SettingsView(
                store: store, navigation: SettingsNavigation(),
                checkForUpdates: { [weak self] in self?.updates.checkNow() },
                copyDiagnostics: { [weak self] in self?.copyDiagnostics() },
                exportSettings: { [weak self] in self?.exportSettings() },
                importSettings: { [weak self] in self?.importSettings() },
                openWelcome: { [weak self] in self?.openWelcome() }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.title = tr("Keyfari Settings")
            // The content runs under a transparent title bar, so the sidebar reaches the top edge.
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        // While the window is open the app shows in the Dock and in the application switcher,
        // so the window can be found again after another application covers it.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func copyDiagnostics() {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        let diagnostics = Diagnostics(
            appVersion: AppUpdater.currentVersion,
            systemVersion: "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
            architecture: architecture,
            displays: NSScreen.screens.map(\.frame.size),
            hasAccessibility: AXPermission.isGranted,
            hasScreenRecording: ScreenTextDetector.hasPermission,
            installsUpdates: AppUpdater.installsUpdates,
            settings: store.effective
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics.report, forType: .string)
        Toast.show(tr("Diagnostic information copied."), for: .seconds(2))
    }

    // MARK: Backup

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Keyfari Settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let archive = SettingsArchive(settings: store.effective, stableLabels: store.labelMemory.book.entries)
            try archive.encoded().write(to: url, options: .atomic)
        } catch {
            log.error("Could not export the settings: \(error.localizedDescription, privacy: .public)")
            alert(tr("The settings could not be saved."), detail: error.localizedDescription)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let archive: SettingsArchive
        do {
            // Read with a limit, so a huge file is refused before it is loaded.
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: SettingsArchive.maximumSize + 1) ?? Data()
            archive = try SettingsArchive.read(data)
        } catch SettingsArchive.ReadError.newerFormat {
            return alert(tr("This file was written by a newer version of Keyfari."), detail: tr("Update Keyfari, then import it again."))
        } catch {
            return alert(tr("This is not a Keyfari settings file."), detail: tr("Nothing was changed."))
        }

        let confirmation = NSAlert()
        confirmation.messageText = tr("Replace the current settings?")
        confirmation.informativeText = tr("The settings and the %d remembered labels in the file replace the ones here.", archive.stableLabels.count)
        confirmation.addButton(withTitle: tr("Replace"))
        confirmation.addButton(withTitle: tr("Cancel"))
        guard confirmation.runModal() == .alertFirstButtonReturn else { return }
        store.settings = archive.settings
        store.labelMemory.replaceAll(with: archive.stableLabels)
    }

    private func alert(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }

    // MARK: Welcome guide

    private static let hasSeenWelcomeKey = "hasSeenWelcome"

    /// Opens the guide on the very first launch. Must run before anything stores settings.
    private func showWelcomeOnFirstLaunch() {
        let defaults = UserDefaults.standard
        let shouldWelcome = FirstLaunch.shouldWelcome(
            hasSeenWelcome: defaults.bool(forKey: Self.hasSeenWelcomeKey),
            hasStoredSettings: defaults.data(forKey: "settings") != nil
        )
        defaults.set(true, forKey: Self.hasSeenWelcomeKey)
        if shouldWelcome { openWelcome() }
    }

    @objc private func openWelcome() {
        if welcomeWindow == nil {
            let content = WelcomeView(store: store, navigation: WelcomeNavigation()) { [weak self] in
                self?.welcomeWindow?.close()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.title = tr("Welcome to Keyfari")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            welcomeWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: Permission

    private func waitForPermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXPermission.isGranted else { return }
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.permissionGranted()
            }
        }
    }

    private func permissionGranted() {
        log.notice("Accessibility permission granted")
        modes.start()
        installDebugTrigger()
        if store.effective.visionMode != .off {
            ScreenRecordingAccess.requestIfNeeded()
        }
        warmUpTextDetection()
    }
}

extension AppDelegate: NSMenuDelegate {
    /// The frontmost application is still the one the user was in, because this app is an accessory.
    func menuWillOpen(_ menu: NSMenu) {
        // The shortcuts are user-defined, so they are shown as text rather than as key equivalents.
        let settings = store.effective
        for entry in modeMenuItems {
            entry.item.title = "\(tr(entry.title))    \(settings[keyPath: entry.shortcut].displayString)"
        }
        settingsMenuItem?.title = tr("Settings…")
        updateMenuItem?.title = tr("Check for Updates…")
        welcomeMenuItem?.title = tr("Welcome Guide…")
        quitMenuItem?.title = tr("Quit Keyfari")
        guard let item = ignoreMenuItem else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let bundleID = frontmost?.bundleIdentifier,
            frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            item.isHidden = true
            return
        }
        item.isHidden = false
        item.title = tr("Ignore %@", frontmost?.localizedName ?? bundleID)
        item.state = store.settings.ignoredBundleIDs.contains(bundleID) ? .on : .off
    }
}

extension AppDelegate: NSWindowDelegate {
    /// Back to a menu bar app once the last of its windows is gone.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === settingsWindow {
            ShortcutRecording.shared.stop()
        } else if closing === welcomeWindow {
            // The guide starts from its first step the next time.
            welcomeWindow = nil
        } else {
            return
        }
        let stillOpen = [settingsWindow, welcomeWindow].contains { $0 != nil && $0 !== closing && $0?.isVisible == true }
        if !stillOpen { NSApp.setActivationPolicy(.accessory) }
    }
}
