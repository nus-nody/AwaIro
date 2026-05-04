// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroDomain", targets: ["AwaIroDomain"])
    ],
    targets: [
        .target(name: "AwaIroDomain"),
        .testTarget(name: "AwaIroDomainTests", dependencies: ["AwaIroDomain"])
    ]
)
