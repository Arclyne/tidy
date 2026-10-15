// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tidy",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Tidy", targets: ["Tidy"]),
        .library(name: "TidyCore", targets: ["TidyCore"])
    ],
    targets: [
        .target(
            name: "TidyCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Tidy",
            dependencies: ["TidyCore"]
        ),
        .testTarget(
            name: "TidyCoreTests",
            dependencies: ["TidyCore"]
        )
    ]
)
