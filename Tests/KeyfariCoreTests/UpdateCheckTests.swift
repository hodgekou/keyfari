// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Testing

@testable import KeyfariCore

@Suite struct UpdateCheckTests {
    func json(tag: String = "v0.3.0", url: String = "https://github.com/hodgekou/keyfari/releases/tag/v0.3.0", extra: String = "") -> Data {
        Data(#"{"tag_name":"\#(tag)","html_url":"\#(url)"\#(extra)}"#.utf8)
    }

    @Test func readsVersions() {
        #expect(AppVersion("1.2.3")?.description == "1.2.3")
        #expect(AppVersion("v0.10.0") == AppVersion("0.10.0"))
        for text in ["", "1.2", "1.2.3.4", "1.2.x", "1.2.3-beta", "v", "1..3", " 1.2.3", "1.2.-3", "1.2.9999999"] {
            #expect(AppVersion(text) == nil, "\(text) should not be a version")
        }
    }

    @Test func comparesVersionsByNumberNotByText() throws {
        let old = try #require(AppVersion("0.9.12"))
        let new = try #require(AppVersion("0.10.2"))
        #expect(old < new)
        #expect(try #require(AppVersion("1.0.0")) > new)
        #expect(try #require(AppVersion("0.10.2")) == new)
    }

    @Test func aCheckIsDueOnceADay() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(UpdateCheck.isDue(lastChecked: nil, now: now))
        #expect(!UpdateCheck.isDue(lastChecked: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(-24 * 3600), now: now))
        // The clock was set back.
        #expect(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(3600), now: now))
    }

    @Test func readsARelease() throws {
        let release = try #require(UpdateCheck.release(fromLatestReleaseJSON: json()))
        #expect(release.version == AppVersion("0.3.0"))
        #expect(release.page.absoluteString == "https://github.com/hodgekou/keyfari/releases/tag/v0.3.0")
    }

    @Test func refusesAnythingThatIsNotAReleaseOfThisProject() {
        #expect(UpdateCheck.release(fromLatestReleaseJSON: Data("not json".utf8)) == nil)
        #expect(UpdateCheck.release(fromLatestReleaseJSON: Data("[]".utf8)) == nil)
        #expect(UpdateCheck.release(fromLatestReleaseJSON: json(tag: "nightly")) == nil)
        #expect(UpdateCheck.release(fromLatestReleaseJSON: json(extra: #","prerelease":true"#)) == nil)
        #expect(UpdateCheck.release(fromLatestReleaseJSON: json(extra: #","draft":true"#)) == nil)
        for url in [
            "http://github.com/hodgekou/keyfari/releases/tag/v0.3.0",
            "https://example.com/hodgekou/keyfari/releases/tag/v0.3.0",
            "https://github.com/someone-else/keyfari/releases/tag/v0.3.0",
            "https://github.com.example.com/hodgekou/keyfari/releases/tag/v0.3.0",
            "https://user@github.com/hodgekou/keyfari/releases/tag/v0.3.0",
            "https://github.com:8443/hodgekou/keyfari/releases/tag/v0.3.0",
            "file:///hodgekou/keyfari/releases/x",
        ] {
            #expect(UpdateCheck.release(fromLatestReleaseJSON: json(url: url)) == nil, "\(url) should be refused")
        }
        let huge = Data(repeating: 0x20, count: UpdateCheck.maximumResponseSize + 1)
        #expect(UpdateCheck.release(fromLatestReleaseJSON: huge) == nil)
    }

    @Test func offersOnlyANewerVersionThatWasNotSkipped() throws {
        let release = try #require(UpdateCheck.release(fromLatestReleaseJSON: json()))
        #expect(UpdateCheck.shouldOffer(release, current: AppVersion("0.2.0"), skipped: nil))
        #expect(!UpdateCheck.shouldOffer(release, current: AppVersion("0.3.0"), skipped: nil))
        #expect(!UpdateCheck.shouldOffer(release, current: AppVersion("0.4.0"), skipped: nil))
        #expect(!UpdateCheck.shouldOffer(release, current: AppVersion("0.2.0"), skipped: "0.3.0"))
        // An older skipped version does not hide a newer release.
        #expect(UpdateCheck.shouldOffer(release, current: AppVersion("0.2.0"), skipped: "0.2.5"))
        // A build without a readable version is never told to update.
        #expect(!UpdateCheck.shouldOffer(release, current: nil, skipped: nil))
    }
}
