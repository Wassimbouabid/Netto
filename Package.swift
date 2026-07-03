// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkLayer",
    // macOS is declared so the test suite can run natively via `swift test`;
    // the library itself targets iOS.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(
            name: "NetworkLayer",
            targets: ["NetworkLayer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0")
    ],
    targets: [
        .target(
            name: "NetworkLayer",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack")
            ],
            path: "LibraryCore/NetworkLayer/Sources/NetworkLayer"
        ),
        .testTarget(
            name: "NetworkLayerTests",
            dependencies: [
                "NetworkLayer",
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "LibraryCore/NetworkLayer/Tests/NetworkLayerTests"
        ),
    ]
)
