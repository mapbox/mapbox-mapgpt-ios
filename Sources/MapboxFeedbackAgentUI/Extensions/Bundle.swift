import Foundation
import UIKit

private final class BundleToken {}

public extension Bundle {
    #if !SWIFT_PACKAGE
        private static let module: Bundle = .init(for: BundleToken.self)
    #endif

    /// The Mapbox Core Navigation framework bundle.
    static let feedbackAgentUI: Bundle = .module

    /// Provides `Bundle` instance, based on provided bundle name and class inside of it.
    /// - Parameters:
    ///   - bundleName: Name of the bundle.
    ///   - class:  Class, which is located inside of the bundle.
    /// - Returns: Instance of the bundle if it was found, otherwise `nil`.
    internal static func bundle(for bundleName: String, class: AnyClass) -> Bundle? {
        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: `class`).resourceURL,
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }

        return nil
    }

    func image(named: String) -> UIImage? {
        guard let image = UIImage(named: named, in: self, compatibleWith: nil) else {
            assertionFailure("Image \(named) wasn't found in Core Framework bundle")
            return nil
        }
        return image
    }
}
