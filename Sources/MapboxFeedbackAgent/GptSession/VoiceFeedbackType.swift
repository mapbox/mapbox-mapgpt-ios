import Foundation
import MapboxCoreNavigation

/// A list of feedback types provided by the MapGpt API when processing feedback.
public struct VoiceFeedbackType: FeedbackType, Equatable, Sendable, Hashable {
    /// The main telemetry identifier for any Feedback Agent report.
    public let typeKey = "voice_feedback"

    /// The subtype telemetry identifier for a specific Feedback Agent report about a particular issue.
    public let subtypeKey: String?

    init(subtypeKey: String) {
        self.subtypeKey = subtypeKey
    }

    public init?(string: String?) {
        guard let string else { return nil }
        if Self.values.contains(where: { $0.subtypeKey == string }) {
            subtypeKey = string
        } else {
            return nil
        }
    }

    /// Convert to `ActiveNavigationFeedbackType`
    var activeNavigationFeedback: ActiveNavigationFeedbackType {
        .custom(typeKey: typeKey, subtypeKey: subtypeKey)
    }

    var passiveNavigationFeedback: PassiveNavigationFeedbackType {
        .custom(type: typeKey, subtype: subtypeKey)
    }

    // MARK: -

    /// Feedback about incorrect or inefficient routes. Examples: 'Incorrect route found', 'The suggested route is
    /// unnecessarily long', 'Just before I turned off the highway, you showed a reroute through here, which I think
    /// would have been a huge detour.'",
    static let poorRoutingIssue = VoiceFeedbackType(
        subtypeKey: "poor_routing_issue"
    )
    /// Issues where the app suggests illegal turns or maneuvers. Examples: 'The route includes a turn that is
    /// prohibited', 'The app told me to make a left turn at a no-left-turn intersection.'",
    static let illegalTurn = VoiceFeedbackType(
        subtypeKey: "illegal_turn"
    )
    /// Situations where no route is generated despite valid input. Examples: 'The app fails to generate a route to my
    /// destination', 'I get an error saying no route found.'",
    static let noRoute = VoiceFeedbackType(
        subtypeKey: "no_route"
    )
    /// Feedback related to arrival instructions or final destination placement. Examples: 'The app places the
    /// destination on the wrong side of the street', 'Arrival guidance is confusing.'",
    static let poorArrivalIssue = VoiceFeedbackType(
        subtypeKey: "poor_arrival_issue"
    )
    /// Issues involving routes that suggest entering restricted areas. Examples: 'The app directed me into a private
    /// driveway', 'The route includes an entrance into a pedestrian-only zone.'",
    static let illegalEntrance = VoiceFeedbackType(
        subtypeKey: "illegal_entrance"
    )
    /// Problems with alternative routes suggested by the app. Examples: 'Alternative routes are not displayed
    /// properly', 'The app doesn't show any alternative routes even when traffic is heavy.'",
    static let alternativeRouteIssue = VoiceFeedbackType(
        subtypeKey: "alternative_route_issue"
    )
    /// Feedback about missing expected maneuvers in navigation instructions. Examples: 'The app skipped a critical turn
    /// instruction', 'No lane change guidance was provided'",
    static let missingExpectedManeuver = VoiceFeedbackType(
        subtypeKey: "missing_expected_maneuver"
    )
    /// Issues with rerouting or recalculating routes when deviating from the original path. Examples: 'Rerouting takes
    /// too long', 'The app fails to recalculate when I miss a turn.'",
    static let reroutingRecalculation = VoiceFeedbackType(
        subtypeKey: "rerouting_recalculation"
    )
    /// General problems with navigation guidance provided by the app. Examples: 'Turn instructions are given too
    /// late.'",
    static let guidanceIssue = VoiceFeedbackType(
        subtypeKey: "guidance_issue"
    )
    /// Problems with navigation banners or on-screen instructions during routing. Examples: 'Banner directions are
    /// incorrect', 'Street names are missing from banners.'",
    static let bannerIssue = VoiceFeedbackType(
        subtypeKey: "banner_issue"
    )
    /// Issues specifically related to voice guidance during navigation. Examples: 'Voice guidance volume is too low',
    /// 'Instructions are incomplete in voice guidance.'",
    static let voiceGuidanceIssue = VoiceFeedbackType(
        subtypeKey: "voice_guidance_issue"
    )
    /// Feedback specifically around lane guidance or details about the road as displayed on the map.. Examples: 'Lane
    /// guidance is inaccurate', 'No lane information is provided for highway exits.'",
    static let laneGuidanceIssue = VoiceFeedbackType(
        subtypeKey: "lane_guidance_issue"
    )
    /// Problems with speed limit data or display in the application. Examples: 'Speed limits are outdated', 'Incorrect
    /// speed limit displayed for this road.'",
    static let speedLimitIssue = VoiceFeedbackType(
        subtypeKey: "speed_limit_issue"
    )
    /// Feedback about road closures not accounted for in routing or map data. Examples: 'The route includes a closed
    /// road', 'Road closures are not updated in real-time.'",
    static let roadClosureIssue = VoiceFeedbackType(
        subtypeKey: "road_closure_issue"
    )
    /// Missing points of interest (POI) in map data or search results. Examples: 'This restaurant is not listed on the
    /// map', 'There are no parking lots displayed in this region.'",
    static let poiMissing = VoiceFeedbackType(
        subtypeKey: "poi_missing"
    )
    /// Feedback about POIs marked as open but actually closed in reality. Examples: 'This store is permanently closed,
    /// but it still shows as open on the map.'",
    static let poiClosed = VoiceFeedbackType(
        subtypeKey: "poi_closed"
    )
    /// Issues with inaccurate or incomplete POI details such as name, address, or hours of operation. Examples: 'The
    /// restaurant's hours of operation are incorrect', 'POI details are outdated.'",
    static let poiDetails = VoiceFeedbackType(
        subtypeKey: "poi_details"
    )
    /// Problems with POI locations being inaccurate on the map. Examples: 'This gas station's location is misplaced on
    /// the map', 'POI appears far from its actual location.'",
    static let poiLocation = VoiceFeedbackType(
        subtypeKey: "poi_location"
    )
    /// General issues with underlying map data accuracy or completeness. Examples: 'Street names are incorrect', 'Road
    /// geometry is wrong in this area.'",
    static let mapDataIssue = VoiceFeedbackType(
        subtypeKey: "map_data_issue"
    )
    /// Problems with how maps are visually displayed or rendered in the application interface. Examples: 'Map tiles
    /// fail to load properly', 'Map rendering is slow and laggy.'",
    static let mapRenderingIssue = VoiceFeedbackType(
        subtypeKey: "map_rendering_issue"
    )
    /// Feedback about road incidents not accurately reflected in routing or map data (e.g., constructions, accidents,
    /// hazards). Examples: 'Accidents are not shown on this road', 'Road hazard information is missing.', 'There's no
    /// construction on this road right now.'",
    static let roadIncidentIssue = VoiceFeedbackType(
        subtypeKey: "road_incident_issue"
    )
    /// Issues related to traffic conditions or traffic data accuracy displayed on maps and routing decisions. Examples:
    /// 'Traffic information does not match real-time conditions.', 'Traffic congestion is not displayed for this
    /// area.', 'the traffic coloring is not correct'",
    static let trafficIssue = VoiceFeedbackType(
        subtypeKey: "traffic_issue"
    )
    /// False negative traffic issue when a user reports traffic congestion or delays (e.g., being stuck or seeing
    /// traffic build up). Examples: 'There's false negative traffic on this road at my location', 'Now there's
    /// congestion starting here.'",
    static let falseNegativeTrafficIssue = VoiceFeedbackType(
        subtypeKey: "false_negative_traffic_issue"
    )
    /// False positive traffic issue when a user reports traffic is flowing smoothly and there's no congestion.
    /// Examples: 'There's false positive traffic coloring on this exit ramp; it should just be green.', 'There is no
    /// traffic congestion here'",
    static let falsePositiveTrafficIssue = VoiceFeedbackType(
        subtypeKey: "false_positive_traffic_issue"
    )
    /// Concerns about estimated time of arrival (ETA) accuracy or calculation logic within the app's routing system.
    /// Examples: 'ETA does not account for current traffic', 'ETA predictions are consistently wrong.'",
    static let etaIssue = VoiceFeedbackType(
        subtypeKey: "eta_issue"
    )
    /// Problems with GPS positioning, including location accuracy and tracking errors. Examples: 'My location jumps
    /// around on the map', 'GPS tracking fails intermittently.'",
    static let positioningIssue = VoiceFeedbackType(
        subtypeKey: "positioning_issue"
    )
    /// General issues with application performance, bugs, or errors unrelated to specific navigation features.
    /// Examples: 'App crashes frequently', 'Search functionality does not work.', 'I keep getting error messages when
    /// trying to load the map.', 'Why did you stop navigation?'",
    static let applicationIssue = VoiceFeedbackType(
        subtypeKey: "application_issue"
    )
    /// Irrelevant or nonsensical feedback that does not pertain to application functionality or navigation issues.
    /// Examples: 'Blue monkeys drive fast under the orange moon of Jupiter!', 'This sucks big time.', 'More feedback
    /// for you.'",
    static let nonFeedback = VoiceFeedbackType(
        subtypeKey: "non_feedback"
    )

    private static let values: [Self] = [
        .poorRoutingIssue,
        .illegalTurn,
        .noRoute,
        .poorArrivalIssue,
        .illegalEntrance,
        .alternativeRouteIssue,
        .missingExpectedManeuver,
        .reroutingRecalculation,
        .guidanceIssue,
        .bannerIssue,
        .voiceGuidanceIssue,
        .laneGuidanceIssue,
        .speedLimitIssue,
        .roadClosureIssue,
        .poiMissing,
        .poiClosed,
        .poiDetails,
        .poiLocation,
        .mapDataIssue,
        .mapRenderingIssue,
        .roadIncidentIssue,
        .trafficIssue,
        .falseNegativeTrafficIssue,
        .falsePositiveTrafficIssue,
        .etaIssue,
        .positioningIssue,
        .applicationIssue,
        .nonFeedback,
    ]
}
