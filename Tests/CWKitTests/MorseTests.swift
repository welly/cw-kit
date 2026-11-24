import Foundation
import Testing
@testable import CWKit

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

// MARK: - Alphabet

@Suite struct MorseAlphabetTests {
    @Test func lettersDigitsAndPunctuation() {
        #expect(MorseAlphabet.elements(for: "A") == [.dit, .dah])
        #expect(MorseAlphabet.elements(for: "q") == [.dah, .dah, .dit, .dah])
        #expect(MorseAlphabet.elements(for: "0") == [.dah, .dah, .dah, .dah, .dah])
        #expect(MorseAlphabet.elements(for: "?") == [.dit, .dit, .dah, .dah, .dit, .dit])
        #expect(MorseAlphabet.elements(for: "/") == [.dah, .dit, .dit, .dah, .dit])
        #expect(MorseAlphabet.elements(for: "#") == nil)
    }

    @Test func everyPatternIsDitsAndDahs() {
        for (character, pattern) in MorseAlphabet.patterns {
            #expect(!pattern.isEmpty && pattern.allSatisfy { $0 == "." || $0 == "-" }, "\(character)")
        }
    }

    @Test func noTwoCharactersShareAPatternExceptKnownAliases() {
        var seen: [String: Character] = [:]
        for (character, pattern) in MorseAlphabet.patterns.sorted(by: { $0.key < $1.key }) {
            if let other = seen[pattern] {
                // À and Å are both .--.- in ITU usage.
                #expect(Set([other, character]) == Set(["À", "Å"]), "\(other) and \(character)")
            }
            seen[pattern] = character
        }
    }

    @Test func germanLetters() {
        #expect(MorseAlphabet.elements(for: "ü") == [.dit, .dit, .dah, .dah])
        #expect(MorseAlphabet.elements(for: "ß") == [.dit, .dit, .dit, .dah, .dah, .dit, .dit])
    }

    @Test func prosignsRunLettersTogether() {
        #expect(MorseAlphabet.prosignElements("AR") == [.dit, .dah, .dit, .dah, .dit])   // .-.-.
        #expect(MorseAlphabet.prosignElements("SK") == [.dit, .dit, .dit, .dah, .dit, .dah]) // ...-.-
        #expect(MorseAlphabet.prosignElements("BT") == MorseAlphabet.elements(for: "="))
        #expect(MorseAlphabet.prosignElements("HH")?.count == 8)
        #expect(MorseAlphabet.prosignElements("") == nil)
        #expect(MorseAlphabet.prosignElements("A#") == nil)
    }
}

// MARK: - Timing

@Suite struct MorseTimingTests {
    @Test func parisStandard() {
        let t = MorseTiming(characterWPM: 20)
        #expect(approx(t.dit, 0.06))
        #expect(approx(t.dah, 0.18))
        #expect(approx(t.elementGap, 0.06))
        #expect(approx(t.characterGap, 0.18))
        #expect(approx(t.wordGap, 0.42))
        #expect(approx(t.effectiveWPM, 20))
    }

    @Test func parisWordIsFiftyUnits() {
        // "PARIS " at 12 WPM takes exactly 5 seconds (60 / 12).
        let t = MorseTiming(characterWPM: 12)
        let segments = MorseKeyer.segments(for: "PARIS", timing: t)
        #expect(approx(MorseKeyer.duration(of: segments) + t.wordGap, 5))
        #expect(approx(MorseKeyer.duration(of: segments) / t.dit, 43))
    }

    @Test func farnsworthMatchesARRLFormula() {
        // ARRL / Bloom: c = 18, s = 5. ta = (60·18 − 37.2·5) / (5·18) = 894 / 90 s.
        let t = MorseTiming(characterWPM: 18, spacing: .farnsworth(overallWPM: 5))
        let ta = 894.0 / 90.0
        #expect(approx(MorseTiming.farnsworthExtraDelay(characterWPM: 18, overallWPM: 5), ta))
        #expect(approx(t.dit, 1.2 / 18))
        #expect(approx(t.characterGap, 3 * ta / 19))
        #expect(approx(t.wordGap, 7 * ta / 19))
        #expect(approx(t.effectiveWPM, 5))
    }

    @Test(arguments: [(20.0, 10.0), (25.0, 15.0), (18.0, 5.0), (30.0, 29.0)])
    func farnsworthGivesOverallSpeed(c: Double, s: Double) {
        let t = MorseTiming(characterWPM: c, spacing: .farnsworth(overallWPM: s))
        #expect(approx(t.effectiveWPM, s))
        #expect(approx(t.dit, 1.2 / c))
        #expect(approx(t.wordGap / t.characterGap, 7.0 / 3.0))
    }

