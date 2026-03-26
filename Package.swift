// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let (mapboxCommonGptVersion, mapboxCommonGptChecksum) = (Version("23.12.0"), "6d263315b2f0a40a9cc16b80444f21b7294b1b330eedae3b3465a4fd5725b4aa")

let mapboxCommon: Version = "23.12.0"

let package = Package(
    name: "MapboxFeedbackAgent",
    defaultLocalization: "en",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "MapboxFeedbackAgent",
            targets: [
                "MapboxFeedbackAgent",
                "MapboxCommonGpt",
            ]
        ),
        .library(
            name: "MapboxFeedbackAgentUI",
            targets: [
                "MapboxFeedbackAgentUI",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mapbox/mapbox-common-ios.git", exact: mapboxCommon),
        .package(url: "https://github.com/mapbox/mapbox-navigation-ios.git", from: "2.20.1"),
    ],
    targets: [
        .target(
            name: "MapboxFeedbackAgent",
            dependencies: [
                .product(name: "MapboxCommon", package: "mapbox-common-ios"),
                .product(name: "MapboxCoreNavigation", package: "mapbox-navigation-ios"),
            ]
        ),
        .target(
            name: "MapboxFeedbackAgentUI",
            dependencies: [.byName(name: "MapboxFeedbackAgent")],
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
