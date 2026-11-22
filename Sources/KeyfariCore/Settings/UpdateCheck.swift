// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// A version of the form 1.2.3.
public struct AppVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    /// Reads "1.2.3" or "v1.2.3". Anything else, including a pre-release suffix, is not a version.
    public init?(_ text: String) {
        let digits = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.count <= 6 && $0.allSatisfy { ("0"..."9").contains($0) } }),
            let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2])
        else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// A published release, as far as the update check cares.
public struct ReleaseInfo: Equatable, Sendable {
    public let version: AppVersion
    /// The page the user is sent to. It is checked to be a release page of this project.
    public let page: URL
}

/// The rules of the daily check for a newer version.
///
/// The check asks GitHub for the latest release of this project and nothing else. What comes
/// back is untrusted: it is only ever turned into a version and a link to the project's own
/// release pages.
public enum UpdateCheck {
    /// Where the latest release is described.
    public static let latestReleaseURL = "https://api.github.com/repos/hodgekou/keyfari/releases/latest"
    /// How long to wait between two checks.
    public static let interval: TimeInterval = 24 * 60 * 60
    /// A response larger than this is not a release description.
    public static let maximumResponseSize = 1_000_000

    private static let releasePagePrefix = "/hodgekou/keyfari/releases/"

    /// Whether enough time has passed since the last check.
    public static func isDue(lastChecked: Date?, now: Date) -> Bool {
        guard let lastChecked else { return true }
        // A clock that was set back must not stop the checks for good.
        return now < lastChecked || now.timeIntervalSince(lastChecked) >= interval
    }

    /// Reads the release out of GitHub's answer, or nil when it is not a regular release of
    /// this project with a version for a tag.
    public static func release(fromLatestReleaseJSON data: Data) -> ReleaseInfo? {
        guard data.count <= maximumResponseSize,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["draft"] as? Bool != true, object["prerelease"] as? Bool != true,
            let tag = object["tag_name"] as? String, let version = AppVersion(tag),
            let link = object["html_url"] as? String, let page = URL(string: link),
            page.scheme == "https", page.host == "github.com", page.path.hasPrefix(releasePagePrefix),
            page.user == nil, page.port == nil
        else { return nil }
        return ReleaseInfo(version: version, page: page)
    }

    /// Whether the user should be told about `release`.
    /// - Parameters:
    ///   - current: the running version, or nil when it cannot be read, as in a development build.
    ///   - skipped: the version the user chose not to hear about again.
    public static func shouldOffer(_ release: ReleaseInfo, current: AppVersion?, skipped: String?) -> Bool {
        guard let current, release.version > current else { return false }
        if let skipped, AppVersion(skipped) == release.version { return false }
        return true
    }
}
