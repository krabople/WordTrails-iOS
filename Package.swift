// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "TrailCore", platforms: [.iOS(.v17)], products: [.library(name: "TrailCore", targets: ["TrailCore"])], targets: [.target(name: "TrailCore", resources: [.process("Resources")]), .testTarget(name: "TrailCoreTests", dependencies: ["TrailCore"])])
