// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkLayer",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "NetworkLayer",
            targets: ["NetworkLayer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0")
    ],
    targets: [
        .target(
            name: "NetworkLayer",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "LibraryCore/NetworkLayer/Sources/NetworkLayer"
        ),
    ]
)
