import HeadphoneKit

protocol HeadphoneControlling: Sendable {
    var snapshots: AsyncStream<DeviceSnapshot> { get }
    func start() async
    func stop() async
    func apply(_ change: SettingChange) async throws(ApplyError)
    func refresh() async
    func userConnect() async
    func userDisconnect() async
}

extension DeviceSession: HeadphoneControlling {}
