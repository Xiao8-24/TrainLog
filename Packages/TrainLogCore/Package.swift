// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TrainLogCore",
    platforms: [.iOS("27.0"), .macOS(.v14)],
    products: [.library(name: "TrainLogCore", targets: ["TrainLogCore"])],
    targets: [
        .target(name: "TrainLogCore"),
        .testTarget(name: "TrainLogCoreTests", dependencies: ["TrainLogCore"])
    ]
)

