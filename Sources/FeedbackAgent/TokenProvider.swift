import Foundation

enum TokenProvider {
    static func obtainAccessToken() -> String {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String ??
            Bundle.main.object(forInfoDictionaryKey: "MGLMapboxAccessToken") as? String
        else {
            // we can assert here because if the token was passed in, it would of overridden this closure.
            // we return an empty string so we don't crash in production (in keeping with behavior of `assert`)
            assertionFailure("`accessToken` must be set in the Info.plist as `MBXAccessToken` or a custom configuration of `FeedbackAgentSessionOptions` must have the `token` property set.")
            return ""
        }
        return token
    }
}
