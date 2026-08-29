// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PulseBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PulseBarCore", targets: ["PulseBarCore"]),
        .executable(name: "SystemMetricsProbe", targets: ["SystemMetricsProbe"])
    ],
    targets: [
        .target(
            name: "PulseBarCore",
            path: "PulseBar",
            exclude: ["App", "Features", "Resources"],
            sources: ["Monitoring", "Platform", "Shared"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .executableTarget(
            name: "SystemMetricsProbe",
            dependencies: ["PulseBarCore"],
            path: "Tools/SystemMetricsProbe"
        ),
        .testTarget(
            name: "PulseBarCoreTests",
            dependencies: ["PulseBarCore"],
            path: "PulseBarTests"
        )
    ]
)
