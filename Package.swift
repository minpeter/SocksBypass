// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SocksBypass",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // xtool builds the single library product as the app.
        .library(name: "SocksBypass", targets: ["SocksBypass"]),
    ],
    targets: [
        .target(name: "SocksBypass", resources: [.copy("Resources/Fonts")]),
        .testTarget(name: "SocksBypassTests", dependencies: ["SocksBypass"]),
    ],
    swiftLanguageModes: [.v5]
)
