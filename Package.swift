// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Airu", platforms: [.macOS(.v14)], products: [
    .executable(name: "airu", targets: ["AiruCLI"])
], dependencies: [.package(path: "Packages/AiruCore")], targets: [
    .executableTarget(name: "AiruCLI", dependencies: [.product(name: "AiruCore", package: "AiruCore")], path: "CLI")
])
