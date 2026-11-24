/// One keyed element of a Morse character.
public enum MorseElement: Sendable, Equatable {
    case dit
    case dah

    /// Length in dit units at standard (PARIS) timing.
    public var units: Int { self == .dit ? 1 : 3 }
}

/// International Morse code (ITU-R M.1677-1), plus the common non-English letters used in
/// Morse Code Ninja's German sets.
///
/// Prosigns are written as their letters run together, the way ebook2cw and Morse Code Ninja
/// write them: `<AR>` is A and R sent with no gap between them.
public enum MorseAlphabet {
    /// Characters mapped to dit/dah patterns written with `.` and `-`. Keys are upper case.
    public static let patterns: [Character: String] = [
        // Letters
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.",
        "G": "--.", "H": "....", "I": "..", "J": ".---", "K": "-.-", "L": ".-..",
        "M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.",
        "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
        "Y": "-.--", "Z": "--..",
        // Digits
        "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
        // Punctuation
        ".": ".-.-.-", ",": "--..--", "?": "..--..", "'": ".----.", "!": "-.-.--",
        "/": "-..-.", "(": "-.--.", ")": "-.--.-", "&": ".-...", ":": "---...",
        ";": "-.-.-.", "=": "-...-", "+": ".-.-.", "-": "-....-", "_": "..--.-",
        "\"": ".-..-.", "$": "...-..-", "@": ".--.-.",
        // Non-English letters
        "Ä": ".-.-", "Ö": "---.", "Ü": "..--", "ß": "...--..", "É": "..-..",
        "À": ".--.-", "Å": ".--.-", "Ñ": "--.--",
    ]

    private static let elementTable: [Character: [MorseElement]] = patterns.mapValues { pattern in
        pattern.map { $0 == "." ? .dit : .dah }
    }

    /// The elements for one character, or `nil` if it has no Morse code. Case is ignored.
    public static func elements(for character: Character) -> [MorseElement]? {
        if let direct = elementTable[character] { return direct }
        // "ß".uppercased() is "SS", so look up the upper-case form only when it is one character.
        let upper = character.uppercased()
        guard upper.count == 1, let key = upper.first else { return nil }
        return elementTable[key]
    }

    /// Whether `character` can be sent as Morse.
    public static func canEncode(_ character: Character) -> Bool {
        elements(for: character) != nil
    }

    /// The elements for a prosign written as its letters, for example `"AR"` or `"SK"`: the
    /// letters' elements run together with no gap between letters. Returns `nil` if the string is
    /// empty or any character has no Morse code.
    public static func prosignElements(_ letters: String) -> [MorseElement]? {
        guard !letters.isEmpty else { return nil }
        var result: [MorseElement] = []
        for character in letters {
            guard let elements = elements(for: character) else { return nil }
            result += elements
        }
        return result
    }
}
