public struct ReconnectPolicy: Sendable {
    public static let standard = ReconnectPolicy(
        delays: [.seconds(1), .seconds(2), .seconds(5), .seconds(10)],
        maxAttempts: 5
    )

    public let maxAttempts: Int
    private let delays: [Duration]

    public init(delays: [Duration], maxAttempts: Int) {
        precondition(!delays.isEmpty, "A reconnect policy needs at least one delay")
        precondition(maxAttempts > 0, "A reconnect policy needs at least one attempt")
        precondition(delays.count >= maxAttempts - 1, "Every retry needs its own delay")
        self.delays = delays
        self.maxAttempts = maxAttempts
    }

    public func delay(afterFailures count: Int) -> Duration {
        delays[min(max(count, 1), delays.count) - 1]
    }
}
