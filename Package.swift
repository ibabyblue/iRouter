// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iRouter",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "iRouter", targets: ["iRouter"]),
    ],
    targets: [
        .target(name: "iRouter"),
        .testTarget(name: "iRouterTests", dependencies: ["iRouter"]),
    ]
)
