// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// Runs one activation of search click mode: query, filter by typed text, act on Return.
///
/// The focused window is searched first. With `hintAllWindows` on, the other visible windows
/// are read alongside it and join the search as they arrive, after the focused window's elements.
@MainActor
final class SearchModeController {
    /// An element that can be searched, and what is needed to click it.
    private struct Item {
        let element: ElementSnapshot
        /// The application the element belongs to, for the statistics.
        let bundleID: String
        /// Set when the element sits in a window that has to come forward before it takes a click.
        let window: BackgroundWindow?
    }

    /// How long a second Return may follow a click to turn it into a double click.
    static let doubleClickWindow: Duration = .milliseconds(300)

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "search")
    private let query: any ElementQuerying
    private let vision: VisionAugmenter?
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let target: @MainActor () -> ModeTarget?
    private let recordClick: @MainActor (String, Int, Bool) -> Void
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var task: Task<Void, Never>?
    private var visionTask: Task<Void, Never>?
    private var windowTasks: [Task<Void, Never>] = []
    /// Counts the queries, so results of an abandoned one are recognised and dropped.
    private var generation = 0
    /// What the focused window holds, with detected text once it arrived.
    private var focusedItems: [Item] = []
    /// What each background window holds, by its position from the front.
    private var windowItems: [Int: [Item]] = [:]
    /// Everything that is searched, in the order the session knows it.
    private var items: [Item] = []
    private var bundleID = ""
    /// The application of the click that a second Return would double.
    private var armedBundleID = ""
    private var session: SearchSession?
    /// The key strokes that changed the session, replayed when detection adds elements.
    private var appliedStrokes: [KeyStroke] = []
    /// Set while waiting for the second Return of a double click.
    private var armedPoint: CGPoint?
    private var isActive = false

    init(
        query: any ElementQuerying,
        vision: VisionAugmenter?,
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        target: @escaping @MainActor () -> ModeTarget?,
        recordClick: @escaping @MainActor (String, Int, Bool) -> Void,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.query = query
        self.vision = vision
        self.overlay = overlay
        self.interceptor = interceptor
        self.settings = settings
        self.target = target
        self.recordClick = recordClick
        self.onShortcut = onShortcut
        self.onExit = onExit
    }

    /// Returns false when the keyboard could not be intercepted, in which case nothing was started.
    func start() -> Bool {
        guard interceptor.start(onKeyDown: { [weak self] stroke in self?.handle(stroke) }) else {
            return false
        }
        isActive = true
        runQuery(after: .zero)
        return true
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        cancelTasks()
        session = nil
        clearItems()
        appliedStrokes = []
        armedPoint = nil
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func cancelTasks() {
        generation += 1
        task?.cancel()
        task = nil
        visionTask?.cancel()
        visionTask = nil
        windowTasks.forEach { $0.cancel() }
        windowTasks = []
    }

    private func clearItems() {
        focusedItems = []
        windowItems = [:]
        items = []
    }

    private func runQuery(after delay: Duration) {
        cancelTasks()
        let generation = generation
        task = Task { [weak self, query] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard let self, !Task.isCancelled, self.isActive, self.generation == generation else { return }
            guard let target = self.target() else {
                self.stop()
                return
            }
            let application = target.application
            let pid = application.processIdentifier
            self.bundleID = application.bundleIdentifier ?? ""
            self.searchBackgroundWindows(focusedPID: pid, generation: generation)
            let found =
                (try? await query.hintableElements(
                    pid: pid,
                    bundleURL: application.bundleURL,
                    otherPIDs: target.otherPIDs
                )) ?? []
            guard !Task.isCancelled, self.isActive, self.generation == generation else { return }
            // With detection on, an empty tree is not the end: the text regions may still arrive.
            // Neither is it while other windows are being read.
            guard !found.isEmpty || self.vision != nil || self.settings.hintAllWindows else {
                SoundFeedback.warningIfEnabled(self.settings.warningSoundEnabled)
                self.stop()
                return
            }
            self.log.notice("Searching \(found.count) elements in \(application.localizedName ?? "?", privacy: .public)")
            self.appliedStrokes = []
            self.focusedItems = found.map { Item(element: $0, bundleID: BackgroundWindows.owner(of: $0, frontmost: self.bundleID), window: nil) }
            self.rebuild()
            self.detectText(pid: pid, existing: found)
        }
    }

    /// Lists the other visible windows and reads each of them on its own thread.
    private func searchBackgroundWindows(focusedPID: pid_t, generation: Int) {
        guard settings.hintAllWindows else { return }
        let excluded = BackgroundWindows.excludedPIDs(ignoredBundleIDs: settings.ignoredBundleIDs)
        let limit = BackgroundWindows.limit
        let listing = Task { [weak self] in
            let windows = await Task.detached {
                VisibleWindowsQuery.backgroundWindows(focusedPID: focusedPID, excludedPIDs: excluded, limit: limit)
            }.value
            guard let self, !Task.isCancelled, self.generation == generation else { return }
            for (index, window) in windows.enumerated() {
                let bundleID = NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier ?? ""
                let reading = Task { [weak self] in
                    let found = await Task.detached { VisibleWindowsQuery.elements(in: window) }.value
                    guard let self, !Task.isCancelled, self.isActive, self.generation == generation, !found.isEmpty else { return }
                    self.windowItems[index] = found.map { Item(element: $0, bundleID: bundleID, window: window) }
                    // Not before the focused window is known: its elements come first.
                    if self.session != nil { self.rebuild() }
                }
                self.windowTasks.append(reading)
            }
        }
        windowTasks.append(listing)
    }

    /// Puts everything found so far in order and searches it for what was typed so far.
    private func rebuild() {
        func sorted(_ group: [Item]) -> [Item] {
            let order = ReadingOrder.sorted(group.map(\.element))
            // Reading order works on the elements alone, so each one is matched back to its item.
            var remaining = group
            return order.compactMap { element in
                guard let index = remaining.firstIndex(where: { $0.element == element }) else { return nil }
                return remaining.remove(at: index)
            }
        }
        items = sorted(focusedItems) + windowItems.keys.sorted().flatMap { sorted(windowItems[$0] ?? []) }
        var fresh = SearchSession(texts: items.map(\.element.searchText), alphabet: settings.hintAlphabet)
        // Whatever was typed so far applies to the new set of elements too.
        for stroke in appliedStrokes {
            _ = fresh.handle(stroke)
        }
        session = fresh
        render()
    }

    /// Adds on-screen text to the searchable elements once recognition finishes.
    private func detectText(pid: pid_t, existing: [ElementSnapshot]) {
        guard let vision else { return }
        visionTask = Task { [weak self] in
            let extras = await vision.additionalElements(pid: pid, existing: existing)
            guard let self, !Task.isCancelled, self.isActive, self.session != nil else { return }
            guard !extras.isEmpty else {
                if self.items.isEmpty, !self.settings.hintAllWindows {
                    SoundFeedback.warningIfEnabled(self.settings.warningSoundEnabled)
                    self.stop()
                }
                return
            }
            self.focusedItems.append(contentsOf: extras.map { Item(element: $0, bundleID: self.bundleID, window: nil) })
            self.rebuild()
        }
    }

    private func render() {
        guard let session else { return }
        let hints = zip(session.labels, session.matches).map { label, index in
            HintItem(label: label, point: items[index].element.clickPoint)
        }
        let elements = items.map(\.element)
        overlay.showSearch(
            query: session.query,
            labelPrefix: session.labelPrefix,
            items: hints,
            focus: session.focus,
            focusFrame: session.focusedIndex.map { elements[$0].clippedFrame },
            // The bar belongs on the screen of the focused window, not of the menu bar.
            anchor: (elements.first { $0.source == .window || $0.source == .vision } ?? elements.first)?.frame
        )
    }

    private func handle(_ stroke: KeyStroke) {
        if let point = armedPoint {
            // Only Return is intercepted while armed. Its auto-repeat must not count as a second press.
            guard !stroke.isRepeat else { return }
            MouseSynthesizer.secondClick(at: point)
            playSuccessSound(clickCount: 1)
            recordClick(armedBundleID, 1, false)
            stop()
            return
        }
        if onShortcut(stroke) { return }

        guard var current = session else {
            if stroke.keyCode == KeyCode.escape { stop() }
            return
        }
        let event = current.handle(stroke)
        session = current

        switch event {
        case .updated:
            appliedStrokes.append(stroke)
            render()
        case .rejected:
            SoundFeedback.warningIfEnabled(settings.warningSoundEnabled)
        case let .act(index, action):
            perform(action, on: items[index])
        case .exit:
            stop()
        case .ignored:
            break
        }
    }

    private func perform(_ action: ClickAction, on item: Item) {
        let element = item.element
        let point = element.clickPoint
        cancelTasks()
        session = nil
        overlay.hide()

        guard let window = item.window, action != .moveOnly else {
            finish(action, on: item, at: point)
            return
        }
        // Keys typed while the window comes forward are still swallowed, and Esc still leaves.
        let generation = generation
        task = Task { [weak self] in
            await BackgroundWindows.bringForward(window)
            guard let self, !Task.isCancelled, self.isActive, self.generation == generation else { return }
            self.finish(action, on: item, at: point)
        }
    }

    private func finish(_ action: ClickAction, on item: Item, at point: CGPoint) {
        MouseSynthesizer.perform(action, at: point)
        playSuccessSound(clickCount: action.clickCount)
        recordClick(item.bundleID, action.clickCount, true)

        if settings.chainClicks, action != .moveOnly, !item.element.acceptsText {
            clearItems()
            runQuery(after: HintModeController.chainDelay)
        } else if action == .left {
            // Keep only Return for a moment: a second press makes this a double click.
            // Every other key goes straight to the application.
            armedPoint = point
            armedBundleID = item.bundleID
            interceptor.swallowOnly = [KeyCode.return]
            task = Task { [weak self] in
                try? await Task.sleep(for: Self.doubleClickWindow)
                guard let self, !Task.isCancelled else { return }
                self.stop()
            }
        } else {
            stop()
        }
    }

    private func playSuccessSound(clickCount: Int) {
        guard settings.successSoundEnabled, clickCount > 0 else { return }
        SoundFeedback.success()
    }
}
