public enum ApplyError: Error, Sendable, Hashable {
    case notConnected
    case writeFailed
    case timedOut

    var message: String {
        switch self {
        case .notConnected: "Headphones aren't connected"
        case .writeFailed: "Couldn't send the change to the headphones"
        case .timedOut: "Headphones didn't confirm the change"
        }
    }
}
