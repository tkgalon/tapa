// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tapa",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TapaCore", targets: ["TapaCore"]),
    ],
    targets: [
        .target(name: "TapaCore"),
        .target(name: "TapaIPC", dependencies: ["TapaCore"]),
        .target(name: "TapaDaemonKit", dependencies: ["TapaCore", "TapaIPC"]),
        .target(name: "TapaUsage", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "TapaDaemon", dependencies: ["TapaDaemonKit"]),
        .executableTarget(name: "tapactl", dependencies: ["TapaCore", "TapaIPC"]),
        .executableTarget(name: "TapaApp", dependencies: ["TapaCore", "TapaIPC", "TapaUsage"]),
        .executableTarget(
            name: "TapaTracker",
            dependencies: ["TapaCore", "TapaIPC", "TapaUsage"],
            exclude: ["Info.plist"],
            // Embedded so the Automation prompt names Tapa and explains why.
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/TapaTracker/Info.plist",
                ]),
            ]
        ),
        .testTarget(name: "TapaCoreTests", dependencies: ["TapaCore"]),
        .testTarget(name: "TapaDaemonKitTests", dependencies: ["TapaDaemonKit", "TapaIPC"]),
        .testTarget(name: "TapaUsageTests", dependencies: ["TapaUsage"]),
    ]
)
