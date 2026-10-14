// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SweeperKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SweeperKit", targets: ["SweeperKit"]),
    ],
    targets: [
        .target(name: "SweeperKit"),
        .testTarget(name: "SweeperKitTests", dependencies: ["SweeperKit"]),
    ]
)
