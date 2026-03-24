import Combine
import Foundation
@_implementationOnly import MapboxCommon_Private
import MapboxNavigationNative

final class EventsAPIProvider {
    let eventsAPI: EventsService

    init() {
        let accessToken = TokenProvider.obtainAccessToken()
        let userAgent =
            Navigator.getUserAgentFragment()
                + "_" + "mapbox-feedback-agent-ios/\(Bundle.mapboxFeedbackAgentSDKVersion)"

        let options = EventsServerOptions(
            token: accessToken,
            userAgentFragment: userAgent,
            deferredDeliveryServiceOptions: nil
        )
        eventsAPI = EventsService.getOrCreate(for: options)
    }
}
