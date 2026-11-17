// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PADRoguelikeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PADRoguelikeCore", targets: ["PADRoguelikeCore"]),
    ],
    targets: [
        .target(name: "PADRoguelikeCore"),
        .testTarget(name: "PADRoguelikeCoreTests", dependencies: ["PADRoguelikeCore"]),
    ]
)
