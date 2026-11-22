// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import AppKit
import InputKit
import KeyfariCore
import OverlayKit
import os

/// The application a mode acts on.
struct ModeTarget {
    let application: NSRunningApplication
    /// Every other running application, searched for menu bar extras.
    let otherPIDs: [pid_t]
}

/// Runs one activation of label click mode: query, show labels, read keys, click.
///
/// The focused window comes first. With `hintAllWindows` on, the other visible windows are read
/// alongside it: those on the display under the pointer share the short labels and appear
/// together with the focused window, the rest follow with longer labels of their own.
@MainActor
final class HintModeController {
    /// How long a click chain waits for the interface to settle before it queries again.
    static let chainDelay: Duration = .milliseconds(250)
    /// How long the first labels wait for the other windows on the pointer's display once the
    /// focused window is known. A window that takes longer joins the later ones.
    private static let nearbyDeadline: Duration = .milliseconds(300)
    /// How long the windows on other displays may take before they go without labels.
    private static let distantDeadline: Duration = .milliseconds(2500)

    /// How many text regions detection found last time, per application. It sizes the block of
    /// labels set aside for detection, which has to be decided before detection finishes.
    private static var detectedCounts: [String: Int] = [:]
    private static let defaultReserve = 40

    /// An element with a label, and what is needed to click it.
    private struct Target {
        let element: ElementSnapshot
        /// The application the element belongs to, for label memory and statistics.
        let bundleID: String
        /// Set when the element sits in a window that has to come forward before it takes a click.
        let window: BackgroundWindow?
        /// Whether its label came from the block for later windows, which is not remembered.
        var isSecondary = false
    }

    /// What one background window turned out to hold.
    private struct WindowResult {
        let window: BackgroundWindow
        let bundleID: String
        let elements: [ElementSnapshot]
    }

    private let log = Logger(subsystem: "app.keyfari.Keyfari", category: "hint")
    private let query: any ElementQuerying
    private let vision: VisionAugmenter?
    private let overlay: OverlayController
    private let interceptor: KeyInterceptor
    private let settings: Settings
    private let memory: LabelMemory?
    private let target: @MainActor () -> ModeTarget?
    private let recordClick: @MainActor (String, Int, Bool) -> Void
    private let rememberClick: @MainActor (ElementSnapshot, String, ClickAction) -> Void
    private let onShortcut: @MainActor (KeyStroke) -> Bool
    private let onExit: @MainActor () -> Void

    private var queryTask: Task<Void, Never>?
    private var visionTask: Task<Void, Never>?
    private var windowTasks: [Task<Void, Never>] = []
    private var deadlineTask: Task<Void, Never>?
    /// Counts the queries, so results of an abandoned one are recognised and dropped.
    private var generation = 0

    /// The focused window's elements, once known.
    private var focused: (elements: [ElementSnapshot], pid: pid_t)?
    /// The background windows of this query, or nil while they are still being listed.
    private var windows: [BackgroundWindow]?
    /// Results by position in `windows`.
    private var windowResults: [Int: WindowResult] = [:]
    /// Positions in `windows` that are on the display under the pointer.
    private var nearby = Set<Int>()
    /// Positions in `windows` whose elements already carry labels.
    private var labelled = Set<Int>()
    private var nearbyExpired = false
    private var distantExpired = false
    private var hasShownFirstLabels = false
    private var hasAddedDistantLabels = false

    private var targets: [Target] = []
    private var labels: [String] = []
    /// Labels generated together with the shown ones and kept for elements that detection adds.
    private var reservedLabels: [String] = []
    /// The frontmost application of this query.
    private var bundleID = ""
    private var session: HintSession?
    private var isActive = false

