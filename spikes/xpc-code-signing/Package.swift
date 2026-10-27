// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "XPCCodeSigningSpike",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SpikeProtocol"),
        .executableTarget(name: "spike-daemon", dependencies: ["SpikeProtocol"]),
        .executableTarget(name: "spike-client", dependencies: ["SpikeProtocol"]),
    ]
)
