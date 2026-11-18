public struct ClassicConnection: Hashable, Sendable {
    public let name: String
    public let address: String

    public init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}

public protocol ConnectionWatcher: Sendable {
    var connections: AsyncStream<ClassicConnection> { get }
}