    @Test(arguments: [(20.0, 10.0), (25.0, 15.0), (18.0, 5.0)])
    func wordsworthStretchesWordGapsOnly(c: Double, s: Double) {
        let t = MorseTiming(characterWPM: c, spacing: .wordsworth(overallWPM: s))
        #expect(approx(t.effectiveWPM, s))
        #expect(approx(t.characterGap, 3 * 1.2 / c))
        #expect(approx(t.wordGap, 60 / s - 43 * 1.2 / c))
    }

    @Test func overallSpeedNotBelowCharacterSpeedIsStandard() {
        let standard = MorseTiming(characterWPM: 20)
        for spacing in [MorseSpacing.farnsworth(overallWPM: 20), .farnsworth(overallWPM: 30), .wordsworth(overallWPM: 25)] {
            let t = MorseTiming(characterWPM: 20, spacing: spacing)
            #expect(approx(t.characterGap, standard.characterGap))
            #expect(approx(t.wordGap, standard.wordGap))
        }
    }

    @Test func speedsAreClamped() {
        #expect(approx(MorseTiming(characterWPM: 0).dit, 1.2))
        #expect(approx(MorseTiming(characterWPM: 500).dit, 0.012))
    }
}

// MARK: - Text and keying

@Suite struct MorseTextTests {
    @Test func charactersAndWordSpaces() {
        let text = MorseText("  cq   de ")
        #expect(text.displayText == "CQ DE")
        #expect(text.tokens.count == 5)
        #expect(text.tokens[2] == .wordSpace)
        #expect(text.skipped.isEmpty)
    }

    @Test func prosignsInAngleBrackets() {
        let text = MorseText("GM <BT> TNX")
        #expect(text.displayText == "GM <BT> TNX")
        #expect(text.tokens[3] == .symbol(text: "<BT>", elements: MorseAlphabet.prosignElements("BT")!))
    }

    @Test func ebook2cwCommands() {
        let text = MorseText("CQ |S1000 CQ |f650|w30|e15 K")
        #expect(text.tokens.contains(.pause(1.0)))
        #expect(text.tokens.contains(.frequency(650)))
        #expect(text.tokens.contains(.characterSpeed(30)))
        #expect(text.tokens.contains(.overallSpeed(15)))
        #expect(text.displayText == "CQ CQ K")
    }

    @Test func speedMarkers() {
        let text = MorseText("<speed2> Ball")
        #expect(text.tokens.first == .speedMarker(2))
        #expect(text.displayText == "BALL")
    }

    @Test func unknownCharactersAreSkipped() {
        let text = MorseText("A#B")
        #expect(text.displayText == "AB")
        #expect(text.skipped == ["#"])
    }

    @Test func keyingForA() {
        let t = MorseTiming(characterWPM: 20)
        let s = MorseKeyer.segments(for: "A", timing: t)
        #expect(s == [
            KeySegment(isOn: true, duration: t.dit),
            KeySegment(isOn: false, duration: t.elementGap),
            KeySegment(isOn: true, duration: t.dah),
        ])
    }

    @Test func gapsBetweenCharactersAndWords() {
        let t = MorseTiming(characterWPM: 20, spacing: .farnsworth(overallWPM: 10))
        let s = MorseKeyer.segments(for: "E E  E", timing: t)
        #expect(s.count == 5)
        #expect(approx(s[1].duration, t.wordGap))
        #expect(approx(s[3].duration, t.wordGap))
        let s2 = MorseKeyer.segments(for: "EE", timing: t)
        #expect(approx(s2[1].duration, t.characterGap))
    }

    @Test func pausesAddToTheGap() {
        let t = MorseTiming(characterWPM: 20)
        let s = MorseKeyer.segments(for: "E |S1000 E", timing: t)
        #expect(s.count == 3)
        #expect(approx(s[1].duration, t.wordGap + 1.0))
    }

    @Test func speedAndFrequencyChangesApplyFromThatPoint() {
        let t = MorseTiming(characterWPM: 20)
        let s = MorseKeyer.segments(for: "E |w40|f800E", timing: t)
        #expect(approx(s[0].duration, 0.06))
        #expect(s[0].frequency == nil)
        #expect(approx(s[2].duration, 0.03))
        #expect(s[2].frequency == 800)
    }

    @Test func noLeadingOrTrailingGaps() {
        let s = MorseKeyer.segments(for: " E ", timing: MorseTiming(characterWPM: 20))
        #expect(s == [KeySegment(isOn: true, duration: 0.06)])
    }
}

// MARK: - Rendering

@Suite struct ToneRendererTests {
    let tone = ToneSettings(frequency: 600, riseTime: 0.005, amplitude: 0.5, sampleRate: 48_000)

    @Test func lengthMatchesTiming() {
        let renderer = ToneRenderer(tone: tone, timing: MorseTiming(characterWPM: 20))
        // PARIS without its trailing word gap: 43 units of 60 ms = 2.58 s.
        #expect(renderer.render("PARIS").count == 123_840)
    }

