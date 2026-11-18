import Foundation
import HeadphoneKit
import Synchronization

struct WaitTimedOut: Error {}

func waitUntil(
    within timeout: Duration = .seconds(1),
    _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while await !condition() {
        guard ContinuousClock.now < deadline else { throw WaitTimedOut() }
        try await Task.sleep(for: .milliseconds(5))
    }
}

func settle() async {
    // Unstructured tasks the session spawns signal nothing, so give them a bounded chance to run.
    for _ in 0..<20 { await Task.yield() }
    try? await Task.sleep(for: .milliseconds(10))
}

final class EventFeed<Element: Sendable>: Sendable {
    private struct State {
        var pending: [Element] = []
        var consumer: CheckedContinuation<Element, Never>?
        var drainWaiters: [CheckedContinuation<Void, Never>] = []

        var isDrained: Bool { pending.isEmpty && consumer != nil }
    }

    private enum Handoff {
        case ready(Element)
        case waiting(drainWaiters: [CheckedContinuation<Void, Never>])
    }

    private let state = Mutex(State())

    var stream: AsyncStream<Element> {
        AsyncStream { await self.next() }
    }

    var isDrained: Bool { state.withLock(\.isDrained) }

    func emit(_ element: Element) {
        let consumer = state.withLock { state -> CheckedContinuation<Element, Never>? in
            defer { state.consumer = nil }
            if state.consumer == nil { state.pending.append(element) }
            return state.consumer
        }
        consumer?.resume(returning: element)
    }

    func drained() async {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            let isDrained = state.withLock { state -> Bool in
                if !state.isDrained { state.drainWaiters.append(waiter) }
                return state.isDrained
            }
            if isDrained { waiter.resume() }
        }
    }

    private func next() async -> Element {
        await withCheckedContinuation { (consumer: CheckedContinuation<Element, Never>) in
            let handoff = state.withLock { state -> Handoff in
                guard state.pending.isEmpty else { return .ready(state.pending.removeFirst()) }
                state.consumer = consumer
                defer { state.drainWaiters = [] }
                return .waiting(drainWaiters: state.drainWaiters)
            }
            switch handoff {
            case .ready(let element):
                consumer.resume(returning: element)
            case .waiting(let drainWaiters):
                for waiter in drainWaiters { waiter.resume() }
            }
        }
    }
}

actor ScriptedSleeper {
    private let immediateCount: Int
    private let blocksFrom: Duration?
    private(set) var requested: [Duration] = []

    init(immediateCount: Int = .max, blocksFrom: Duration? = nil) {
        self.immediateCount = immediateCount
        self.blocksFrom = blocksFrom
    }

    func sleep(_ duration: Duration) async throws {
        requested.append(duration)
        let alwaysBlocks = blocksFrom.map { duration >= $0 } ?? false
        guard alwaysBlocks || requested.count > immediateCount else { return }
        try await Task.sleep(for: .seconds(3600))
    }

    func requested(below limit: Duration) -> [Duration] {
        requested.filter { $0 < limit }
    }

    nonisolated var closure: Sleeper {
        { [self] duration in try await self.sleep(duration) }
    }
}
