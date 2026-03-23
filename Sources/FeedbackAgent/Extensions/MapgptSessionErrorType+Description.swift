import MapboxCommonGpt

extension MapgptSessionErrorType: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .alreadyConnectedError:
            "Already Connected Error"
        case .httpError:
            "HTTP Error"
        case .invalidResponseError:
            "Invalid Response Error"
        case .notConnectedError:
            "Not Connected Error"
        case .otherError:
            "Other Error"
        case .wrongSessionTypeError:
            "Wrong Session Type Error"
        case .wssError:
            "WSS Error"
        @unknown default:
            "Unknown error type"
        }
    }
}
