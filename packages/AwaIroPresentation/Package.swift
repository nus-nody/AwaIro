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
        .package(path: "../AwaIroPlatform")
    ],
    targets: [
        .target(name: "AwaIroPresentation", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain"),
            .product(name: "AwaIroPlatform", package: "AwaIroPlatform")
        ]),
        .testTarget(name: "AwaIroPresentationTests", dependencies: ["AwaIroPresentation"])
    ]
)
