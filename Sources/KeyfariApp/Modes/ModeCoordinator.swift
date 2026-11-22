// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

enum Mode: Equatable {
    case hint
    case search
    case scroll
}

/// Owns the global shortcuts and makes sure at most one mode is active.
@MainActor
final class ModeCoordinator {
    /// What a global shortcut triggers.
    private enum Command: Equatable {
        case mode(Mode)
        case space(SpaceDirection)
    }

    private struct Binding: Equatable {
        let command: Command
        let shortcut: Shortcut
    }

    /// The global shortcuts, from the settings in force.
    private var shortcuts: [Binding] = []

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "mode")
    private let store: SettingsStore
    private let hotkeys = GlobalHotkeys()
    private let overlay = OverlayController()
    private let interceptor = KeyInterceptor()
    private lazy var spaces = SpaceController(store: store)
    private var keySequence: KeySequenceActivator?
    private var active: (mode: Mode, stop: @MainActor () -> Void)?

    init(store: SettingsStore) {
        self.store = store
    }

    /// Registers the shortcuts. Call once the Accessibility permission is granted.
    func start() {
        store.onChange = { [weak self] in self?.applySettings() }
        applySettings()
    }

    private func registerShortcuts(_ settings: Settings) {
        var wanted = [
            Binding(command: .mode(.hint), shortcut: settings.hintShortcut),
            Binding(command: .mode(.search), shortcut: settings.searchShortcut),
            Binding(command: .mode(.scroll), shortcut: settings.scrollShortcut),
        ]
        let systemShortcuts = SpaceDirection.allCases.compactMap(SystemSpaces.shortcut)
        for direction in SpaceDirection.allCases {
            guard let shortcut = settings[keyPath: Settings.spaceShortcut(direction)] else { continue }
            // Keyfari changes Spaces by pressing the system's shortcut. Owning the same keys
            // would catch that press, and the system handles them already.
            guard !systemShortcuts.contains(shortcut) else {
                log.notice("Leaving \(shortcut.displayString, privacy: .public) to the system")
                continue
            }
            wanted.append(Binding(command: .space(direction), shortcut: shortcut))
        }
        guard wanted != shortcuts else { return }

        hotkeys.unregisterAll()
        shortcuts = wanted
        for binding in wanted {
            let shortcut = binding.shortcut
            let registered = hotkeys.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
                self?.run(binding.command)
            }
            if registered {
                log.notice("Registered \(shortcut.displayString, privacy: .public)")
            } else {
                log.error("Could not register \(shortcut.displayString, privacy: .public); another application may own it")
            }
        }
    }

    private func run(_ command: Command) {
        switch command {
        case let .mode(mode):
            toggle(mode)
        case let .space(direction):
            // Labels drawn for this Space mean nothing on the next one.
            active?.stop()
            spaces.switchSpace(direction)
        }
    }

    /// Starts or stops the optional activators to match the settings.
    func applySettings() {
        let settings = store.effective
        keySequence?.stop()
        keySequence = nil
        guard AXPermission.isGranted else { return }
        registerShortcuts(settings)

        let isSuppressed: @MainActor () -> Bool = { [weak self] in
            guard let self else { return true }
            return self.active != nil || self.eligibleApplication() == nil
        }

        let bindings = [(settings.hintKeySequence, Mode.hint), (settings.scrollKeySequence, Mode.scroll)]
            .filter { !$0.0.isEmpty }
        if !bindings.isEmpty {
            let activator = KeySequenceActivator(
                sequences: bindings.map(\.0),
                resetDelay: settings.keySequenceResetDelay,
                isSuppressed: isSuppressed
            ) { [weak self] index in
                self?.toggle(bindings[index].1)
            }
            if activator.start() { keySequence = activator }
        }
    }

    /// Activates `mode`, or leaves it when it is already active. Another active mode is replaced.
    func toggle(_ mode: Mode) {
        if let active {
            active.stop()
            if active.mode == mode { return }
        }

        guard AXPermission.isGranted else { return refuse("the Accessibility permission is missing") }
        // Event taps receive nothing while a password field holds secure input.
        guard !SecureInput.isEnabled else { return refuse("secure input is active") }
        guard let application = currentTarget()?.application else {
            return refuse("the frontmost application is missing, ignored, or Keyfari itself")
        }

        let settings = store.effective
        let target: @MainActor () -> ModeTarget? = { [weak self] in self?.currentTarget() }
        let recordClick: @MainActor (String, Int) -> Void = { [weak self] bundleID, count in
            self?.store.recordClick(bundleID: bundleID, count: count)
        }
        let onShortcut: @MainActor (KeyStroke) -> Bool = { [weak self] stroke in
            self?.handleShortcut(stroke) ?? false
        }
        let onExit: @MainActor () -> Void = { [weak self] in
            self?.active = nil
        }

        let started: Bool
        let stop: @MainActor () -> Void
        switch mode {
        case .hint:
            applyStyle(settings)
            let controller = HintModeController(
                query: AXElementQuery(), vision: vision(settings), overlay: overlay, interceptor: interceptor, settings: settings,
                memory: store.labelMemory,
                target: target, recordClick: recordClick, onShortcut: onShortcut, onExit: onExit
            )
            started = controller.start()
            stop = { controller.stop() }
        case .search:
            applyStyle(settings)
            let controller = SearchModeController(
                query: AXElementQuery(), vision: vision(settings), overlay: overlay, interceptor: interceptor, settings: settings,
                target: target, recordClick: recordClick, onShortcut: onShortcut, onExit: onExit
            )
            started = controller.start()
            stop = { controller.stop() }
        case .scroll:
            let controller = ScrollModeController(
                overlay: overlay, interceptor: interceptor, settings: settings,
                onShortcut: onShortcut, onExit: onExit
            )
            started = controller.start(application: application)
            stop = { controller.stop() }
        }

        guard started else { return refuse("the keyboard could not be intercepted") }
        active = (mode, stop)
    }

    private func applyStyle(_ settings: Settings) {
        overlay.style.fontSize = settings.hintFontSize
        overlay.style.cornerRadius = settings.hintCornerRadius
        overlay.style.theme = settings.hintTheme.isAvailable ? settings.hintTheme : .vivid
        overlay.searchPlaceholder = tr("Type to search")
        overlay.matchCountText = { $0 == 1 ? tr("1 match") : tr("%d matches", $0) }
    }

    private func vision(_ settings: Settings) -> VisionAugmenter? {
        settings.visionMode == .off ? nil : VisionAugmenter(mode: settings.visionMode)
    }

    /// The frontmost application, unless it is this app or on the ignore list.
    private func currentTarget() -> ModeTarget? {
        guard let application = eligibleApplication() else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let otherPIDs = NSWorkspace.shared.runningApplications
            .map(\.processIdentifier)
            .filter { $0 != ownPID && $0 != application.processIdentifier }
        return ModeTarget(application: application, otherPIDs: otherPIDs)
    }

    /// Whether a keyboard activation gesture may act on the current frontmost application.
    private func eligibleApplication() -> NSRunningApplication? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let application = NSWorkspace.shared.frontmostApplication,
            application.processIdentifier != ownPID
        else { return nil }
        if let bundleID = application.bundleIdentifier, store.effective.ignoredBundleIDs.contains(bundleID) {
            return nil
        }
        return application
    }

    /// While a mode is active its event tap sees the shortcuts before the system does,
    /// so they are recognised here. Returns true when the key stroke was a shortcut.
    private func handleShortcut(_ stroke: KeyStroke) -> Bool {
        guard let match = shortcuts.first(where: { $0.shortcut.matches(stroke) }) else { return false }
        if !stroke.isRepeat {
            run(match.command)
        }
        return true
    }

    private func refuse(_ reason: String) {
        log.notice("Not activating: \(reason, privacy: .public)")
        SoundFeedback.warningIfEnabled(store.effective.warningSoundEnabled)
    }
}
