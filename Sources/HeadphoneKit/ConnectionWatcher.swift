public protocol ConnectionWatcher: Sendable {
    var connections: AsyncStream<String> { get }
}
