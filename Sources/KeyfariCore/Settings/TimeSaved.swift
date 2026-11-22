// SPDX-License-Identifier: GPL-3.0-only

/// An estimate of the time the keyboard saved over reaching for the pointer.
public enum TimeSaved {
    /// What one keyboard action is taken to save.
    public static let secondsPerAction = 5

    public struct Parts: Equatable, Sendable {
        public let hours: Int
        public let minutes: Int
        public let seconds: Int
    }

    public static func seconds(actions: Int) -> Int {
        max(actions, 0) * secondsPerAction
    }

    /// Splits the estimate for `actions` into hours, minutes and seconds.
    public static func parts(actions: Int) -> Parts {
        let total = seconds(actions: actions)
        return Parts(hours: total / 3600, minutes: total % 3600 / 60, seconds: total % 60)
    }
}
