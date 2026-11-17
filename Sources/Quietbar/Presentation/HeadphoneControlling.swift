import JBLDevice
import JBLProtocol

protocol HeadphoneControlling: Sendable {
    var snapshots: AsyncStream<SessionSnapshot> { get }
    func apply(_ command: Command) async throws(ApplyError)
    func refresh() async
    func userConnect() async
    func userDisconnect() async
}

extension HeadphoneSession: HeadphoneControlling {}
