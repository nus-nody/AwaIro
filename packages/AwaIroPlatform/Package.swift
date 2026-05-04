// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AwaIroPlatform",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "AwaIroPlatform", targets: ["AwaIroPlatform"])
  ],
  dependencies: [
    .package(path: "../AwaIroDomain")
  ],
  targets: [
    .target(
      name: "AwaIroPlatform",
      dependencies: [
        .product(name: "AwaIroDomain", package: "AwaIroDomain")
      ],
      resources: [
        .process("Effects")
      ]
    ),
    .testTarget(name: "AwaIroPlatformTests", dependencies: ["AwaIroPlatform"]),
  ]
)
