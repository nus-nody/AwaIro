// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroPresentation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroPresentation", targets: ["AwaIroPresentation"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain"),
        .package(path: "../AwaIroPlatform"),
        // swift-snapshot-testing: testTarget only — does NOT ship in app binary.
        // Used for G3 guardrail enforcement (no numeric metrics in HomeScreen).
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.16.0")
    ],
    targets: [
        .target(name: "AwaIroPresentation", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain"),
            .product(name: "AwaIroPlatform", package: "AwaIroPlatform")
        ]),
        .testTarget(name: "AwaIroPresentationTests", dependencies: [
            "AwaIroPresentation",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
        ])
    ]
)
