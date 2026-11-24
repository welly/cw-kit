/// A stretch of time with the key either down (tone) or up (silence).
public struct KeySegment: Sendable, Equatable {
    public var isOn: Bool
    /// Seconds.
    public var duration: Double
    /// Tone frequency for this segment when the text changed it with `|f`; `nil` means the
    /// renderer's default.
    public var frequency: Double?

    public init(isOn: Bool, duration: Double, frequency: Double? = nil) {
        self.isOn = isOn
        self.duration = duration
        self.frequency = frequency
    }
}

/// Converts Morse tokens into key-down / key-up segments with real durations.
///
/// The result never starts or ends with a gap between characters or words; explicit pauses
/// (`|S`) are kept wherever they are.
public enum MorseKeyer {
    private enum PendingGap { case none, character, word }

    public static func segments(for text: String, timing: MorseTiming) -> [KeySegment] {
        segments(for: MorseText(text).tokens, timing: timing)
    }

    public static func segments(for tokens: [MorseToken], timing initialTiming: MorseTiming) -> [KeySegment] {
        var timing = initialTiming
        var frequency: Double?
        var out: [KeySegment] = []
        var pendingGap = PendingGap.none
        var pendingPause = 0.0

        func appendSilence(_ duration: Double) {
            guard duration > 0 else { return }
            if let last = out.last, !last.isOn {
                out[out.count - 1].duration += duration
            } else {
                out.append(KeySegment(isOn: false, duration: duration))
            }
        }

        for token in tokens {
            switch token {
            case .symbol(_, let elements):
                guard !elements.isEmpty else { continue }
                let gap: Double
                switch pendingGap {
                case .none: gap = 0
                case .character: gap = timing.characterGap
                case .word: gap = timing.wordGap
                }
                appendSilence(gap + pendingPause)
                for (index, element) in elements.enumerated() {
                    if index > 0 { appendSilence(timing.elementGap) }
                    out.append(KeySegment(isOn: true, duration: Double(element.units) * timing.dit, frequency: frequency))
                }
                pendingGap = .character
                pendingPause = 0
            case .wordSpace:
                if pendingGap == .character { pendingGap = .word }
            case .pause(let seconds):
                pendingPause += max(0, seconds)
            case .frequency(let hz):
                frequency = hz
            case .characterSpeed(let wpm):
                timing.characterWPM = wpm
            case .overallSpeed(let wpm):
                timing.spacing = .farnsworth(overallWPM: wpm)
            case .speedMarker:
                break
            }
        }
        appendSilence(pendingPause)
        return out
    }

    /// Length of `text` in dit units at standard timing: each element, 1 unit between the elements of a character, 3
    /// between characters and 7 between words, with no gap before the first character or after the last. Pauses and
    /// changes of speed or tone are left out. QRQ Trainer scores an item by this.
    public static func units(of text: String) -> Int {
        var units = 0
        var pendingGap = PendingGap.none
        for token in MorseText(text).tokens {
            switch token {
            case .symbol(_, let elements):
                guard !elements.isEmpty else { continue }
                switch pendingGap {
                case .none: break
                case .character: units += 3
                case .word: units += 7
                }
                units += elements.reduce(0) { $0 + $1.units } + (elements.count - 1)
                pendingGap = .character
            case .wordSpace:
                if pendingGap == .character { pendingGap = .word }
            case .pause, .frequency, .characterSpeed, .overallSpeed, .speedMarker:
                break
            }
        }
        return units
    }

    /// Total length of `segments` in seconds.
    public static func duration(of segments: [KeySegment]) -> Double {
        segments.reduce(0) { $0 + $1.duration }
    }
}
