// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import Testing

@testable import KeyfariCore

@Suite struct StableLabelsTests {
    func button(_ text: String, path: String? = nil) -> ElementSnapshot {
        ElementSnapshot(role: "AXButton", frame: .zero, searchText: text, stableIdentity: path)
    }

    @Test func anElementWithTextIsKnownByItsTextWhereverItSits() {
        #expect(StableLabels.fingerprint(of: button("Save File")) == "AXButton|savefile")
        // The same button under another window title or after a banner appeared above it.
        #expect(
            StableLabels.fingerprint(of: button("Save File", path: "AXWindow[0]/AXGroup[1]/AXButton[0]"))
                == StableLabels.fingerprint(of: button("Save File", path: "AXWindow[0]/AXGroup[2]/AXButton[3]")))
    }

    @Test func anElementWithoutTextIsKnownByItsPlace() {
        #expect(
            StableLabels.fingerprint(of: button("  ", path: "AXWindow[0]/AXToolbar[0]/AXButton[2]"))
                == "AXButton@AXWindow[0]/AXToolbar[0]/AXButton[2]")
        #expect(
            StableLabels.fingerprint(of: button("", path: "AXWindow[0]/AXToolbar[0]/AXButton[2]"))
                != StableLabels.fingerprint(of: button("", path: "AXWindow[0]/AXToolbar[0]/AXButton[3]")))
        #expect(StableLabels.fingerprint(of: button("  ")) == nil)
    }

    @Test func rememberedLabelIsReused() {
        let fingerprints: [String?] = ["a", "b", "c"]
        let plain = StableLabels.assign(fingerprints: fingerprints, alphabet: "sdf", memory: [:])
        // The generator hands labels out in sorted order.
        #expect(plain == ["D", "F", "S"])

        let remembered = StableLabels.assign(fingerprints: fingerprints, alphabet: "sdf", memory: ["a": "S"])
        #expect(remembered[0] == "S")
        #expect(Set(remembered) == ["S", "D", "F"])
    }

    @Test func labelOutsideTheGeneratedSetIsIgnored() {
        let labels = StableLabels.assign(fingerprints: ["a", nil], alphabet: "sdf", memory: ["a": "ZZ"])
        #expect(labels == ["D", "S"])
    }

    @Test func twoElementsCannotShareARememberedLabel() {
        let labels = StableLabels.assign(fingerprints: ["a", "a", "b"], alphabet: "sdf", memory: ["a": "F"])
        #expect(labels[0] == "F")
        #expect(Set(labels).count == 3)
    }

    @Test func aChosenLabelIsUsedEvenOutsideTheGeneratedSet() {
        // Three elements would get one-letter labels; the chosen one has two.
        let labels = StableLabels.assign(fingerprints: ["a", "b", "c"], alphabet: "sdfj", memory: [:], custom: ["b": "SS"])
        #expect(labels[1] == "SS")
        #expect(Set(labels).count == 3)
    }

    @Test func noLabelBeginsAChosenOne() {
        let fingerprints: [String?] = (0..<12).map { "e\($0)" }
        let labels = StableLabels.assign(fingerprints: fingerprints, alphabet: "sdfj", memory: ["e1": "S"], custom: ["e0": "S"])
        #expect(labels[0] == "S")
        #expect(Set(labels).count == 12)
        for (index, label) in labels.enumerated() where index != 0 {
            #expect(!label.isEmpty)
            #expect(!label.hasPrefix("S"))
        }
    }

    @Test func aChosenLabelBeatsARememberedOneAndGoesToTheFirstOfTwins() {
        let labels = StableLabels.assign(fingerprints: ["a", "a", "b"], alphabet: "sdf", memory: ["a": "F"], custom: ["a": "D"])
        #expect(labels[0] == "D")
        #expect(labels[1] != "D")
        #expect(Set(labels).count == 3)
    }

    @Test func aChosenLabelWithLettersOutsideTheAlphabetIsIgnored() {
        let labels = StableLabels.assign(fingerprints: ["a", "b"], alphabet: "sdf", memory: [:], custom: ["a": "Q"])
        #expect(labels == ["D", "S"])
    }

    @Test func typedTextBecomesUppercaseLetters() {
        #expect(StableLabels.normalized(customLabel: " s1d ") == "SD")
    }

    @Test func checksAChosenLabel() {
        let alphabet = "sdfj"
        #expect(StableLabels.problem(withCustomLabel: "SD", alphabet: alphabet, otherCustomLabels: ["F"]) == nil)
        #expect(StableLabels.problem(withCustomLabel: "", alphabet: alphabet, otherCustomLabels: []) == .empty)
        #expect(StableLabels.problem(withCustomLabel: "SDFJ", alphabet: alphabet, otherCustomLabels: []) == .tooLong)
        #expect(StableLabels.problem(withCustomLabel: "SQ", alphabet: alphabet, otherCustomLabels: []) == .notInAlphabet)
        // One label must not be the beginning of another, in either direction.
        #expect(StableLabels.problem(withCustomLabel: "S", alphabet: alphabet, otherCustomLabels: ["SD"]) == .conflicts(with: "SD"))
        #expect(StableLabels.problem(withCustomLabel: "SD", alphabet: alphabet, otherCustomLabels: ["S"]) == .conflicts(with: "S"))
    }
}
