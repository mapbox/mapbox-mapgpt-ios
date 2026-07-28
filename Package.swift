// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.28.0-alpha.3"
let navNativeVersion: Version = "324.28.0-alpha.3"
let mapboxCommonGptChecksum = "9249f4823da22ebce9134dfe01752bedf9492184ab5ed3973a615dd09e588352"

let version = "3.28.0-alpha.3"
let mapGptVersion = "3.28.0-alpha.3"

let binaries = [
  "MapboxCoreMaps": "4138a8c9160a2d1a9a42ff60453833f1603605c7aefb4e818990eddc2e324da6",
  "MapboxDirections": "76caf840f55007b547fd73fbc41f0f8c8974a26db366cc996e80f2ac89e0f02d",
  "MapboxMaps": "c80f68d093104cf621bc2c75ff47afcd250c819c20e47d928476b7794330ff4c",
  "MapboxNavigationCore": "6f2ea6b81917c1c5708dcc03b2e65a085e6ed750d7f1659077ece9a38c17052f",
  "MapboxNavigationUIKit": "48b00fdb6650247844d085a7612175e635dbc573c0a0be6775d0b47a48a61e9d",
  "_MapboxNavigationHelpers": "3eaf62b3124eaade5ee29046157c5a863edc5203e6a639866f8a76982f62ab24",
  "_MapboxNavigationLocalization":
    "33f814ebd96ef2e4aea26201a6437c96c4a47466e53a0600a1fd1c49cfe83528",
]

let libraries = [
  "MapboxMapGpt": "d5f87b2718d0df88210d34b460f61008220c408455450eb9ca3e24dcdf001622",
  "MapboxMapGptUI": "5b32f55b3789662cd9c14503e0fda38912fe8e92d7b73f475a4195ccdb0f23df",
]

enum FrameworkType {
  case release
  case staging
  case local
}

let frameworkType: FrameworkType = .release

let package = Package(
  name: "MapboxMapGpt",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "MapboxMapGpt",
      targets: ["MapboxMapGptWrapper"]
    ),
    .library(
      name: "MapboxMapGptUI",
      targets: ["MapboxMapGptUIWrapper"]
    ),
    .library(
      name: "MapboxCommonGpt",
      targets: ["MapboxCommonGpt"]
    ),
    .library(
      name: "MapboxNavigationCore",
      targets: ["MapboxNavigationCoreWrapper"]
    ),
    .library(
      name: "MapboxNavigationUIKit",
      targets: ["MapboxNavigationUIKitWrapper"]
    ),
    .library(
      name: "MapboxDirections",
      targets: ["MapboxDirectionsWrapper"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/mapbox/mapbox-common-ios.git", exact: commonVersion),
    .package(
      url: "https://github.com/mapbox/mapbox-navigation-native-ios.git", exact: navNativeVersion),
  ],
  targets: binaryTargets() + libraryTargets() + wrapperTargets()
)

// mapbox-navigation-ios
func binaryTargets() -> [Target] {
  binaries.map { binaryName, checksum in
    binaryTarget(binaryName: binaryName, checksum: checksum, packageName: "navsdk-v3-ios")
  }
}

// MapGpt
func libraryTargets() -> [Target] {
  libraries.map { binaryName, checksum in
    binaryTarget(
      binaryName: binaryName,
      version: mapGptVersion,
      checksum: checksum,
      packageName: "mapbox-mapgpt-ios"
    )
  }
}

func wrapperTargets() -> [Target] {
  [
    .target(
      name: "MapboxMapGptWrapper",
      dependencies: [
        "MapboxMapGpt"
      ],
      path: "Sources/.empty/MapboxMapGptWrapper"
    ),
    .target(
      name: "MapboxMapGptUIWrapper",
      dependencies: [
        "MapboxMapGptUI"
      ],
      path: "Sources/.empty/MapboxMapGptUIWrapper"
    ),
    commonBinaryTarget(
      binaryName: "MapboxCommonGpt",
      checksum: mapboxCommonGptChecksum,
      packageName: "mapbox-common-mapgpt"
    ),
    // ---
    .target(
      name: "MapboxNavigationCoreWrapper",
      dependencies:
        binaries.keys
        .filter { $0 != "MapboxNavigationUIKit" }
        .map { .byName(name: $0) }
        + [
          .product(name: "MapboxCommon", package: "mapbox-common-ios"),
          .product(name: "MapboxNavigationNative", package: "mapbox-navigation-native-ios"),
        ],
      path: "Sources/.empty/MapboxNavigationCoreWrapper"
    ),
    .target(
      name: "MapboxNavigationUIKitWrapper",
      dependencies: [
        "MapboxNavigationUIKit",
        "MapboxNavigationCoreWrapper",
      ],
      path: "Sources/.empty/MapboxNavigationUIKitWrapper"
    ),
    .target(
      name: "MapboxDirectionsWrapper",
      dependencies: [
        "MapboxDirections",
        .product(name: "MapboxCommon", package: "mapbox-common-ios"),
      ],
      path: "Sources/.empty/MapboxDirectionsWrapper"
    ),
  ]
}

func binaryTarget(
  binaryName: String, version: String = version, checksum: String, packageName: String
) -> Target {
  switch frameworkType {
  case .release, .staging:
    let host = frameworkType == .release ? "api.mapbox.com" : "cloudfront-staging.tilestream.net"
    return Target.binaryTarget(
      name: binaryName,
      url: "https://\(host)/downloads/v2/\(packageName)"
        + "/releases/ios/packages/\(version)/\(binaryName).xcframework.zip",
      checksum: checksum
    )
  case .local:
    return Target.binaryTarget(
      name: binaryName,
      path: "XCFrameworks/\(binaryName).xcframework"
    )
  }
}

func commonBinaryTarget(
  binaryName: String, checksum: String, packageName: String
) -> Target {
  switch frameworkType {
  case .release, .staging:
    let host = frameworkType == .release ? "api.mapbox.com" : "cloudfront-staging.tilestream.net"
    return Target.binaryTarget(
      name: binaryName,
      url: "https://\(host)/downloads/v2/\(packageName)"
        + "/releases/ios/packages/\(commonVersion.description)/\(binaryName).zip",
      checksum: checksum
    )
  case .local:
    return Target.binaryTarget(
      name: binaryName,
      path: "XCFrameworks/\(binaryName).xcframework"
    )
  }
}
