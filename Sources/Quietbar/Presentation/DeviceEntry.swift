import HeadphoneKit

struct DeviceEntry: Identifiable, Sendable {
    let id: String
    let model: DeviceModel
    let makeController: @Sendable (_ connectionPreferenceKey: String) -> any HeadphoneControlling

    var name: String { model.name }
    var connectionPreferenceKey: String { "\(DeviceSession.wantsConnectionKey).\(id)" }
}
