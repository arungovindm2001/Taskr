// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TaskrCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TaskrCore", targets: ["TaskrCore"]),
        .executable(name: "taskr-sample", targets: ["taskr-sample"]),
    ],
    targets: [
        .target(name: "TaskrCore"),
        .executableTarget(name: "taskr-sample", dependencies: ["TaskrCore"]),
    ]
)
