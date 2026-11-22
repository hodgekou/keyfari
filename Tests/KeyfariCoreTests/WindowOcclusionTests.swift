// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct WindowOcclusionTests {
    let window = CGRect(x: 100, y: 100, width: 600, height: 400)

    @Test func aPointShowsUnlessAWindowInFrontCoversIt() {
        let inFront = [CGRect(x: 0, y: 0, width: 300, height: 300)]
        #expect(!WindowOcclusion.isVisible(CGPoint(x: 200, y: 200), behind: inFront))
        #expect(WindowOcclusion.isVisible(CGPoint(x: 500, y: 400), behind: inFront))
        #expect(WindowOcclusion.isVisible(CGPoint(x: 200, y: 200), behind: []))
    }

    @Test func nothingInFrontMeansFullyVisible() {
        #expect(WindowOcclusion.visibleFraction(of: window, behind: []) == 1)
    }

    @Test func aWindowUnderAnotherIsNotVisible() {
        #expect(WindowOcclusion.visibleFraction(of: window, behind: [CGRect(x: 0, y: 0, width: 2000, height: 2000)]) == 0)
    }

    @Test func halfCoveredIsAboutHalfVisible() {
        let leftHalf = CGRect(x: 100, y: 100, width: 300, height: 400)
        #expect(WindowOcclusion.visibleFraction(of: window, behind: [leftHalf]) == 0.5)
    }

    @Test func anEmptyFrameIsNotVisible() {
        #expect(WindowOcclusion.visibleFraction(of: .zero, behind: []) == 0)
    }
}
