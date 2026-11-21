// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NOTCHORA",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NOTCHORA", targets: ["NotchoraApp"]),
        .library(name: "NotchoraCore", targets: ["NotchoraCore"])
    ],
    targets: [
        .target(
            name: "NotchoraCore",
            path: "Sources/NotchoraCore"
        ),
        .executableTarget(
            name: "NotchoraApp",
            dependencies: ["NotchoraCore"],
            path: "Sources/NotchoraApp"
        ),
        .testTarget(
            name: "NotchoraCoreTests",
            dependencies: ["NotchoraCore"],
            path: "Tests/NotchoraCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