    /// - Parameters:
    ///   - vision: adds on-screen text after the first labels are shown; nil when detection is off.
    ///   - target: returns the frontmost application, or nil when no mode may act on it.
    init(
        query: any ElementQuerying,
        vision: VisionAugmenter?,
        overlay: OverlayController,
        interceptor: KeyInterceptor,
        settings: Settings,
        memory: LabelMemory?,
        target: @escaping @MainActor () -> ModeTarget?,
        recordClick: @escaping @MainActor (String, Int, Bool) -> Void,
        rememberClick: @escaping @MainActor (ElementSnapshot, String, ClickAction) -> Void,
        onShortcut: @escaping @MainActor (KeyStroke) -> Bool,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.query = query
        self.vision = vision
        self.overlay = overlay
        self.interceptor = interceptor
        self.settings = settings
        self.memory = memory
        self.target = target
        self.recordClick = recordClick
        self.rememberClick = rememberClick
        self.onShortcut = onShortcut
        self.onExit = onExit
    }

    /// Returns false when the keyboard could not be intercepted, in which case nothing was started.
    func start() -> Bool {
        // Keys are swallowed from the first moment so that nothing typed during the query reaches the application.
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
        clearState()
        overlay.hide()
        interceptor.stop()
        onExit()
    }

    private func cancelTasks() {
        generation += 1
        queryTask?.cancel()
        queryTask = nil
        visionTask?.cancel()
        visionTask = nil
        windowTasks.forEach { $0.cancel() }
        windowTasks = []
        deadlineTask?.cancel()
        deadlineTask = nil
    }

    private func clearState() {
        session = nil
        targets = []
        labels = []
        reservedLabels = []
        focused = nil
        windows = nil
        windowResults = [:]
        nearby = []
        labelled = []
        nearbyExpired = false
        distantExpired = false
        hasShownFirstLabels = false
        hasAddedDistantLabels = false
    }

    // MARK: Query

    private func runQuery(after delay: Duration) {
        cancelTasks()
        let generation = generation
        queryTask = Task { [weak self, query] in
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
            let name = application.localizedName ?? "pid \(pid)"
            let started = ContinuousClock.now
            self.bundleID = application.bundleIdentifier ?? ""
            self.queryBackgroundWindows(focusedPID: pid, generation: generation)

            let found =
                (try? await query.hintableElements(
                    pid: pid,
                    bundleURL: application.bundleURL,
                    otherPIDs: target.otherPIDs
                )) ?? []
            guard !Task.isCancelled, self.isActive, self.generation == generation else { return }
            let elapsed = ContinuousClock.now - started
            self.log.notice("Found \(found.count) elements in \(name, privacy: .public) after \(elapsed.description, privacy: .public)")

            self.focused = (found, pid)
            self.startDeadline(Self.nearbyDeadline, generation: generation) { $0.nearbyExpired = true }
            self.advance()
        }
    }

    /// Lists the other visible windows and reads each of them on its own thread.
    private func queryBackgroundWindows(focusedPID: pid_t, generation: Int) {
        guard settings.hintAllWindows else {
            windows = []
            return
        }
        let excluded = BackgroundWindows.excludedPIDs(ignoredBundleIDs: settings.ignoredBundleIDs)
        let pointer = CGEvent(source: nil)?.location ?? .zero
        let displays = AXElementQuery.activeDisplayBounds()
        let limit = BackgroundWindows.limit

        let listing = Task { [weak self] in
            let found = await Task.detached {
                VisibleWindowsQuery.backgroundWindows(focusedPID: focusedPID, excludedPIDs: excluded, limit: limit)
            }.value
            guard let self, !Task.isCancelled, self.generation == generation else { return }
            self.windows = found
            let pointerDisplay = displays.firstIndex { $0.contains(pointer) }
            for (index, window) in found.enumerated() {
                if ScreenGeometry.indexOfScreen(containing: window.frame, screenFrames: displays) == pointerDisplay {
                    self.nearby.insert(index)
                }
                self.read(window, at: index, generation: generation)
            }
            self.advance()
        }
        windowTasks.append(listing)
    }

    private func read(_ window: BackgroundWindow, at index: Int, generation: Int) {
        let bundleID = NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier ?? ""
        let task = Task { [weak self] in
            let elements = await Task.detached { VisibleWindowsQuery.elements(in: window) }.value
            guard let self, !Task.isCancelled, self.generation == generation else { return }
            self.windowResults[index] = WindowResult(window: window, bundleID: bundleID, elements: elements)
            self.advance()
        }
        windowTasks.append(task)
    }

