#if os(WASI)
import WASILibc // Wasm: no Foundation, which would add megabytes to the web apps
#else
import Foundation
#endif

/// One step of a Morse text after parsing.
public enum MorseToken: Sendable, Equatable {
    /// A character or prosign to key. `text` is what it stands for: `"A"`, or `"<AR>"` for a prosign.
    case symbol(text: String, elements: [MorseElement])
    /// One or more spaces between words.
    case wordSpace
    /// Silence of a fixed length in seconds (ebook2cw `|S1000` is 1000 ms).
    case pause(Double)
    /// Change the tone frequency in Hz from here on (ebook2cw `|f650`).
    case frequency(Double)
    /// Change the character speed in WPM from here on (ebook2cw `|w30`).
    case characterSpeed(Double)
    /// Change the overall (Farnsworth) speed in WPM from here on (ebook2cw `|e15`).
    case overallSpeed(Double)
    /// A Morse Code Ninja speed placeholder such as `<speed1>`. Morse Code Ninja's renderer
    /// replaces it with a speed change chosen at render time; the player decides what it means.
    case speedMarker(Int)
}

/// Turns text into Morse tokens.
///
/// Understands the inline syntax that Morse Code Ninja files use (taken from ebook2cw):
/// - `<AR>`: letters in angle brackets are sent as one prosign, with no gaps between letters.
/// - `|S1000`: 1000 ms of silence. `|f650`: tone 650 Hz. `|w30`: character speed 30 WPM.
///   `|e15`: overall speed 15 WPM.
/// - `<speed1>`: Morse Code Ninja speed placeholder.
///
/// Characters with no Morse code are dropped and recorded in `skipped`.
public struct MorseText: Sendable, Equatable {
    public let tokens: [MorseToken]
    /// Characters that were dropped because they have no Morse code.
    public let skipped: [Character]

    public init(_ text: String) {
        var tokens: [MorseToken] = []
        var skipped: [Character] = []
        let chars = Array(text)
        var i = 0

        func appendWordSpace() {
            if let last = tokens.last, last == .wordSpace { return }
            tokens.append(.wordSpace)
        }

        while i < chars.count {
            let ch = chars[i]

            if ch.isWhitespace {
                appendWordSpace()
                i += 1
                continue
            }

            // <...>: prosign or speed placeholder.
            if ch == "<", let close = chars[(i + 1)...].firstIndex(of: ">") {
                let inner = String(chars[(i + 1)..<close])
                if let n = Self.speedMarkerNumber(inner) {
                    tokens.append(.speedMarker(n))
                    i = close + 1
                    continue
                }
                if !inner.contains(where: \.isWhitespace),
                   let elements = MorseAlphabet.prosignElements(inner) {
                    tokens.append(.symbol(text: "<\(inner.uppercased())>", elements: elements))
                    i = close + 1
                    continue
                }
            }

            // |X123: ebook2cw inline command.
            if ch == "|", i + 2 < chars.count {
                let command = chars[i + 1]
                var j = i + 2
                while j < chars.count, chars[j].isASCII, chars[j].isNumber || chars[j] == "." { j += 1 }
                if j > i + 2, let value = Double(String(chars[(i + 2)..<j])) {
                    var token: MorseToken?
                    switch command {
                    case "S": token = .pause(value / 1000)
                    case "f": token = .frequency(value)
                    case "w": token = .characterSpeed(value)
                    case "e": token = .overallSpeed(value)
                    default: token = nil
                    }
                    if let token {
                        tokens.append(token)
                        i = j
                        continue
                    }
                }
            }

            if let elements = MorseAlphabet.elements(for: ch) {
                tokens.append(.symbol(text: ch.uppercased(), elements: elements))
            } else {
                skipped.append(ch)
            }
            i += 1
        }

        // No leading or trailing word spaces.
        while tokens.first == .wordSpace { tokens.removeFirst() }
        while tokens.last == .wordSpace { tokens.removeLast() }

        self.tokens = tokens
        self.skipped = skipped
    }

    private static func speedMarkerNumber(_ inner: String) -> Int? {
        let lower = inner.lowercased()
        guard lower.hasPrefix("speed") else { return nil }
        return Int(lower.dropFirst(5))
    }

    /// The text as it will be sent, with prosigns in angle brackets and commands left out.
    public var displayText: String {
        var out = ""
        for token in tokens {
            switch token {
            case .symbol(let text, _): out += text
            case .wordSpace: out += " "
            default: break
            }
        }
        return out.split(separator: " ").joined(separator: " ")
    }
}
