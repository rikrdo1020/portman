// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ServicesPanel",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ServicesPanel",
            path: "Sources/ServicesPanel"
        )
    ]
)
