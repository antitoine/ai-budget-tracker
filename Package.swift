// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIBudgetBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AIBudgetBar",
            targets: ["AIBudgetBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AIBudgetBar",
            path: "Sources/AIBudgetBar"
        ),
        .testTarget(
            name: "AIBudgetBarTests",
            dependencies: ["AIBudgetBar"]
        )
    ]
)
