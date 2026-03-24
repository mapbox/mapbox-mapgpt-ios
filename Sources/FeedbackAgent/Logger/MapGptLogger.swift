import Foundation
@_spi(MapboxInternal) import MapboxCommon_Private.MBXLog_Internal
import OSLog

@_spi(MapboxInternal)
public typealias Log = MapGptLog

@_spi(MapboxInternal)
public enum MapGptLog {
    public typealias Category = MapGptLogCategory
    private typealias Logger = MapboxCommon_Private.Log

    public static var logLevel: LoggingLevel = .warning {
        didSet {
            let logLevel = NSNumber(value: logLevel.rawValue)
            for category in MapGptLogCategory.allCases {
                LogConfiguration.setLoggingLevelForCategory(category.rawLogCategory, upTo: logLevel)
            }
            LogConfiguration.setLoggingLevelForUpTo(logLevel)
        }
    }

    public static func debug(_ message: String, category: Category) {
        Logger.debug(forMessage: message, category: category.rawLogCategory)
    }

    public static func info(_ message: String, category: Category) {
        Logger.info(forMessage: message, category: category.rawLogCategory)
    }

    public static func warning(_ message: String, category: Category) {
        Logger.warning(forMessage: message, category: category.rawLogCategory)
    }

    public static func error(_ message: String, category: Category) {
        Logger.error(forMessage: message, category: category.rawLogCategory)
    }

    public static func fault(_ message: String, category: Category) {
        let faultLog: OSLog = .init(subsystem: "com.mapbox.mapgpt", category: category.rawValue)
        os_log("%{public}@", log: faultLog, type: .fault, message)
        Logger.error(forMessage: message, category: category.rawLogCategory)
    }

    @available(*, unavailable, message: "Use MapGptLog.debug(_:category:)")
    public static func trace(_: String) {}
}

@_spi(MapboxInternal)
public struct MapGptLogCategory: CaseIterable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let session: Self = .init(rawValue: "session")
    public static let audio: Self = .init(rawValue: "audio")
    public static let feedback: Self = .init(rawValue: "feedback")
    public static let telemetry: Self = .init(rawValue: "telemetry")

    public static var allCases: [MapGptLogCategory] = [.session, .audio, .feedback]

    public var rawLogCategory: String {
        "feedback-agent-ios/\(rawValue)"
    }
}
