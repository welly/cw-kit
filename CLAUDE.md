# CWKit (cw-kit)

The Morse engine shared by HW CPY, Mock QSO and QRQ Trainer (github.com/welly/cw-kit, public, GPL-3.0-or-later).
Started 2026-11-24 from HW CPY's `CWKit`, with Mock QSO's faster WAV writer, CPM helpers and `MorseKeyer.units(of:)`
for QRQ Trainer's scoring. Oscillator keeps its own engine (the owner's choice).

## Rules

- Apps depend on it by URL and version (`from: "1.0.0"`). Tag a new version for every change apps need
  (semantic versioning: a behaviour or API change that breaks an app is a new major version).
- Changes affect every app: run each app's tests, and for Mock QSO check a seed still gives the same QSO
  (`node scripts/web-check.mjs <kind> <seed>`), before tagging.
- No Foundation on WASI (the web apps): `#if os(WASI) import WASILibc` for maths; `WAVFile` is Apple-only.
  Check with the swift.org toolchain: `swift build --target CWKit --swift-sdk swift-6.4.3-RELEASE_wasm`.
- Speeds are 1–100 WPM (`MorseTiming.wpmRange`): nobody needs training above that (owner, 2026-11-24).
- No UI and no app-specific code (practice-file formats, QSO generation, scoring rules stay in the apps).
- Tests: `./scripts/test.sh`.
