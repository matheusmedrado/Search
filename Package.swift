// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Search",
    // macOS 26 and later: the frame is glass (see Glass.swift), and the
    // glass is Apple's, which is not there before 26.
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Search",
            path: "Sources/Search",
            // Same reasoning as the canvas app next door: the whole interface is
            // main-thread by nature, and Swift 6's strict isolation buys nothing
            // here but ceremony.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: ["Search"],
            path: "Tests/SearchTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
