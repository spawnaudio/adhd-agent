// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusFlow",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusFlow", targets: ["FocusFlowMac"]),
        .executable(name: "Focus", targets: ["FocusApp"])
    ],
    targets: [
        .target(name: "FocusFlowCore"),
        .executableTarget(name: "FocusFlowMac", dependencies: ["FocusFlowCore"]),
        .testTarget(name: "FocusFlowCoreTests", dependencies: ["FocusFlowCore"]),
        .target(name: "FocusCore"),
        .executableTarget(name: "FocusApp", dependencies: ["FocusCore"]),
        .testTarget(name: "FocusCoreTests", dependencies: ["FocusCore"])
    ]
)
