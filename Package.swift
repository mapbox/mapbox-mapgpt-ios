// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.35.0-rc.1"
let navNativeVersion: Version = "324.35.0-rc.1"

let version = "3.35.0-rc.1"
let mapGptVersion = "3.35.0-rc.1"

let binaries = [
  "MapboxCoreMaps": "e08061c60f9f3dee108bfb676298adf0d59d9b85ea4319a8e043147d529b98ce",
  "MapboxDirections": "1f00804cbcf7b6b7d39f018508a572d587885212a3c102ebccc5f280c5598550",
  "MapboxMaps": "9964a817e0ccabec5401c01d009f9598c07fbe4e00e3e5cf0dfebfb12253b8df",
  "MapboxNavigationCore": "3e85687ea6dc19a5396a27a9cd2abb7b030c6191ac761be5eaa332f680a74751",
  "MapboxNavigationUIKit": "e0d5d1be6e5369e86b444a3d72ec22e470fa4bb8eaa889e9cb1b1abbd9aaf2ec",
  "_MapboxNavigationHelpers": "4c6c3234e82e486cbb62dc24551e108c214fd465c508bbe4d6eef296e3614326",
  "_MapboxNavigationLocalization":
    "06d8a842196ac6fc1925dd19b3bc694f05e46b7653e92fde918a507853c37a35",
]

let libraries = [
  "MapboxMapGpt": "a25e0b392803d2e437c03efbbe9b0906d7c642c5e77850aad4574d7de9bfc2cf",
  "MapboxMapGptUI": "23f3f5f194df3b4e89f030a178044f2055d177a02c34776410471abb553f49ed",
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
