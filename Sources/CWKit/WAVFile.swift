// Not in the Wasm build, which has no Foundation (the web page makes its own WAV if it needs one).
#if !os(WASI)
import Foundation

/// Writes mono 16-bit PCM WAV files, for checking rendered audio by ear.
public enum WAVFile {
    public static func data(samples: [Float], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        var data = Data(capacity: 44 + dataSize)

        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))                                 // fmt chunk size
        append(UInt16(1))                                  // PCM
        append(UInt16(1))                                  // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * bytesPerSample))        // byte rate
        append(UInt16(bytesPerSample))                     // block align
        append(UInt16(16))                                 // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        // Converted in one go: appending sample by sample is very slow in debug builds.
        let pcm = samples.map { Int16((max(-1, min(1, $0)) * Float(Int16.max)).rounded()).littleEndian }
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    public static func write(samples: [Float], sampleRate: Int, to url: URL) throws {
        try data(samples: samples, sampleRate: sampleRate).write(to: url)
    }
}
#endif
