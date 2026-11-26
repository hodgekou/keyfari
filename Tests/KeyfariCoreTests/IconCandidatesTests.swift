// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct IconCandidatesTests {
    /// A toolbar: icons of 20 points, 36 points apart, at height `y`.
    func row(count: Int, y: CGFloat = 10, startX: CGFloat = 20) -> [CGRect] {
        (0..<count).map { CGRect(x: startX + CGFloat($0) * 36, y: y, width: 20, height: 20) }
    }

    @Test func aRowOfIconsIsFoundInReadingOrder() {
        let icons = row(count: 5)
        #expect(IconCandidates.find(outlines: icons.shuffled(), occupied: []) == icons)
    }

    @Test func aColumnCountsToo() {
        let column = (0..<4).map { CGRect(x: 10, y: 40 + CGFloat($0) * 34, width: 22, height: 22) }
        #expect(IconCandidates.find(outlines: column, occupied: []) == column)
    }

    @Test func aLoneShapeOrAPairIsNotEnough() {
        #expect(IconCandidates.find(outlines: row(count: 1), occupied: []).isEmpty)
        #expect(IconCandidates.find(outlines: row(count: 2), occupied: []).isEmpty)
    }

    @Test func aPairAtTheFarEndOfASidebarContinuesItsColumn() {
        // Four tabs at the top of a sidebar, and a phone and a menu icon far below them.
        let tabs = (0..<4).map { CGRect(x: 20, y: 110 + CGFloat($0) * 48, width: 20, height: 20) }
        let pair = [CGRect(x: 22, y: 547, width: 14, height: 20), CGRect(x: 21, y: 600, width: 17, height: 11)]
        #expect(IconCandidates.find(outlines: tabs + pair, occupied: []) == tabs + pair)
    }

    @Test func aPairOutOfLineWithARunIsNotEnough() {
        let tabs = (0..<4).map { CGRect(x: 20, y: 110 + CGFloat($0) * 48, width: 20, height: 20) }
        let pair = [CGRect(x: 300, y: 547, width: 20, height: 20), CGRect(x: 300, y: 600, width: 20, height: 20)]
        #expect(IconCandidates.find(outlines: tabs + pair, occupied: []) == tabs)
    }

    @Test func aLoneShapeInLineWithARunIsNotEnough() {
        let tabs = (0..<4).map { CGRect(x: 20, y: 110 + CGFloat($0) * 48, width: 20, height: 20) }
        let lone = CGRect(x: 20, y: 600, width: 20, height: 20)
        #expect(IconCandidates.find(outlines: tabs + [lone], occupied: []) == tabs)
    }

    @Test func shapesFarApartDoNotMakeARow() {
        let scattered = [0, 300, 600].map { CGRect(x: CGFloat($0), y: 10, width: 20, height: 20) }
        #expect(IconCandidates.find(outlines: scattered, occupied: []).isEmpty)
    }

    @Test func thePartsOfOneIconAreJoined() {
        // The third icon is drawn as two pieces, like a speaker and its waves.
        var outlines = row(count: 2)
        outlines.append(CGRect(x: 92, y: 12, width: 8, height: 16))
        outlines.append(CGRect(x: 102, y: 10, width: 10, height: 20))
        let found = IconCandidates.find(outlines: outlines, occupied: [])
        #expect(found.count == 3)
        #expect(found.last == CGRect(x: 92, y: 10, width: 20, height: 20))
    }

    @Test func lettersJoinIntoAWordThatIsTooWideToBeAnIcon() {
        // Twelve letters, 7 points wide and 2 points apart.
        let letters = (0..<12).map { CGRect(x: 20 + CGFloat($0) * 9, y: 10, width: 7, height: 12) }
        #expect(IconCandidates.find(outlines: letters, occupied: []).isEmpty)
    }

    @Test func whatAlreadyHasALabelOrIsTextIsLeftAlone() {
        let icons = row(count: 5)
        // The first two are a real button and a recognised word.
        let occupied = [icons[0].insetBy(dx: -4, dy: -4), icons[1]]
        #expect(IconCandidates.find(outlines: icons, occupied: occupied) == Array(icons[2...]))
    }

    @Test func bigAndThinShapesAreNotIcons() {
        var outlines = row(count: 4)
        outlines.append(CGRect(x: 0, y: 0, width: 400, height: 40))  // the toolbar itself
        outlines.append(CGRect(x: 170, y: 10, width: 30, height: 4))  // a divider in line with the icons
        #expect(IconCandidates.find(outlines: outlines, occupied: []) == row(count: 4))
    }

    @Test func neverReturnsMoreThanTheLimit() {
        var limits = IconCandidates.Limits()
        limits.maximumCount = 3
        #expect(IconCandidates.find(outlines: row(count: 8), occupied: [], limits: limits).count == 3)
    }
}
