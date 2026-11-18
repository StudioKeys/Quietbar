import Foundation

extension DeviceSession {
    func shakeHands() async -> Bool {
        let requests = driver.handshakeRequests
        guard !requests.isEmpty else { return true }
        handshakeState = .empty
        for _ in 0..<2 {
            guard !Task.isCancelled else { return false }
            for request in requests {
                await send(request)
            }
            if await waitUntilReady() { return true }
        }
        Self.logger.notice("Headphones did not answer the handshake")
        return false
    }

    func noteHandshakeProgress(_ updates: [DeviceUpdate]) {
        handshakeState = handshakeState.applying(updates)
        guard let waiter = readyWaiter, driver.isReady(handshakeState) else { return }
        readyWaiter = nil
        waiter.resume(returning: true)
    }

    private func waitUntilReady() async -> Bool {
        if driver.isReady(handshakeState) { return true }
        readyToken += 1
        let token = readyToken
        let timeout = replyTimeout
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                readyWaiter = continuation
                Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    await self?.expireReadyWaiter(token)
                }
            }
        } onCancel: {
            Task { [weak self] in await self?.expireReadyWaiter(token) }
        }
    }

    private func expireReadyWaiter(_ token: Int) {
        guard token == readyToken, let waiter = readyWaiter else { return }
        readyWaiter = nil
        waiter.resume(returning: false)
    }
}
