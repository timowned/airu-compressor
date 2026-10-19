// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AiruUI", platforms: [.macOS(.v14)], products: [
    .library(name: "AiruUI", targets: ["AiruUI"])
], dependencies: [.package(path: "../AiruCore")], targets: [
    .target(name: "AiruUI", dependencies: [.product(name: "AiruCore", package: "AiruCore")], resources: [.process("Resources")]),
    .testTarget(name: "AiruUITests", dependencies: ["AiruUI"])
])
