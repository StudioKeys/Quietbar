import JBLProtocol
import Testing

@testable import JBLDevice

struct ReplyWaitersTests {
    @Test func deliveryBeforeWaitMarksTicketFulfilled() {
        var waiters = ReplyWaiters()
        let ticket = waiters.expect(.eq)

        let resumed = waiters.deliver(.eq)

        let wasFulfilled = waiters.consumeFulfilled(ticket)

        #expect(resumed.isEmpty)
        #expect(wasFulfilled)
    }

    @Test func deliveryOfOtherKindLeavesTicketPending() {
        var waiters = ReplyWaiters()
        let ticket = waiters.expect(.eq)

        _ = waiters.deliver(.battery)
        let wasFulfilled = waiters.consumeFulfilled(ticket)

        #expect(!wasFulfilled)
        #expect(waiters.isPending(ticket))
    }

    @Test func expiringRemovesTicket() {
        var waiters = ReplyWaiters()
        let ticket = waiters.expect(.spatial)

        _ = waiters.expire(ticket)

        #expect(!waiters.isPending(ticket))
    }
}
