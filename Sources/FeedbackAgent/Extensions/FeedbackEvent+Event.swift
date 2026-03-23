import MapboxCommon
@_implementationOnly import MapboxCommon_Private
import MapboxCoreNavigation

extension FeedbackEvent {
    func toEvent(with voiceFeedbackItem: VoiceFeedbackItem) -> Event {
        var attributes = contents
        attributes["feedbackId"] = voiceFeedbackItem.id.uuidString
        attributes["feedbackType"] = voiceFeedbackItem.feedbackType.typeKey
        attributes["feedbackSubtype"] = [voiceFeedbackItem.feedbackType.subtypeKey]
        attributes["description"] = voiceFeedbackItem.description
        return Event(
            priority: .immediate,
            attributes: attributes,
            deferredOptions: nil
        )
    }
}
