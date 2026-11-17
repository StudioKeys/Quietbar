public struct ReconnectPolicy: Sendable {
    public static let standard = ReconnectPolicy(
        delays: [.seconds(1), .seconds(2), .seconds(5), .seconds(10), .seconds(30)]
    )

    private let delays: [Duration]

    public init(delays: [Duration]) {
        precondition(!delays.isEmpty, "A reconnect policy needs at least one delay")
        self.delays = delays
    }

    public func delay(afterFailures count: Int) -> Duration {
        delays[min(max(count, 1), delays.count) - 1]
    }
}
