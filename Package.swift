// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.35.1"
let navNativeVersion: Version = "324.35.1"

let version = "3.35.1"
let mapGptVersion = "3.35.1"

let binaries = [
  "MapboxCoreMaps": "f584c16a6e8c38ce2621af0abe2c0607becf6c752db972a91d52ca6ed6d0152f",
  "MapboxDirections": "338d52f8f406ea2a8baa9ee7df4c14586dd81c794b1a6b7930a189eb2a890d48",
  "MapboxMaps": "ce8c4cf6a854858a37696f1cc0e9992815680b50ea576f7b86133f021db6065d",
  "MapboxNavigationCore": "3772448466f7e655cf95d95faa107781509457f16bcfc563f3ff2bece9611674",
  "MapboxNavigationUIKit": "e266eecbec134578a4cb72487ab8dbea98ab80118ba53da72919e52dca4711a8",
  "_MapboxNavigationHelpers": "7ebadba16e89cc00c755b3fc7ac8cc6629128c50adafe7cb44238b6daf59fdf3",
  "_MapboxNavigationLocalization":
    "6676e5834a74848cb5b93420f5c543d29efb1ad0b26525d91d5f9240eb381067",
]

let libraries = [
  "MapboxMapGpt": "366a0a553fe77ba24ba41a566370b57dacbe06e4091419b168e603c539e4fe2d",
  "MapboxMapGptUI": "0a915459958d6ed95b42f060a4073c78319f0050b93a4e32bf5223db6cfac215",
]

enum FrameworkType {
  case release
  case staging
  case local
}

let frameworkType: FrameworkType = .release

let commonGptTarget = frameworkType == .local ? "MapboxCommonGpt" : "MapboxCommonGptWrapper"

func commonGptTargets() -> [Target] {
  switch frameworkType {
  case .release, .staging:
    return [
      .target(
        name: "MapboxCommonGptWrapper",
        dependencies: [.product(name: "MapboxMapGptNative", package: "mapbox-mapgpt-native-ios")],
        path: "Sources/.empty/MapboxCommonGptWrapper"
      )
    ]
  case .local:
    return [
      .binaryTarget(name: "MapboxCommonGpt", path: "XCFrameworks/MapboxCommonGpt.xcframework")
    ]
  }
}

func packageDependencies() -> [Package.Dependency] {
  var packages: [Package.Dependency] = [
    .package(url: "https://github.com/mapbox/mapbox-common-ios.git", exact: commonVersion),
    .package(
      url: "https://github.com/mapbox/mapbox-navigation-native-ios.git", exact: navNativeVersion),
  ]
  // Only the wrapper-backed modes need it; .local reads MapboxCommonGpt off disk instead, which
  // needs no checksum either -- only the remote url: variant the wrapper replaces did.
  if frameworkType != .local {
    packages.append(
      .package(url: "https://github.com/mapbox/mapbox-mapgpt-native-ios.git", exact: commonVersion))
  }
  return packages
}

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
      targets: [commonGptTarget]
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
  dependencies: packageDependencies(),
  targets: binaryTargets() + libraryTargets() + wrapperTargets() + commonGptTargets()
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
