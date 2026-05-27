// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.24.2"
let navNativeVersion: Version = "324.24.2"
let mapboxCommonGptChecksum = "9acc81e2a85b5ed180052e32e5a3e701a6f6c5e2c56b0f163b756d1d4a49aada"

let version = "3.24.2"
let mapGptVersion = "3.24.2"

let binaries = [
  "MapboxCoreMaps": "da5bf626f8d02213441b8074ca3fedce56f16ad56994fb5ad42ec5814ebdb900",
  "MapboxDirections": "07719c07dd17a8f137c92146d875183d0a52b9ed365595a8a6c11f663746e6fb",
  "MapboxMaps": "4a6b39bf6a97df430039e2b635798df9f665cb676d5a9671a3b495fc484deeeb",
  "MapboxNavigationCore": "ed1cc03b88741389ede736c8c9fb88959abdaa73db78acfaf3725e264410ab5e",
  "MapboxNavigationUIKit": "f8509abceadee1f421a20911c16e9c5c089f8587f64e60171a2068fb593d5fed",
  "_MapboxNavigationHelpers": "1f265eff27f0e847db508601eedf3193300d57aa4606152ad8ebb9d9a4fea7d0",
  "_MapboxNavigationLocalization":
    "36faa193e83d5a86c8b1add1f972a7ecdf0ec9c20adffe6fe50e6e818f8c18bf",
]

let libraries = [
  "MapboxMapGpt": "e1fb84bf7164a0c0151b971167f955b999b006776a07f749e7723602ccd2276a",
  "MapboxMapGptUI": "6fdba8babe51423ee82ff020e93866924ff18269f1cede2a44b4f712d228887e",
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
