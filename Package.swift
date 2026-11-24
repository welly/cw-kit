// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CWKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "CWKit", targets: ["CWKit"]),
    ],
    targets: [
        // The Morse engine shared by the G3AJM apps: alphabet, PARIS / Farnsworth / Wordsworth timing, text with
        // prosigns and inline commands, keying, click-free tone rendering and WAV files. No UI, no Apple-only
        // frameworks, and no Foundation on WASI, so the web apps can compile it to WebAssembly.
        .target(name: "CWKit"),
        .testTarget(name: "CWKitTests", dependencies: ["CWKit"]),
    ]
)
