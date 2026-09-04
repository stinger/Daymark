// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AssistantKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AssistantKit", targets: ["AssistantKit"])
    ],
    dependencies: [
        .package(path: "../SchedulerKit")
    ],
    targets: [
        .target(
            name: "AssistantKit",
            dependencies: ["SchedulerKit"]
        ),
        .testTarget(
            name: "AssistantKitTests",
            dependencies: ["AssistantKit", "SchedulerKit"]
        ),
    ]
)
