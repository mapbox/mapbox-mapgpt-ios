// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.17.0"
let navNativeVersion: Version = "324.17.0"
let mapboxCommonGptChecksum = "d3d33e58b286b941cfc7382377005e2f7db8f9ef90986baebcd657e31450bb81"

let version = "3.17.0"
let mapGptVersion = "3.17.0-alpha.1"

let binaries = [
  "MapboxCoreMaps": "7ab481031da3fbc805d851463de614be6de7930aa49b917d3bd025e0ef48bc47",
  "MapboxDirections": "e0540653b7990a3cf4763f05534b9ed12db237b35867d52a37ac0258a8ac44fc",
  "MapboxMaps": "f53c893f77d8fcd24cc95e2e458f043096125c101a5b47b2bbdf18400c93d15f",
  "MapboxNavigationCore": "c442343d6dcac3299fd4122a4c909702ea89ebae85fa5763800ac790d8cea506",
  "MapboxNavigationUIKit": "4a83f8b88dc473558889c5c7831a3af64da0a733052cb9d7e1ed85b79b1f567f",
  "_MapboxNavigationHelpers": "fa76b377bc1669c0e8cac1c81687cd4179803e5f0cd29d3fc396513465db4059",
  "_MapboxNavigationLocalization":
    "4b87061d4dac9ca78698f83c6d59219e8e71b31499eacb79d688d600db74d453",
]

let libraries = [
  "MapboxMapGpt": "39f7dbcfcccbe1f27c9f8b3fbd2d113d808ff561c6ebee541f6438fd4831bacf",
  "MapboxMapGptUI": "9fa5c10e97cb691a4c989497a2bc27cde8e57830f3bebb0d186be30b63155ff7",
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
      binaryName: binaryName, version: mapGptVersion, checksum: checksum,
      packageName: "mapbox-mapgpt-ios")
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
