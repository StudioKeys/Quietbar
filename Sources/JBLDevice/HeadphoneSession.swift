import JBLProtocol
import os

public typealias Sleeper = @Sendable (Duration) async throws -> Void

public actor HeadphoneSession {
    private static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "HeadphoneSession")

    public nonisolated let snapshots: AsyncStream<SessionSnapshot>
    private let continuation: AsyncStream<SessionSnapshot>.Continuation
    private let transport: any HeadphoneTransport
    private let replyTimeout: Duration
    private let sleep: Sleeper
    private var snapshot = SessionSnapshot.initial
    private var listener: Task<Void, Never>?

    public init(
        transport: any HeadphoneTransport,
        replyTimeout: Duration = .seconds(3),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) }
    ) {
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(16))
        self.transport = transport
        self.replyTimeout = replyTimeout
        self.sleep = sleep
    }

    public func start() async {
        startListening()
        await connect()
    }

    public func refresh() async {
        for command in Command.refreshAll {
            await send(command)
        }
    }

    private func connect() async {
        publish(snapshot.with(status: .searching))
        do {
            try await transport.connect()
            publish(snapshot.with(status: .connected))
            await refresh()
        } catch {
            Self.logger.error("Connect failed: \(String(describing: error), privacy: .public)")
            publish(snapshot.with(status: .retrying(after: .zero, phoneHint: true)))
        }
    }

    private func send(_ command: Command) async {
        do {
            try await transport.send(command.frame)
        } catch {
            Self.logger.error("Send \(String(describing: command), privacy: .public) failed: \(error)")
        }
    }

    private func startListening() {
        guard listener == nil else { return }
        let incoming = transport.incoming
        listener = Task { [weak self] in
            for await frame in incoming {
                await self?.receive(frame)
            }
        }
    }

    private func receive(_ frame: Frame) {
        let updated = snapshot.state.applying(Reply(frame: frame))
        guard updated != snapshot.state else { return }
        publish(snapshot.with(state: updated))
    }

    private func publish(_ next: SessionSnapshot) {
        snapshot = next
        continuation.yield(next)
    }
}
