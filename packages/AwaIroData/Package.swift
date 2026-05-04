// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroData", targets: ["AwaIroData"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain")
    ],
    targets: [
        .target(name: "AwaIroData", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain")
        ]),
        .testTarget(name: "AwaIroDataTests", dependencies: ["AwaIroData"])
    ]
)
