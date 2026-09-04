// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SchedulerKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SchedulerKit", targets: ["SchedulerKit"])
    ],
    targets: [
        .target(name: "SchedulerKit"),
        .testTarget(
            name: "SchedulerKitTests",
            dependencies: ["SchedulerKit"]
        ),
    ]
)
