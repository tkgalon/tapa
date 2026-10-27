// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tapa",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TapaCore", targets: ["TapaCore"]),
    ],
    targets: [
        .target(name: "TapaCore"),
        .target(name: "TapaIPC", dependencies: ["TapaCore"]),
        .target(name: "TapaDaemonKit", dependencies: ["TapaCore", "TapaIPC"]),
        .testTarget(name: "TapaCoreTests", dependencies: ["TapaCore"]),
        .testTarget(name: "TapaDaemonKitTests", dependencies: ["TapaDaemonKit", "TapaIPC"]),
    ]
)
