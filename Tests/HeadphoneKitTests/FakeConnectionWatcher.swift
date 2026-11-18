import HeadphoneKit

struct FakeConnectionWatcher: ConnectionWatcher {
    private let feed = EventFeed<ClassicConnection>()

    var connections: AsyncStream<ClassicConnection> { feed.stream }

    var hasHandledAll: Bool { feed.isDrained }

    func emit(_ name: String, address: String = "00-00-00-00-00-00") {
        feed.emit(ClassicConnection(name: name, address: address))
    }
}
