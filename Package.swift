// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PulseBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PulseBarCore", targets: ["PulseBarCore"]),
        .executable(name: "SystemMetricsProbe", targets: ["SystemMetricsProbe"]),
        .executable(name: "PerformanceProbe", targets: ["PerformanceProbe"])
    ],
    targets: [
        .target(
            name: "PulseBarCore",
            path: "PulseBar",
            exclude: [
                "App",
                "Features",
                "Resources",
                "Shared/AppActions.swift",
                "Shared/Settings/UnitSystemEnvironment.swift"
            ],
            sources: ["Monitoring", "Platform", "Shared"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Network"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .executableTarget(
            name: "SystemMetricsProbe",
            dependencies: ["PulseBarCore"],
            path: "Tools/SystemMetricsProbe"
        ),
        .executableTarget(
            name: "PerformanceProbe",
            dependencies: ["PulseBarCore"],
            path: "Tools/PerformanceProbe"
        ),
        .testTarget(
            name: "PulseBarCoreTests",
            dependencies: ["PulseBarCore"],
            path: "PulseBarTests"
        )
    ]
)
