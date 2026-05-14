// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexAccount",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CodexAccount",
            targets: ["CodexAccountSwitcher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexAccountSwitcher",
            path: "Sources"
        )
    ]
)
