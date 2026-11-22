// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// Labels the windows and desktops of Mission Control: type a label to open its item.
@MainActor
final class MissionControlModeController {
    /// How often the overview is read again. It changes while it opens, when the Spaces bar
    /// unfolds and when the user moves to another desktop, and it can close at any time.
    private static let pollInterval: Duration = .milliseconds(200)
    /// How long the overview may take to appear after the mode started.
    private static let openingGrace: Duration = .milliseconds(1500)

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "mission-control")
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var pollTask: Task<Void, Never>?
    /// The items that carry labels right now.
    private var targets: [MissionControlTarget] = []
    private var labels: [String] = []
    private var session: MissionControlSession?
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
    func start() -> Bool {
        guard interceptor.start(onKeyDown: { [weak self] stroke in self?.handle(stroke) }) else { return false }
        // Arrow keys and the system's shortcuts stay with Mission Control.
        interceptor.swallowOnly = MissionControlSession.keyCodes
        isActive = true
        poll()
        return true
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        pollTask?.cancel()
        pollTask = nil
        session = nil
        targets = []
        labels = []
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func poll() {
        pollTask = Task { [weak self] in
            let started = ContinuousClock.now
            var wasShowing = false
            var previous: [MissionControlTarget]?
            while !Task.isCancelled {
                let displays = await Task.detached { MissionControlQuery.displays() }.value
                guard let self, !Task.isCancelled, self.isActive else { return }

                if displays.isEmpty {
                    // Closed, or it never opened.
                    if wasShowing || ContinuousClock.now - started > Self.openingGrace {
                        self.log.notice("Mission Control is not showing, leaving")
                        self.stop()
                        return
                    }
                } else {
                    wasShowing = true
                    // Every display shows its own overview, and all of them get labels at once.
                    let current = displays.flatMap(\.targets)
                    // Labels are drawn once two readings agree, so they do not chase an animation.
                    if current == previous, current != self.targets {
                        self.present(current)
                    }
                    previous = current
                }
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    private func present(_ found: [MissionControlTarget]) {
        log.notice("Labelling \(found.count) Mission Control items")
        targets = found
        labels = HintLabelGenerator.labels(count: found.count, alphabet: settings.hintAlphabet)
        guard !found.isEmpty, labels.count == found.count else {
            session = nil
            overlay.hide()
            return
        }
        session = MissionControlSession(labels: labels)
        overlay.showHints(zip(labels, found).map { HintItem(label: $0, point: $1.labelPoint) })
    }

    private func handle(_ stroke: KeyStroke) {
        if onShortcut(stroke) { return }

        guard var current = session else {
            // Nothing is labelled yet: only leaving makes sense.
            if stroke.keyCode == KeyCode.escape { leaveOverview() }
            return
        }
        let event = current.handle(stroke)
        session = current

        switch event {
        case let .updated(prefix):
            overlay.update(prefix: prefix)
        case let .matched(index):
            open(targets[index])
        case .rejected:
            SoundFeedback.warningIfEnabled(settings.warningSoundEnabled)
        case .exit:
            leaveOverview()
        case .ignored:
            break
        }
    }

    private func open(_ target: MissionControlTarget) {
        let playsSound = settings.successSoundEnabled
        let warns = settings.warningSoundEnabled
        let log = log
        stop()
        Task {
            let pressed = await Task.detached { target.press() }.value
            if pressed {
                if playsSound { SoundFeedback.success() }
            } else {
                log.error("Mission Control did not accept the selection")
                SoundFeedback.warningIfEnabled(warns)
            }
        }
    }

    /// Esc ends the labels and the overview together, as it does without Keyfari.
    private func leaveOverview() {
        stop()
        KeySynthesizer.press(keyCode: KeyCode.escape)
    }
}
