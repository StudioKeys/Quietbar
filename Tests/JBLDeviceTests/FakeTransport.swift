import JBLDevice
import JBLProtocol

actor FakeTransport: HeadphoneTransport {
    nonisolated let incoming: AsyncStream<Frame>
    nonisolated let events: AsyncStream<LinkEvent>
    private let incomingContinuation: AsyncStream<Frame>.Continuation
    private let eventsContinuation: AsyncStream<LinkEvent>.Continuation
    private var responses: [Frame: [Frame]]
    private var remainingConnectFailures: Int
    private let connectFailure: TransportError
    private(set) var sent: [Frame] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var isConnected = false

    init(
        responses: [Command: [Frame]] = [:],
        connectFailures: Int = 0,
        connectFailure: TransportError = .connectFailed
    ) {
        (incoming, incomingContinuation) = AsyncStream.makeStream()
        (events, eventsContinuation) = AsyncStream.makeStream()
        self.responses = Dictionary(uniqueKeysWithValues: responses.map { ($0.key.frame, $0.value) })
        self.remainingConnectFailures = connectFailures
        self.connectFailure = connectFailure
    }

    func connect() async throws(TransportError) {
        connectCount += 1
        guard remainingConnectFailures == 0 else {
            remainingConnectFailures -= 1
            throw connectFailure
        }
        isConnected = true
    }

    func disconnect() async {
        disconnectCount += 1
        isConnected = false
    }

    func send(_ frame: Frame) async throws(TransportError) {
        guard isConnected else { throw .notConnected }
        sent.append(frame)
        for response in responses[frame, default: []] {
            incomingContinuation.yield(response)
        }
    }

    func respond(to command: Command, with frames: [Frame]) {
        responses[command.frame] = frames
    }

    func emit(_ frame: Frame) {
        incomingContinuation.yield(frame)
    }

    func emit(_ event: LinkEvent) {
        if event == .disconnected { isConnected = false }
        eventsContinuation.yield(event)
    }
}
