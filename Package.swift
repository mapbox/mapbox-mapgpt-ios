// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.36.0-rc.1"
let navNativeVersion: Version = "324.36.0-rc.1"

let version = "3.36.0-rc.1"
let mapGptVersion = "3.36.0-rc.1"

let binaries = [
  "MapboxCoreMaps": "69c322c29e90f97eb0acd7b09231dff1c4838924de28d537ee3881fffff44573",
  "MapboxDirections": "baf8aa5911768fc4e2b91b9b991f215a48a54d0c794cfb57dd5e70498922191d",
  "MapboxMaps": "cc4608cdd8809b266704b751c4ee98101a523db1ff6e5683da9e95893e30e4ea",
  "MapboxNavigationCore": "8e2fdf5b2ec3947bacb6ed567ac313ba214ef1b574a9e808a3a9f7cfb7f44406",
  "MapboxNavigationUIKit": "77b88433962e13fa14a106167d2cfd9be8b58b221204ea2725b43bad4557d054",
  "_MapboxNavigationHelpers": "578cec3c2cfa1d3f622056c7de5b8cbe76bdb612ee1940f01fbb7b690fdb3c06",
  "_MapboxNavigationLocalization":
    "0a30baa95f5a84e64f700fe8c9c9eb7e2f6dc97f1f836c2f5a656d7950170c23",
]

let libraries = [
  "MapboxMapGpt": "06175a6aa984dfd9009a65123f3550776e2bf38727c2af5e9cd10fd255f90774",
  "MapboxMapGptUI": "71ae0291bc3e5b641546f9d7dc472cd58aed24d9cc0bcd2dd171e38f01888968",
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
