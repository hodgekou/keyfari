// SPDX-License-Identifier: GPL-3.0-only
// Derived from Utils.swift in Vimac (https://github.com/nchudleigh/vimac),
// Copyright © 2019 Dexter Leng, licensed under GPL-3.0.

import CoreGraphics
import KeyfariCore

/// Posts synthesized mouse events. Points use accessibility coordinates,
/// which are the coordinates Quartz events use.
public enum MouseSynthesizer {
    public static func perform(_ action: ClickAction, at point: CGPoint) {
        move(to: point)
        switch action {
        case .left:
            click(.left, at: point, clickState: 1, flags: [])
        case .right:
            click(.right, at: point, clickState: 1, flags: [])
        case .double:
            click(.left, at: point, clickState: 1, flags: [])
            click(.left, at: point, clickState: 2, flags: [])
        case .commandLeft:
            click(.left, at: point, clickState: 1, flags: .maskCommand)
        case .moveOnly:
            break
        }
    }

    /// The second click of a double click whose first click was already posted.
    public static func secondClick(at point: CGPoint) {
        click(.left, at: point, clickState: 2, flags: [])
    }

    /// Drags from one point to another: press, move across in steps, release.
    ///
    /// The pauses give the application under the pointer time to notice that a drag began and
    /// where it ended; without them most applications see a click, or drop too early.
    public static func drag(from start: CGPoint, to end: CGPoint) async {
        let steps = 12
        move(to: start)
        post(.leftMouseDown, button: .left, at: start, clickState: 1, flags: [])
        try? await Task.sleep(for: .milliseconds(120))
        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y + (end.y - start.y) * progress)
            post(.leftMouseDragged, button: .left, at: point, clickState: 1, flags: [])
            try? await Task.sleep(for: .milliseconds(20))
        }
        try? await Task.sleep(for: .milliseconds(120))
        post(.leftMouseUp, button: .left, at: end, clickState: 1, flags: [])
    }

    public static func move(to point: CGPoint) {
        post(.mouseMoved, button: .left, at: point, clickState: 0, flags: [])
    }

    private static func click(_ button: CGMouseButton, at point: CGPoint, clickState: Int64, flags: CGEventFlags) {
        let (down, up): (CGEventType, CGEventType) =
            button == .right
            ? (.rightMouseDown, .rightMouseUp)
            : (.leftMouseDown, .leftMouseUp)
        post(down, button: button, at: point, clickState: clickState, flags: flags)
        post(up, button: button, at: point, clickState: clickState, flags: flags)
    }

    private static func post(_ type: CGEventType, button: CGMouseButton, at point: CGPoint, clickState: Int64, flags: CGEventFlags) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
        if clickState > 0 {
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
        }
        // Set explicitly: the user may still hold the modifier that selected this action,
        // and it must not turn a right click into a shift-right click.
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}
