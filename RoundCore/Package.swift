// swift-tools-version:5.9
// RoundCore is the whole workout with no UI in it: the moves library, the
// combo generator, the timeline, and which haptic plays when. It is plain Foundation so `swift test`
// runs it anywhere (Linux CI included); the watch app is a thin SwiftUI shell
// that turns `Pulse` values into WKHapticType.
import PackageDescription

let package = Package(
    name: "RoundCore",
    platforms: [.watchOS(.v9), .iOS(.v16), .macOS(.v13)],
    products: [.library(name: "RoundCore", targets: ["RoundCore"])],
    targets: [
        .target(name: "RoundCore"),
        .testTarget(name: "RoundCoreTests", dependencies: ["RoundCore"]),
    ]
)