    @Test func silenceIsSilentAndToneIsBounded() {
        let renderer = ToneRenderer(tone: tone, timing: MorseTiming(characterWPM: 20))
        let samples = renderer.render("EE")
        // E (60 ms) then a 180 ms gap: samples 2880..<11520 are silent.
        #expect(samples[2880..<11520].allSatisfy { $0 == 0 })
        #expect(samples.allSatisfy { abs($0) <= 0.5 + 1e-6 })
        #expect(samples[0..<2880].contains { abs($0) > 0.49 })
    }

    @Test func edgesRampWithRaisedCosine() {
        let renderer = ToneRenderer(tone: tone, timing: MorseTiming(characterWPM: 20))
        let samples = renderer.render("E")
        let ramp = 240 // 5 ms at 48 kHz
        // The first and last samples are nearly silent; the peak in the ramp grows steadily.
        #expect(abs(samples[0]) < 0.001)
        #expect(abs(samples[samples.count - 1]) < 0.01)
        let firstCycle = samples[0..<80].map { abs($0) }.max()!
        let lastRampCycle = samples[(ramp - 80)..<ramp].map { abs($0) }.max()!
        #expect(firstCycle < 0.1)
        #expect(lastRampCycle > 0.45)
    }

    @Test func separateRiseAndFall() {
        let shape = ToneSettings(frequency: 600, riseTime: 0.001, fallTime: 0.010, amplitude: 0.5)
        let samples = ToneRenderer(tone: shape, timing: MorseTiming(characterWPM: 5)).render("E") // 240 ms
        // 1 ms rise: full level by 2 ms in. 10 ms fall: still well below full level 2 ms from the end.
        #expect(samples[96..<176].map { abs($0) }.max()! > 0.49)
        let tail = samples[(samples.count - 96)...].map { abs($0) }.max()!
        #expect(tail < 0.1)
        #expect(ToneSettings(riseTime: 0.003).fallTime == 0.003)
    }

    @Test func riseTimeClampsToHalfAnElement() {
        let fast = ToneRenderer(tone: ToneSettings(riseTime: 0.1), timing: MorseTiming(characterWPM: 60))
        let samples = fast.render("E")
        #expect(samples.count == 960)
        #expect(samples.contains { abs($0) > 0.7 })
    }

    @Test func frequencyIsRight() {
        let renderer = ToneRenderer(tone: tone, timing: MorseTiming(characterWPM: 5))
        let samples = renderer.render("T") // 720 ms dah
        let middle = samples[4800..<(4800 + 48_000 / 10)] // 100 ms
        var crossings = 0
        for i in middle.indices.dropFirst() where (middle[i - 1] < 0) != (middle[i] < 0) { crossings += 1 }
        #expect(abs(crossings - 120) <= 1) // 600 Hz → 120 zero crossings per 100 ms
    }

    @Test func wavHeader() {
        let data = WAVFile.data(samples: [0, 1, -1], sampleRate: 48_000)
        #expect(data.count == 44 + 6)
        #expect(String(decoding: data[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
        let rate = data[24..<28].enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
        #expect(rate == 48_000)
        let last = Int16(bitPattern: UInt16(data[48]) | UInt16(data[49]) << 8)
        #expect(last == -Int16.max)
    }
}

// MARK: - Units and characters per minute

@Suite struct MorseUnitsTests {
    @Test func parisIsFiftyUnitsWithItsWordGap() {
        // "PARIS" is 31 units of characters plus 4 gaps of 3; a following word adds the 7-unit word gap.
        #expect(MorseKeyer.units(of: "PARIS") == 43)
        #expect(MorseKeyer.units(of: "PARIS PARIS") == 43 + 7 + 43)
    }

    @Test func singleCharactersAndSpacing() {
        #expect(MorseKeyer.units(of: "E") == 1)
        #expect(MorseKeyer.units(of: "T") == 3)
        #expect(MorseKeyer.units(of: "EE") == 5)
        #expect(MorseKeyer.units(of: "  E   E  ") == 9)
        #expect(MorseKeyer.units(of: "") == 0)
    }

    @Test func prosignsHaveNoGapsBetweenTheirLetters() {
        // <AR> is .-.-. : 1+1+3+1+1+1+3+1+1 = 13.
        #expect(MorseKeyer.units(of: "<AR>") == 13)
    }

    @Test func unitsMatchTheKeyedDuration() {
        let timing = MorseTiming(characterWPM: 20)
        for text in ["G3AJM", "CQ CQ DE G3AJM", "5NN 599", "EA8/DL1ABC"] {
            let seconds = MorseKeyer.duration(of: MorseKeyer.segments(for: text, timing: timing))
            #expect(approx(seconds, Double(MorseKeyer.units(of: text)) * timing.dit, tolerance: 1e-9))
        }
    }

    @Test func charactersPerMinute() {
        #expect(MorseTiming.cpm(fromWPM: 20) == 100)
        #expect(MorseTiming.wpm(fromCPM: 500) == 100)
        #expect(approx(MorseTiming(characterCPM: 100).dit, MorseTiming(characterWPM: 20).dit))
    }
}
