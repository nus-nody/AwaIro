// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroData", targets: ["AwaIroData"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0")
    ],
    targets: [
        .target(name: "AwaIroData", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain"),
            .product(name: "GRDB", package: "GRDB.swift")
        ]),
        .testTarget(name: "AwaIroDataTests", dependencies: ["AwaIroData"])
    ]
)
