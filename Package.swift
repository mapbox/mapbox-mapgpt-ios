// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let (mapboxCommonGptVersion, mapboxCommonGptChecksum) = (Version("23.12.0-alpha.2"), "fe9b20a80289708927be1de873f9672a3928a4063838b0fea81d266625b8139a")

let package = Package(
    name: "MapboxFeedbackAgent",
    defaultLocalization: "en",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "FeedbackAgent",
            targets: [
                "FeedbackAgent",
                "MapboxCommonGpt",
            ]
        ),
        .library(
            name: "FeedbackAgentUI",
            targets: [
                "FeedbackAgentUI",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mapbox/mapbox-common-ios.git", from: mapboxCommonGptVersion),
        .package(url: "https://github.com/mapbox/mapbox-navigation-ios.git", from: "2.20.1"),
    ],
    targets: [
        .target(
            name: "FeedbackAgent",
            dependencies: [
                .product(name: "MapboxCommon", package: "mapbox-common-ios"),
                .product(name: "MapboxCoreNavigation", package: "mapbox-navigation-ios"),
            ],
            path: "Sources/FeedbackAgent"
        ),
        .target(
            name: "FeedbackAgentUI",
            dependencies: [.byName(name: "FeedbackAgent")],
            resources: [
                .copy("FeedbackAgentUIAssets.xcassets"),
            ]
        ),
        .binaryTarget(
            name: "MapboxCommonGpt",
            url: "https://api.mapbox.com/downloads/v2/mapbox-common-mapgpt/releases/ios/packages/\(mapboxCommonGptVersion)/MapboxCommonGpt.zip",
            checksum: mapboxCommonGptChecksum
        ),
    ]
)
