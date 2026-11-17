public enum ApplyError: Error, Sendable, Hashable {
    case notConnected
    case writeFailed
    case timedOut
    case unsupported

    public var message: String {
        switch self {
        case .notConnected: "Headphones aren't connected"
        case .writeFailed: "Couldn't send the change to the headphones"
        case .timedOut: "Headphones didn't confirm the change"
        case .unsupported: "These headphones don't support that setting"
        }
    }
}
