// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DJMacPlayer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DJMacPlayer", targets: ["DJPlayerApp"])
    ],
    targets: [
        .executableTarget(
            name: "DJPlayerApp",
            path: "Sources/DJPlayerApp",
            resources: []
        )
    ]
)
