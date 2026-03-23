import MapKit

public struct Context: Equatable, CustomDebugStringConvertible, Sendable {
    public var location: CLLocation?

    public init(
        location: CLLocation? = nil
    ) {
        self.location = location
    }

    /// All values must be String type for the API.
    var dictionary: [String: String] {
        guard let location else { return [:] }

        var context = [
            "lat": String(location.coordinate.latitude),
            "lon": String(location.coordinate.longitude),
        ]
        if location.course >= 0 {
            context["heading"] = String(location.course)
        }
        return context
    }

    public var debugDescription: String {
        var debug = dictionary
        debug["lastRefreshDate"] = location?.timestamp.description
        return debug.compactMapValues { $0 }.debugDescription
    }
}
