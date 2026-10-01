// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Portman",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Portman",
            path: "Sources/Portman"
        )
    ]
)
