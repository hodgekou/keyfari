// SPDX-License-Identifier: GPL-3.0-only

import AXKit
import Foundation
import KeyfariCore
import ScreenVision
import os

/// Finds on-screen text that the accessibility tree does not expose.
///
/// Recognition takes several hundred milliseconds, so it runs after the regular labels are
/// already on screen and its results are added to them.
struct VisionAugmenter: Sendable {
    /// Below this many window elements the accessibility tree is considered empty.
    static let fallbackThreshold = 5

    let mode: VisionMode
    /// Whether shapes that look like icon buttons get labels too.
    var detectsIcons = false

    /// Extra elements for the focused window of `pid`, excluding anything `existing` already covers.
    /// Returns nothing when detection is off, not needed, not permitted, or fails.
    func additionalElements(pid: pid_t, existing: [ElementSnapshot]) async -> [ElementSnapshot] {
        guard mode != .off else { return [] }
        let log = Logger(subsystem: "app.keyfari.Keyfari", category: "vision")

        let windowElements = existing.filter { $0.source == .window }
        if mode == .fallback, windowElements.count >= Self.fallbackThreshold { return [] }
        guard ScreenTextDetector.hasPermission else {
            log.notice("Skipping vision detection: no Screen Recording permission")
            return []
        }
        guard let windowFrame = AXElementQuery.focusedWindowFrame(pid: pid) else { return [] }

        let started = ContinuousClock.now
        let scan: ScreenTextDetector.Scan
        do {
            scan = try await ScreenTextDetector.scan(pid: pid, windowFrame: windowFrame, includesOutlines: detectsIcons)
        } catch is CancellationError {
            return []
        } catch {
            log.error("Vision detection failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        let regions = scan.text
        let kept = VisionMerge.newRegions(regions.map(\.frame), existing: windowElements.map(\.clippedFrame))
        // Whatever is text or already has a label is not an icon of its own.
        let icons =
            detectsIcons
            ? IconCandidates.find(outlines: scan.outlines, occupied: windowElements.map(\.clippedFrame) + regions.map(\.frame))
            : []
        let elapsed = ContinuousClock.now - started
        log.notice(
            "Vision found \(regions.count) text regions, kept \(kept.count), and \(icons.count) icons, after \(elapsed.description, privacy: .public)"
        )
        let iconElements = icons.map { ElementSnapshot(role: "VisionIcon", frame: $0, source: .vision) }
        return iconElements
            + kept.map { index in
                ElementSnapshot(
                    role: "VisionText",
                    frame: regions[index].frame,
                    searchText: regions[index].text,
                    source: .vision
                )
            }
    }
}
