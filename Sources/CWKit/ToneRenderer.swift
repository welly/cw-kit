#if os(WASI)
import WASILibc // Wasm: no Foundation, which would add megabytes to the web apps
#else
import Foundation
#endif

/// The sound of the CW tone.
public struct ToneSettings: Sendable, Equatable, Hashable {
    /// Tone frequency in Hz.
    public var frequency: Double
    /// Rise time of each element's leading edge in seconds. Clamped to half an element at high speeds.
    public var riseTime: Double
    /// Fall time of each element's trailing edge in seconds. Clamped to half an element at high speeds.
    public var fallTime: Double
    /// Peak amplitude, 0...1.
    public var amplitude: Double
    /// Output sample rate in Hz.
    public var sampleRate: Double

    public init(frequency: Double = 700, riseTime: Double = 0.004, fallTime: Double? = nil,
                amplitude: Double = 0.8, sampleRate: Double = 48_000) {
        self.frequency = frequency
        self.riseTime = riseTime
        self.fallTime = fallTime ?? riseTime
        self.amplitude = amplitude
        self.sampleRate = sampleRate
    }
}

/// Renders Morse to mono Float32 PCM: a sine wave whose edges are shaped with a raised cosine,
/// so there are no key clicks.
///
/// Rendering allocates, so do it ahead of time, not on the audio thread.
public struct ToneRenderer: Sendable {
    public var tone: ToneSettings
    public var timing: MorseTiming

    public init(tone: ToneSettings = ToneSettings(), timing: MorseTiming) {
        self.tone = tone
        self.timing = timing
    }

    public func render(_ text: String) -> [Float] {
        render(segments: MorseKeyer.segments(for: text, timing: timing))
    }

    public func render(tokens: [MorseToken]) -> [Float] {
        render(segments: MorseKeyer.segments(for: tokens, timing: timing))
    }

    /// Number of samples `render(segments:)` produces.
    public func sampleCount(for segments: [KeySegment]) -> Int {
        Int((MorseKeyer.duration(of: segments) * tone.sampleRate).rounded())
    }

    public func render(segments: [KeySegment]) -> [Float] {
        let sampleRate = tone.sampleRate
        var samples = [Float](repeating: 0, count: sampleCount(for: segments))
        var elapsed = 0.0
        var phase = 0.0

        for segment in segments {
            // Sample boundaries come from the running total, so rounding never accumulates drift.
            let start = Int((elapsed * sampleRate).rounded())
            elapsed += segment.duration
            let end = min(Int((elapsed * sampleRate).rounded()), samples.count)
            let count = end - start
            guard segment.isOn, count > 0 else { continue }

            let frequency = segment.frequency ?? tone.frequency
            let step = 2 * Double.pi * frequency / sampleRate
            let rise = min(Int((tone.riseTime * sampleRate).rounded()), count / 2)
            let fall = min(Int((tone.fallTime * sampleRate).rounded()), count / 2)

            for i in 0..<count {
                var envelope = 1.0
                let fromEnd = count - 1 - i
                if i < rise {
                    envelope = 0.5 - 0.5 * cos(Double.pi * (Double(i) + 0.5) / Double(rise))
                } else if fromEnd < fall {
                    envelope = 0.5 - 0.5 * cos(Double.pi * (Double(fromEnd) + 0.5) / Double(fall))
                }
                samples[start + i] = Float(tone.amplitude * envelope * sin(phase))
                phase += step
            }
            phase = phase.truncatingRemainder(dividingBy: 2 * Double.pi)
        }
        return samples
    }
}
