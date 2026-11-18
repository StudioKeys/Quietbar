import HeadphoneKit

struct FakeConnectionWatcher: ConnectionWatcher {
    let connections: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init() {
        (connections, continuation) = AsyncStream.makeStream()
    }

    func emit(_ name: String) {
        continuation.yield(name)
    }
}
