// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import ApplicationServices
import KeyfariCore

/// A window on screen that does not have the keyboard focus.
public struct BackgroundWindow: Sendable, Equatable {
    public let pid: pid_t
    /// In accessibility coordinates.
    public let frame: CGRect
    /// Frames of the windows in front of this one.
    let occluders: [CGRect]

    /// Brings the window to the front of its application. Blocking; call it off the main thread.
    ///
    /// A click on a window in the background only brings it forward in most applications,
    /// so the window is raised first and the click then lands on a window that listens.
    public func raise() {
        guard let window = VisibleWindowsQuery.accessibilityWindow(pid: pid, frame: frame) else { return }
        AXUIElementPerformAction(window.raw, kAXRaiseAction as CFString)
        window.setBool(true, for: kAXMainAttribute)
    }
}

/// Finds the windows that are visible besides the focused one, and what can be clicked in them.
///
/// Every call is a blocking cross-process request, so call them off the main thread.
public enum VisibleWindowsQuery {
    /// A window smaller than this in either direction is a tooltip or an indicator, not a window to work in.
    private static let minimumSide: CGFloat = 80
    /// Below this visible share a window is treated as covered.
    private static let minimumVisibleFraction = 0.08
    /// How far two frames of the same window may differ between the window server and accessibility.
    private static let frameTolerance: CGFloat = 3

    /// The visible windows other than the focused one, front to back.
    /// - Parameters:
    ///   - focusedPID: the frontmost application, whose focused window is handled separately.
    ///   - excludedPIDs: applications whose windows are left alone.
    ///   - limit: the most windows to return, counted from the front.
    public static func backgroundWindows(focusedPID: pid_t, excludedPIDs: Set<pid_t>, limit: Int) -> [BackgroundWindow] {
        let focusedFrame = AXElementQuery.focusedWindowFrame(pid: focusedPID)
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        var result: [BackgroundWindow] = []
        var inFront: [CGRect] = []
        // The list runs front to back, so everything seen so far covers what follows.
        for entry in list {
            guard (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: bounds),
                ((entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0
            else { continue }
            defer { inFront.append(frame) }

            guard frame.width >= minimumSide, frame.height >= minimumSide, !excludedPIDs.contains(pid) else { continue }
            if pid == focusedPID, let focusedFrame, matches(frame, focusedFrame) { continue }
            guard WindowOcclusion.visibleFraction(of: frame, behind: inFront) >= minimumVisibleFraction else { continue }
            if result.count < limit {
                result.append(BackgroundWindow(pid: pid, frame: frame, occluders: inFront))
            }
        }
        return result
    }

    /// Everything in `window` that should get a label and is not covered by a window in front.
    public static func elements(in window: BackgroundWindow, nodeBudget: Int = 1500) -> [ElementSnapshot] {
        let application = AXElement.application(pid: window.pid)
        application.setMessagingTimeout(seconds: 0.25)
        AppAccessibilityActivator.prepare(
            application: application, pid: window.pid,
            bundleURL: NSRunningApplication(processIdentifier: window.pid)?.bundleURL
        )
        // Reading the role wakes Chromium's accessibility tree.
        _ = try? application.role()
        guard let element = accessibilityWindow(pid: window.pid, frame: window.frame) else { return [] }

        let traversal = TreeTraversal(budget: nodeBudget)
        guard let root = try? traversal.visit(element, clip: nil) else { return [] }
        return traversal.hintableSnapshots(root: root, source: .window).filter { snapshot in
            window.frame.contains(snapshot.clickPoint) && WindowOcclusion.isVisible(snapshot.clickPoint, behind: window.occluders)
        }
    }

    /// The accessibility element of the window that the window server reports at `frame`.
    static func accessibilityWindow(pid: pid_t, frame: CGRect) -> AXElement? {
        let application = AXElement.application(pid: pid)
        application.setMessagingTimeout(seconds: 0.25)
        return AXDecode.elements(try? application.value(of: kAXWindowsAttribute)).first { window in
            let values = window.values(of: [kAXPositionAttribute, kAXSizeAttribute])
            guard let windowFrame = AXDecode.frame(position: values[0], size: values[1]) else { return false }
            return matches(windowFrame, frame)
        }
    }

    private static func matches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= frameTolerance && abs(lhs.minY - rhs.minY) <= frameTolerance
            && abs(lhs.width - rhs.width) <= frameTolerance && abs(lhs.height - rhs.height) <= frameTolerance
    }
}