    private func startDeadline(_ duration: Duration, generation: Int, expire: @escaping @MainActor (HintModeController) -> Void) {
        deadlineTask?.cancel()
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, !Task.isCancelled, self.generation == generation else { return }
            expire(self)
            self.advance()
        }
    }

    /// Shows whatever has become ready. Called whenever a result or a deadline arrives.
    private func advance() {
        guard isActive, let focused else { return }

        if !hasShownFirstLabels {
            // Wait for the windows next to the focused one, but not for long.
            let nearbyReady = windows != nil && nearby.allSatisfy { windowResults[$0] != nil }
            guard nearbyReady || nearbyExpired else { return }
            hasShownFirstLabels = true
            let ready = nearby.sorted().compactMap { index in windowResults[index].map { (index, $0) } }
            labelled.formUnion(ready.map(\.0))
            showFirstLabels(focused: focused.elements, nearby: ready.map(\.1))
            guard isActive else { return }
            detectText(pid: focused.pid, existing: focused.elements)
            startDeadline(Self.distantDeadline, generation: generation) { $0.distantExpired = true }
        }

        guard !hasAddedDistantLabels, let windows else { return }
        let allRead = windows.indices.allSatisfy { windowResults[$0] != nil }
        guard allRead || distantExpired else { return }
        hasAddedDistantLabels = true
        deadlineTask?.cancel()
        let rest = windows.indices.filter { !labelled.contains($0) }.compactMap { windowResults[$0] }
        addDistantLabels(rest)
    }

    // MARK: Labels

    /// The letter kept out of the first labels so later windows can have labels of their own.
    /// Only needed when later windows can exist at all.
    private var secondaryLead: Character? {
        settings.hintAllWindows ? StableLabels.secondaryLead(alphabet: settings.hintAlphabet) : nil
    }

    private func showFirstLabels(focused: [ElementSnapshot], nearby: [WindowResult]) {
        var found = focused.map { Target(element: $0, bundleID: BackgroundWindows.owner(of: $0, frontmost: bundleID), window: nil) }
        for result in nearby {
            found.append(contentsOf: result.elements.map { Target(element: $0, bundleID: result.bundleID, window: result.window) })
        }
        // With detection on, an empty tree is not the end: the text regions may still arrive.
        // Neither is it with more windows still being read.
        let moreToCome = vision != nil || (settings.hintAllWindows && !hasAddedDistantLabels)
        guard !found.isEmpty || moreToCome else {
            SoundFeedback.warningIfEnabled(settings.warningSoundEnabled)
            stop()
            return
        }

        // All labels are generated at once, including a block for detection, so the ones added
        // later can never be a prefix of the ones already on screen, or the other way round.
        let reserve = vision == nil ? 0 : (Self.detectedCounts[bundleID] ?? Self.defaultReserve) + 10
        let all = assignLabels(to: found, reserve: reserve)

        targets = found
        labels = Array(all.prefix(found.count))
        reservedLabels = Array(all.dropFirst(found.count))
        session = HintSession(labels: labels)
        overlay.showHints(zip(labels, found).map { HintItem(label: $0, point: $1.element.clickPoint) })
    }

    private func assignLabels(to found: [Target], reserve: Int) -> [String] {
        let elements = found.map(\.element)
        if let memory {
            return memory.book.assign(
                to: elements, bundleIDs: found.map(\.bundleID), alphabet: settings.hintAlphabet, reserve: reserve,
                useMemory: settings.stableLabels, excludedLead: secondaryLead
            )
        }
        return StableLabels.assign(
            fingerprints: [String?](repeating: nil, count: elements.count + reserve), alphabet: settings.hintAlphabet, memory: [:],
            excludedLead: secondaryLead
        )
    }

    /// Adds labels for the windows that were not part of the first labels: those on other
    /// displays, and any on the pointer's display that took too long.
    private func addDistantLabels(_ results: [WindowResult]) {
        let added = results.flatMap { result in
            result.elements.map { Target(element: $0, bundleID: result.bundleID, window: result.window, isSecondary: true) }
        }
        guard !added.isEmpty, let lead = secondaryLead, var current = session else {
            finishIfEmpty()
            return
        }
        let newLabels = StableLabels.secondaryLabels(
            count: added.count, alphabet: settings.hintAlphabet, lead: lead, avoiding: labels + reservedLabels
        )
        guard newLabels.count == added.count else {
            finishIfEmpty()
            return
        }
        log.notice("Adding \(added.count) elements from \(results.count) more windows")
        append(added, labels: newLabels, to: &current)
    }

    /// Adds labels for on-screen text once recognition finishes. The labels already shown do not change.
    /// Only the focused window is read this way: recognition is too slow to run on every window.
    private func detectText(pid: pid_t, existing: [ElementSnapshot]) {
        guard let vision else { return }
        let generation = generation
        visionTask = Task { [weak self] in
            let extras = await vision.additionalElements(pid: pid, existing: existing)
            guard let self, !Task.isCancelled, self.isActive, self.generation == generation, var current = self.session else { return }

            Self.detectedCounts[self.bundleID] = extras.count
            // More regions than reserved labels: the rest go without, and the reserve grows next time.
            let added = extras.prefix(self.reservedLabels.count).map { Target(element: $0, bundleID: self.bundleID, window: nil) }
            self.visionTask = nil
            guard !added.isEmpty else {
                self.finishIfEmpty()
                return
            }
            let newLabels = Array(self.reservedLabels.prefix(added.count))
            self.reservedLabels.removeFirst(added.count)
            self.append(added, labels: newLabels, to: &current)
        }
    }

    private func append(_ added: [Target], labels newLabels: [String], to current: inout HintSession) {
        targets.append(contentsOf: added)
        labels.append(contentsOf: newLabels)
        current.append(labels: newLabels)
        session = current
        overlay.appendHints(
            zip(newLabels, added).map { HintItem(label: $0, point: $1.element.clickPoint) },
            typedPrefix: current.prefix
        )
    }

    /// Leaves the mode once nothing has a label and nothing more can arrive.
    private func finishIfEmpty() {
        guard targets.isEmpty, visionTask == nil, hasAddedDistantLabels else { return }
        SoundFeedback.warningIfEnabled(settings.warningSoundEnabled)
        stop()
    }

    // MARK: Keys

    private func handle(_ stroke: KeyStroke) {
        if onShortcut(stroke) { return }

        guard var current = session else {
            // Still querying: only leaving the mode makes sense.
            if stroke.keyCode == KeyCode.escape { stop() }
            return
        }

        let event = current.handle(stroke)
        session = current

        switch event {
        case let .updated(prefix, _):
            overlay.update(prefix: prefix)
        case .rejected:
            SoundFeedback.warningIfEnabled(settings.warningSoundEnabled)
        case .rotate:
            overlay.rotate()
        case let .matched(index, action):
            let target = targets[index]
            if settings.stableLabels, !target.isSecondary {
                memory?.remember(labels[index], for: target.element, bundleID: target.bundleID)
            }
            perform(action, on: target)
        case .exit:
            stop()
        case .ignored:
            break
        }
    }

    private func perform(_ action: ClickAction, on target: Target) {
        // A chain stops on text fields, otherwise the text typed next would be read as labels.
        let continues = settings.chainClicks && action != .moveOnly && !target.element.acceptsText
        if continues {
            cancelTasks()
            clearState()
            overlay.hide()
        } else {
            stop()
        }

        let point = target.element.clickPoint
        let click: @MainActor () -> Void = { [recordClick, rememberClick, settings] in
            MouseSynthesizer.perform(action, at: point)
            rememberClick(target.element, target.bundleID, action)
            if settings.successSoundEnabled, action.clickCount > 0 { SoundFeedback.success() }
            recordClick(target.bundleID, action.clickCount, true)
        }

        guard let window = target.window, action != .moveOnly else {
            click()
            if continues { runQuery(after: Self.chainDelay) }
            return
        }
        // The window is in the background: it comes forward first, like it would under a real
        // pointer, and takes the click once it listens.
        Task { [weak self] in
            await BackgroundWindows.bringForward(window)
            click()
            if continues { self?.runQuery(after: Self.chainDelay) }
        }
    }
}
