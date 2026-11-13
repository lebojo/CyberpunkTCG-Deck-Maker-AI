// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeckSim",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DeckSim", targets: ["DeckSim"]),
        .executable(name: "FetchCards", targets: ["FetchCards"]),
        .library(name: "SimCore", targets: ["SimCore"]),
    ],
    targets: [
        .target(name: "SimCore", path: "Sources/SimCore", resources: [.process("Resources")]),
        .executableTarget(name: "DeckSim", dependencies: ["SimCore"], path: "Sources/DeckSim"),
        .executableTarget(name: "FetchCards", path: "Sources/FetchCards"),
        .testTarget(name: "SimCoreTests", dependencies: ["SimCore"], path: "Tests/SimCoreTests"),
    ]
)
