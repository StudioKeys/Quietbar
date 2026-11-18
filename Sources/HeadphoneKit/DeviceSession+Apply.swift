import Foundation

extension DeviceSession {
    public func apply(_ change: SettingChange) async throws(ApplyError) {
        guard snapshot.status == .connected else { throw .notConnected }
        do throws(ApplyError) {
            guard let requests = driver.requests(for: change, current: snapshot.state) else {
                throw ApplyError.unsupported
            }
            if appliesWithReconnect(change.id) {
                try await sendAll(requests)
            } else {
                try await confirmWithFollowUp(requests, setting: change.id)
            }
            publish(snapshot.with(lastError: nil))
        } catch {
            Self.logger.notice(
                "\(change.id.rawValue, privacy: .public) not confirmed: \(error.message, privacy: .public)")
            publish(snapshot.with(lastError: error.message))
            throw error
        }
    }

    func appliesWithReconnect(_ id: SettingID) -> Bool {
        driver.model.settings.first { $0.id == id }?.appliesWithReconnect ?? false
    }

    func sendAll(_ requests: [Data]) async throws(ApplyError) {
        do {
            for request in requests {
                try await transport.send(request)
            }
        } catch {
            throw .writeFailed
        }
    }

    func confirmWithFollowUp(_ requests: [Data], setting: SettingID) async throws(ApplyError) {
        do {
            try await confirm(requests, setting: setting)
        } catch .timedOut {
            guard let query = driver.confirmingRequest(for: setting) else { throw .timedOut }
            try await confirm([query], setting: setting)
        }
    }

    func confirm(_ requests: [Data], setting: SettingID) async throws(ApplyError) {
        let ticket = waiters.expect(setting)
        do {
            for request in requests {
                try await transport.send(request)
            }
        } catch {
            _ = waiters.expire(ticket)
            throw .writeFailed
        }
        guard await waitForReply(ticket) else { throw .timedOut }
    }

    func waitForReply(_ ticket: ReplyWaiters<SettingID>.Ticket) async -> Bool {
        if waiters.consumeFulfilled(ticket) { return true }
        guard waiters.isPending(ticket) else { return false }
        let timeout = replyTimeout
        return await withCheckedContinuation { continuation in
            waiters.park(ticket, continuation)
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                await self?.expire(ticket)
            }
        }
    }

    func expire(_ ticket: ReplyWaiters<SettingID>.Ticket) {
        waiters.expire(ticket)?.resume(returning: false)
    }
}
