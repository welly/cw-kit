/// How the gaps between characters and words are stretched when the overall speed is lower than
/// the character speed.
public enum MorseSpacing: Sendable, Equatable, Hashable {
    /// Standard PARIS timing: every gap is at character speed.
    case standard
    /// Farnsworth: characters at character speed; the gaps between characters and between words
    /// are both stretched so a PARIS word takes `60 / overallWPM` seconds (ARRL formula).
    case farnsworth(overallWPM: Double)
    /// Wordsworth: characters and the gaps between them stay at character speed; only the gap
    /// between words is stretched so a PARIS word takes `60 / overallWPM` seconds.
    case wordsworth(overallWPM: Double)
}

/// Morse timing for a character speed and spacing. All durations are in seconds.
///
/// PARIS standard: dit = 1.2 / WPM; dah = 3 dits; the gap inside a character is 1 dit, between
/// characters 3 dits and between words 7 dits. "PARIS " is 50 dit units: 31 units of keyed
/// characters (elements plus the gaps inside them), 12 units of gaps between characters and
/// 7 units of word gap.
public struct MorseTiming: Sendable, Equatable, Hashable {
    /// Speed at which each character is keyed, in words per minute.
    public var characterWPM: Double
    public var spacing: MorseSpacing

    public init(characterWPM: Double, spacing: MorseSpacing = .standard) {
        self.characterWPM = characterWPM
        self.spacing = spacing
    }

    /// Lowest and highest speeds accepted; values outside are clamped.
    public static let wpmRange: ClosedRange<Double> = 1...100

    private var c: Double { min(max(characterWPM, Self.wpmRange.lowerBound), Self.wpmRange.upperBound) }

    /// The overall speed after clamping, or `nil` when spacing is standard or the overall speed is
    /// not lower than the character speed (both then mean standard timing).
    private var stretchedOverallWPM: Double? {
        switch spacing {
        case .standard:
            return nil
        case .farnsworth(let s), .wordsworth(let s):
            let s = max(s, Self.wpmRange.lowerBound)
            return s < c ? s : nil
        }
    }

    /// Length of a dit, and of the gap between elements inside a character.
    public var dit: Double { 1.2 / c }
    public var dah: Double { 3 * dit }
    public var elementGap: Double { dit }

    /// Gap between characters within a word.
    public var characterGap: Double {
        guard let s = stretchedOverallWPM, case .farnsworth = spacing else { return 3 * dit }
        return 3 * Self.farnsworthExtraDelay(characterWPM: c, overallWPM: s) / 19
    }

    /// Gap between words.
    public var wordGap: Double {
        guard let s = stretchedOverallWPM else { return 7 * dit }
        switch spacing {
        case .farnsworth:
            return 7 * Self.farnsworthExtraDelay(characterWPM: c, overallWPM: s) / 19
        case .wordsworth:
            // A PARIS word must take 60/s seconds; 43 of its 50 units stay at character speed.
            return 60 / s - 43 * dit
        case .standard:
            return 7 * dit
        }
    }

    /// The overall speed this timing gives, measured on "PARIS ".
    public var effectiveWPM: Double {
        60 / (31 * dit + 4 * characterGap + wordGap)
    }

    /// ARRL / Bloom (KE3Z) Farnsworth formula: total delay spread over the 19 gap units of a
    /// PARIS word, `ta = (60c − 37.2s) / (s·c)` seconds, where 37.2 = 31 units × 1.2.
    public static func farnsworthExtraDelay(characterWPM c: Double, overallWPM s: Double) -> Double {
        (60 * c - 37.2 * s) / (s * c)
    }
}

// MARK: Characters per minute

extension MorseTiming {
    /// Characters per minute for a speed in words per minute: PARIS has 5 characters, so 1 WPM = 5 CPM. CPM is the unit
    /// RufzXP-style callsign trainers use.
    public static func cpm(fromWPM wpm: Double) -> Double { wpm * 5 }

    /// Words per minute for a speed in characters per minute (1 WPM = 5 CPM).
    public static func wpm(fromCPM cpm: Double) -> Double { cpm / 5 }

    /// Timing for a character speed given in characters per minute.
    public init(characterCPM: Double, spacing: MorseSpacing = .standard) {
        self.init(characterWPM: Self.wpm(fromCPM: characterCPM), spacing: spacing)
    }
}
