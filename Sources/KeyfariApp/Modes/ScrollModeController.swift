// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// Runs one activation of scroll mode: find scroll areas, outline the active one, scroll on keys.
@MainActor
final class ScrollModeController {
    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "scroll")
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void
    private let scroller = ScrollSynthesizer()

    private var queryTask: Task<Void, Never>?
    /// Ends the mode when no key was pressed for the time set in the settings.
    private var idleTask: Task<Void, Never>?
    /// How many keys are down right now. The idle wait does not run while one is held.
    private var heldKeys = 0
    private var areas: [CGRect] = []
    private var session: ScrollSession?
    private var isActive = false

    init(
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.overlay = overlay
        self.interceptor = interceptor
        self.settings = settings
        self.onShortcut = onShortcut
        self.onExit = onExit
    }

    /// Returns false when the keyboard could not be intercepted, in which case nothing was started.
    func start(application: NSRunningApplication) -> Bool {
        let started = interceptor.start(
            onKeyDown: { [weak self] stroke in self?.keyDown(stroke) },
            onKeyUp: { [weak self] keyCode in self?.keyUp(keyCode) }
        )
        guard started else { return false }
        isActive = true

        let pid = application.processIdentifier
        let name = application.localizedName ?? "pid \(pid)"
        queryTask = Task { [weak self] in
            let found = (try? await AXScrollAreaQuery().scrollAreas(pid: pid)) ?? []
            guard let self, !Task.isCancelled, self.isActive else { return }
            self.log.notice("Found \(found.count) scroll areas in \(name, privacy: .public)")
            guard !found.isEmpty else {
                SoundFeedback.warningIfEnabled(settings.warningSoundEnabled)
                self.stop()
                return
            }
            self.areas = found
            self.session = ScrollSession(
                areaCount: found.count,
                keys: ScrollKeys(scroll: settings.scrollKeys, halfPage: settings.halfPageKeys) ?? .standard,
                arrowsScroll: settings.arrowKeysScroll
            )
            self.select(0)
            self.restartIdleTimer()
        }
        return true
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        queryTask?.cancel()
        queryTask = nil
        idleTask?.cancel()
        idleTask = nil
        scroller.stop()
        session = nil
        areas = []
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func select(_ index: Int) {
        let area = areas[index]
        overlay.showScrollArea(frame: area, index: settings.showScrollAreaNumbers ? index : nil)
        // Scroll events go to whatever is under the cursor.
        MouseSynthesizer.move(to: CGPoint(x: area.midX, y: area.midY))
    }

    /// Starts the wait for the idle timeout again. A key that is held keeps scrolling, so the
    /// wait only runs out once nothing is held.
    private func restartIdleTimer() {
        idleTask?.cancel()
        idleTask = nil
        guard settings.scrollIdleTimeout > 0, heldKeys == 0 else { return }
        let timeout = Duration.seconds(settings.scrollIdleTimeout)
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, !Task.isCancelled, self.isActive else { return }
            self.stop()
        }
    }

    private func keyDown(_ stroke: KeyStroke) {
        if !stroke.isRepeat { heldKeys += 1 }
        idleTask?.cancel()
        if onShortcut(stroke) { return }
        guard var current = session else {
            if stroke.keyCode == KeyCode.escape { stop() }
            return
        }
        let event = current.keyDown(stroke, at: ProcessInfo.processInfo.systemUptime)
        session = current
        apply(event, areaIndex: current.areaIndex)
    }

    private func keyUp(_ keyCode: UInt16) {
        heldKeys = max(heldKeys - 1, 0)
        restartIdleTimer()
        guard var current = session else { return }
        let event = current.keyUp(keyCode: keyCode)
        session = current
        apply(event, areaIndex: current.areaIndex)
    }

    private func apply(_ event: ScrollEvent, areaIndex: Int) {
        switch event {
        case let .start(direction, dash):
            let speed = Double(settings.scrollSpeed) * (dash ? settings.dashMultiplier : 1)
            scroller.start(
                direction,
                pixelsPerTick: max(Int(speed.rounded()), 1),
                reverseHorizontal: settings.reverseHorizontal,
                reverseVertical: settings.reverseVertical
            )
        case .stop:
            scroller.stop()
        case let .halfPage(direction):
            scroller.scroll(
                direction,
                pixels: Int(areas[areaIndex].height / 2),
                reverseHorizontal: settings.reverseHorizontal,
                reverseVertical: settings.reverseVertical
            )
        case .top:
            scroller.scrollToTop()
        case .bottom:
            scroller.scrollToBottom()
        case let .selectArea(index):
            scroller.stop()
            select(index)
        case .exit:
            stop()
        case .ignored:
            break
        }
    }
}
