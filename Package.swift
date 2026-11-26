// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonVersion: Version = "24.36.0"
let navNativeVersion: Version = "324.36.0"

let version = "3.36.0"
let mapGptVersion = "3.36.0"

let binaries = [
  "MapboxCoreMaps": "36d88e69efddebd7dce84499f5c1e3ff2b555062abe859d76b33b536c55cf8ce",
  "MapboxDirections": "083e3eef2465bace08e319db6ff0827ee121882d5513d80be9a7e14ad86e61f0",
  "MapboxMaps": "48ce247ed66948d33ccc425df792f124425cef886508ea19060a011e59493efd",
  "MapboxNavigationCore": "fb5c35d537216a43490284c9a9bca0203efd1d619aeb070c20f8ac3f1f19e74d",
  "MapboxNavigationUIKit": "e3e254224cbb91985995e60610f6349094ef61ad8f2264b976c861055d3305d4",
  "_MapboxNavigationHelpers": "b66f625ec1ece486cad6b43c2565037193ceca073c997ef93e2ff997761504c3",
  "_MapboxNavigationLocalization":
    "822a101f1e2dcc7692de681811239df4acf7cd53cacec974380a4537ba28c19d",
]

let libraries = [
  "MapboxMapGpt": "df42897b31a3a2f342de543d7b25187ac0d660b9d595b493b880b3b86853ef5c",
  "MapboxMapGptUI": "a34ec260534b39adb55e1c6414d93ebf911dc885eabaf604001de2d5610961ef",
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
