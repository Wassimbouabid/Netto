// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Netto",
    // macOS is declared so the test suite can run natively via `swift test`;
    // the library itself targets iOS.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(
            name: "Netto",
            targets: ["Netto"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0")
    ],
    targets: [
        .target(
            name: "Netto",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack")
            ],
            path: "LibraryCore/Netto/Sources/Netto"
        ),
        .testTarget(
            name: "NettoTests",
            dependencies: [
                "Netto",
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "LibraryCore/Netto/Tests/NettoTests"
        ),
    ]
)
