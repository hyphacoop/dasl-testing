// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift",
    dependencies: [
        .package(url: "https://github.com/thecoolwinter/CBOR", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "swift",
            dependencies: ["CBOR"]
        ),
    ]
)
