// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PortGuardCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PortGuardCore", targets: ["PortGuardCore"]),
    ],
    targets: [
        .target(name: "PortGuardCore"),
        .testTarget(name: "PortGuardCoreTests", dependencies: ["PortGuardCore"]),
    ]
)
