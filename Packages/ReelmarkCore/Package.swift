// swift-tools-version: 6.0
import PackageDescription

// All of Reelmark's logic that doesn't need a window lives here, so it can be
// tested with `swift test` on CI. Apple frameworks only; no dependencies.
let package = Package(
    name: "ReelmarkCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "ReelmarkCore", targets: ["ReelmarkCore"])
    ],
    targets: [
        .target(name: "ReelmarkCore"),
        .testTarget(name: "ReelmarkCoreTests", dependencies: ["ReelmarkCore"]),
    ]
)
