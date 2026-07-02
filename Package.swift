// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AiBrowserKit",
    platforms: [.macOS("26.0"), .iOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "AiBrowserKit", targets: ["AiBrowserKit"]),
        // Browser-agnostic UI controls (SFSymbolPicker), usable without the browser stack.
        .library(name: "AiBrowserKitUI", targets: ["AiBrowserKitUI"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AiBrowserKitUI",
            dependencies: [],
            path: "Sources/AiBrowserKitUI"
        ),
        .target(
            name: "AiBrowserKit",
            dependencies: ["AiBrowserKitUI"],
            path: "Sources/AiBrowserKit"
        ),
        .testTarget(
            name: "AiBrowserKitTests",
            dependencies: ["AiBrowserKit"],
            path: "Tests/AiBrowserKitTests"
        ),
    ]
)
