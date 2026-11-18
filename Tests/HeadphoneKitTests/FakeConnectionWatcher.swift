import HeadphoneKit

struct FakeConnectionWatcher: ConnectionWatcher {
    let connections: AsyncStream<ClassicConnection>
    private let continuation: AsyncStream<ClassicConnection>.Continuation

    init() {
        (connections, continuation) = AsyncStream.makeStream()
    }

    func emit(_ name: String, address: String = "00-00-00-00-00-00") {
        continuation.yield(ClassicConnection(name: name, address: address))
    }
}
