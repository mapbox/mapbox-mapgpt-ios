import Foundation

@_spi(ExperimentalMapboxAPI)
public typealias GptError = FeedbackAgentSession.GptError

public extension FeedbackAgentSession {
    /// Errors that could occur when using ``FeedbackAgentSession``.
    struct GptError: Error {
        static let missingLocationContext = GptError("Cannot proceed without location context.")

        static let connectionTimeout = GptError("Connection to MapGpt session timed out.")

        static let asrTimeout = GptError("Connection to ASR (Automatic Speech Recognition) timed out.")

        static let notGrantedMicrophonePermission = GptError("Microphone permission not granted.")

        static let feedbackError = GptError("Failed to process feedback event.")

        public var localizedDescription: String

        init(_ localizedDescription: String) {
            self.localizedDescription = localizedDescription
        }
    }
}
