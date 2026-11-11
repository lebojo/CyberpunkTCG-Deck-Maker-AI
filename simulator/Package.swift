// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeckSim",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "DeckSim", path: "Sources/DeckSim")
    ]
)
