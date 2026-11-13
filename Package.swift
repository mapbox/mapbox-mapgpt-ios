// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.35.0"
let navNativeVersion: Version = "324.35.0"

let version = "3.35.0"
let mapGptVersion = "3.35.0"

let binaries = [
  "MapboxCoreMaps": "36426723df027e6e9c88c749a7847895c33b2edec5d8f88c73e10f5b717c8065",
  "MapboxDirections": "ad9cf6548fcab65535cfa48994d509aa82831ab15b8a2fadef4c86d9bc6d66b5",
  "MapboxMaps": "6a0b6de2be96031b2533e1268ca1c9b4d3e8f1544c2e939488773c5907c76d70",
  "MapboxNavigationCore": "3b08122023b9d6e2da3f05a8e0d1a8f70f095ac710bb393b0ce60827bd233a34",
  "MapboxNavigationUIKit": "33fd57393ae7aa61c69d862fca3071b7678128e751f713e365c75bd338292467",
  "_MapboxNavigationHelpers": "e7e30778db86d3406ace27b09716ef6be33310796695c240a61abb2e45a87397",
  "_MapboxNavigationLocalization":
    "c9f4a26562e012671b1fceb607011e05de7ffaa1036bb9f9edc64b2c47600e23",
]

let libraries = [
  "MapboxMapGpt": "2cba3f75dabd18e587a5a3aadab9bb9360cd1cfbad46a7cb8a0c2575dd89af6a",
  "MapboxMapGptUI": "70cb23f3d8d24c9f256500b2d0286d14e51726f143b40ffda95107e15c2c3fe5",
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
