import Foundation

/// Encapsulate the results of ASR (automatic speech recognition) feedback.
public struct VoiceFeedbackItem: Identifiable, Equatable, Sendable, Hashable {
    public let id = UUID()

    /// The ASR text of the user's report
    public let description: String

    public let feedbackType: VoiceFeedbackType
}
