import Foundation

struct ReplyWaiters<Key: Hashable> {
    typealias Ticket = UUID

    private var pending: [Ticket: Key] = [:]
    private var fulfilled: Set<Ticket> = []
    private var continuations: [Ticket: CheckedContinuation<Bool, Never>] = [:]

    mutating func expect(_ kind: Key) -> Ticket {
        let ticket = Ticket()
        pending[ticket] = kind
        return ticket
    }

    func isPending(_ ticket: Ticket) -> Bool {
        pending[ticket] != nil
    }

    mutating func consumeFulfilled(_ ticket: Ticket) -> Bool {
        fulfilled.remove(ticket) != nil
    }

    mutating func park(_ ticket: Ticket, _ continuation: CheckedContinuation<Bool, Never>) {
        continuations[ticket] = continuation
    }

    mutating func deliver(_ kind: Key) -> [CheckedContinuation<Bool, Never>] {
        let matching = pending.filter { $0.value == kind }.map(\.key)
        return matching.compactMap { ticket in
            pending[ticket] = nil
            guard let continuation = continuations.removeValue(forKey: ticket) else {
                fulfilled.insert(ticket)
                return nil
            }
            return continuation
        }
    }

    mutating func expire(_ ticket: Ticket) -> CheckedContinuation<Bool, Never>? {
        pending[ticket] = nil
        fulfilled.remove(ticket)
        return continuations.removeValue(forKey: ticket)
    }
}
