# CWKit

The Morse code engine shared by G3AJM's apps for radio amateurs: [HW CPY](https://g3ajm.radio/hwcpy/),
[Mock QSO](https://g3ajm.radio/mockqso/) and [QRQ Trainer](https://g3ajm.radio/qrqtrainer/). A Swift package with no UI.

- **Alphabet:** letters, digits, punctuation and common non-English letters (ITU-R M.1677-1), and prosigns written as
  their letters (`<AR>`, `<BT>`, `<SK>`).
- **Timing:** PARIS (dit = 1.2 / WPM), Farnsworth (ARRL formula: characters at full speed, gaps stretched) and
  Wordsworth (only the gaps between words stretched), in WPM or CPM (1 WPM = 5 CPM). Speeds from 1 to 100 WPM.
- **Text:** prosigns and ebook2cw's inline commands (`|S1000` pause, `|f650` tone, `|w30` and `|e15` speeds).
- **Keying and sound:** text to key-down / key-up segments, rendered to mono Float32 samples with raised-cosine edges,
  so there are no key clicks. Mono 16-bit WAV files on Apple platforms.

It builds for macOS 14+, iOS 17+ and WebAssembly (WASI), where it uses no Foundation, so the web apps stay small.

```swift
import CWKit

let timing = MorseTiming(characterWPM: 25, spacing: .farnsworth(overallWPM: 15))
let samples = ToneRenderer(tone: ToneSettings(frequency: 600), timing: timing).render("CQ DE G3AJM <AR>")
```

## Using it

```swift
.package(url: "https://github.com/welly/cw-kit.git", from: "1.0.0"),
```

and `.product(name: "CWKit", package: "cw-kit")` in a target's dependencies.

## Tests

```bash
./scripts/test.sh
```

(With full Xcode, plain `swift test` works too; the script adds the framework paths the Command Line Tools need for
Swift Testing.)

## Licence

Copyright © 2026 Alastair Moore, G3AJM.

CWKit is free software: you can redistribute it and modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License or (at your option) any later version. It
comes with no warranty. See [LICENSE](LICENSE) for the full text.
