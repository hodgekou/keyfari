// SPDX-License-Identifier: GPL-3.0-only

/// Decides whether the welcome guide opens by itself.
public enum FirstLaunch {
    /// The guide is for a first launch only. Someone who already has settings has used the
    /// app before the guide existed and does not need it sprung on them.
    public static func shouldWelcome(hasSeenWelcome: Bool, hasStoredSettings: Bool) -> Bool {
        !hasSeenWelcome && !hasStoredSettings
    }
}
