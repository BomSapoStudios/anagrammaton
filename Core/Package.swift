// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AnagrammatonCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AnagrammatonCore", targets: ["AnagrammatonCore"]),
    ],
    targets: [
        .target(name: "AnagrammatonCore"),
        .testTarget(name: "AnagrammatonCoreTests", dependencies: ["AnagrammatonCore"]),
    ]
)
