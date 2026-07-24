// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.28.0-alpha.1"
let navNativeVersion: Version = "324.28.0-alpha.1"
let mapboxCommonGptChecksum = "83de98f8fa09b14c13a7e173dc3e872162d7cabb7cb98aabbc0889306c4d2508"

let version = "3.28.0"
let mapGptVersion = "3.28.0-alpha.1"

let binaries = [
  "MapboxCoreMaps": "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
  "MapboxDirections": "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
  "MapboxMaps": "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
  "MapboxNavigationCore": "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
  "MapboxNavigationUIKit": "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
  "_MapboxNavigationHelpers": "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
  "_MapboxNavigationLocalization":
    "8fd54eee4277f1327015cc0bcaed8a878bf44d1804364cd5d93dfab9e2d1a5af",
]

let libraries = [
  "MapboxMapGpt": "a61d29628e43ffc1d16d59aecb01d53a531265a2b24ef22741ffb6831cb2d27e",
  "MapboxMapGptUI": "8503639d55e7d62b31b6da67bf11e63ab9e31f237647a1ad7639f6b09ec9e6fc",
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
