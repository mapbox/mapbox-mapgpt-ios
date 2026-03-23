import AVFoundation
@preconcurrency import MapboxCommonGpt

public extension MapgptSessionOptions {
    /// Recommended session configuration values for using ``FeedbackAgentSession`` for voice-based Feedback Agent.
    static let feedbackASR = MapgptSessionOptions(
        token: TokenProvider.obtainAccessToken(),
        uuid: nil,
        mode: .online,
        type: .ASR,
        profile: "feedback",
        pingTimeout: 30,
        sampleRate: UInt32(AVAudioSession.sharedInstance().sampleRate),
        language: .english,
        reconnect: false,
        endpoint: nil
    )
}
