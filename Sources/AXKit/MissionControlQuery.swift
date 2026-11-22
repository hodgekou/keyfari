// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import ApplicationServices
import KeyfariCore

/// A window or a desktop shown in Mission Control.
public struct MissionControlTarget: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case window
        case space
    }

    public let kind: Kind
    public let title: String
    /// The part of the item that is on screen, in accessibility coordinates.
    public let frame: CGRect
    public let labelPoint: CGPoint
    let element: AXElement

    /// Opens the item, which also leaves Mission Control. Blocking; call it off the main thread.
    public func press() -> Bool {
        AXUIElementPerformAction(element.raw, kAXPressAction as CFString) == .success
    }
}

/// The overview Mission Control draws on one display.
public struct MissionControlDisplay: Sendable, Equatable {
    public let frame: CGRect
    public let targets: [MissionControlTarget]
}

/// Reads Mission Control through the accessibility tree of the process that draws it.
///
/// Every call is a blocking cross-process request, so call them off the main thread.
public enum MissionControlQuery {
    /// The Dock draws Mission Control up to macOS 15; later systems moved it to WindowManager.
    private static let hosts = ["com.apple.WindowManager", "com.apple.dock"]

    private static let displayIdentifier = "mc.display"
    private static let spacesBarIdentifier = "mc.spaces.list"
    private static let addDesktopIdentifier = "mc.spaces.add"
    private static let attributes = [
        kAXRoleAttribute, kAXIdentifierAttribute, kAXPositionAttribute, kAXSizeAttribute,
        kAXTitleAttribute, kAXChildrenAttribute, "wid",
    ]

    public static func isShowing() -> Bool {
        !displayGroups().isEmpty
    }

    /// One entry per display while Mission Control is showing, otherwise empty.
    public static func displays() -> [MissionControlDisplay] {
        let groups = displayGroups()
        guard !groups.isEmpty else { return [] }
        let onScreen = onScreenWindowIDs()
        return groups.compactMap { group in
            let values = group.values(of: attributes)
            guard let frame = AXDecode.frame(position: values[2], size: values[3]) else { return nil }
            var windows: [MissionControlTarget] = []
            var spaces: [MissionControlTarget] = []
            var budget = 400
            for child in AXDecode.elements(values[5]) {
                collect(child, display: frame, bar: nil, onScreen: onScreen, depth: 0, budget: &budget, windows: &windows, spaces: &spaces)
            }
            spaces.sort { $0.labelPoint.x < $1.labelPoint.x }
            let order = MissionControlLayout.readingOrder(windows.map(\.frame))
            return MissionControlDisplay(frame: frame, targets: spaces + order.map { windows[$0] })
        }
    }

    /// The groups that hold the overview of one display each.
    private static func displayGroups() -> [AXElement] {
        var result: [AXElement] = []
        for bundleID in hosts {
            guard let host = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { continue }
            let application = AXElement.application(pid: host.processIdentifier)
            application.setMessagingTimeout(seconds: 0.25)
            findDisplayGroups(in: application, depth: 0, into: &result)
            if !result.isEmpty { break }
        }
        return result
    }

    private static func findDisplayGroups(in element: AXElement, depth: Int, into result: inout [AXElement]) {
        for child in AXDecode.elements(try? element.value(of: kAXChildrenAttribute)) {
            let values = child.values(of: [kAXRoleAttribute, kAXIdentifierAttribute])
            // Only groups can lead there; the Dock's own list of icons is not walked.
            guard values[0] as? String == "AXGroup" else { continue }
            if values[1] as? String == displayIdentifier {
                result.append(child)
            } else if depth < 2 {
                findDisplayGroups(in: child, depth: depth + 1, into: &result)
            }
        }
    }

    private static func collect(
        _ element: AXElement,
        display: CGRect,
        bar: CGRect?,
        onScreen: Set<Int>,
        depth: Int,
        budget: inout Int,
        windows: inout [MissionControlTarget],
        spaces: inout [MissionControlTarget]
    ) {
        guard budget > 0, depth < 5 else { return }
        budget -= 1
        let values = element.values(of: attributes)
        guard let role = values[0] as? String else { return }
        let identifier = values[1] as? String
        let frame = AXDecode.frame(position: values[2], size: values[3])

        if role == "AXButton" {
            guard identifier != addDesktopIdentifier, let frame else { return }
            let title = values[4] as? String ?? ""
            if let bar {
                let visible = frame.intersection(bar)
                guard !visible.isNull, !visible.isEmpty else { return }
                let point = MissionControlLayout.spaceLabelPoint(button: frame, bar: bar)
                spaces.append(MissionControlTarget(kind: .space, title: title, frame: visible, labelPoint: point, element: element))
            } else {
                // The overview also lists the windows of other Spaces, which it does not draw.
                if let windowID = values[6] as? NSNumber, !onScreen.contains(windowID.intValue) { return }
                let visible = frame.intersection(display)
                guard !visible.isNull, !visible.isEmpty else { return }
                let point = CGPoint(x: visible.midX, y: visible.midY)
                windows.append(MissionControlTarget(kind: .window, title: title, frame: visible, labelPoint: point, element: element))
            }
            return
        }

        let innerBar = identifier == spacesBarIdentifier ? frame : bar
        for child in AXDecode.elements(values[5]) {
            collect(
                child, display: display, bar: innerBar, onScreen: onScreen, depth: depth + 1, budget: &budget, windows: &windows,
                spaces: &spaces)
        }
    }

    /// Numbers of the windows of the current Space.
    private static func onScreenWindowIDs() -> Set<Int> {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue })
    }
}
