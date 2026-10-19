// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AiruCore", platforms: [.macOS(.v14)], products: [
    .library(name: "AiruCore", targets: ["AiruCore"])
], targets: [
    .target(name: "AiruCore"),
    .testTarget(name: "AiruCoreTests", dependencies: ["AiruCore"], resources: [.copy("Fixtures")])
])
