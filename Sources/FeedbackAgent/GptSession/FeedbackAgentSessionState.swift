import Foundation

/// FeedbackAgentSessionState conveys the current state of the session.
/// Certain operations are limited to specific states.
public enum FeedbackAgentSessionState {
    case disconnected
    case connecting
    case connected
    case requestingMicrophonePermission
    case startingMicrophone
    case recording
    case submittingRecording
    case completed(Result<VoiceFeedbackItem, Error>)
}

extension FeedbackAgentSessionState: Equatable {
    public static func == (lhs: FeedbackAgentSessionState, rhs: FeedbackAgentSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            true
        case (.connecting, .connecting):
            true
        case (.connected, .connected):
            true
        case (.requestingMicrophonePermission, .requestingMicrophonePermission):
            true
        case (.startingMicrophone, .startingMicrophone):
            true
        case (.recording, .recording):
            true
        case (.submittingRecording, .submittingRecording):
            true
        case let (.completed(lhResult), .completed(rhResult)):
            switch (lhResult, rhResult) {
            case let (.success(leftItem), .success(rightItem)):
                leftItem == rightItem
            case (.failure, .failure):
                false
            default:
                false
            }
        default:
            false
        }
    }
}

extension FeedbackAgentSessionState: Hashable {
    // TODO: Validate with unit test
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .disconnected:
            hasher.combine(".disconnected")
        case .connecting:
            hasher.combine(".connecting")
        case .connected:
            hasher.combine(".connected")
        case .requestingMicrophonePermission:
            hasher.combine(".requestingMicrophonePermission")
        case .startingMicrophone:
            hasher.combine(".startingMicrophone")
        case .recording:
            hasher.combine(".recording")
        case .submittingRecording:
            hasher.combine(".submittingRecording")
        case let .completed(result):
            switch result {
            case let .success(success):
                hasher.combine(success)
            case let .failure(failure):
                hasher.combine(failure.localizedDescription)
            }
        }
    }
}

public extension FeedbackAgentSessionState {
    /// String suitable for displaying in the user-interface to convey the session state.
    var display: String {
        switch self {
        case .disconnected:
            "Disconnected"
        case .connecting:
            "Connecting"
        case .connected:
            "Connected"
        case .requestingMicrophonePermission:
            "Requesting permission to record the microphone"
        case .startingMicrophone:
            "Starting microphone"
        case .recording:
            "Recording"
        case .submittingRecording:
            "Submitting Recording"
        case let .completed(result):
            switch result {
            case let .success(item):
                "Successfully Submitted \(item.id)"
            case let .failure(failure):
                "Failed to submit, \(failure.localizedDescription)"
            }
        }
    }
}
