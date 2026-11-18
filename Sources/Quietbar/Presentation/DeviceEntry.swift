import HeadphoneKit

struct DeviceEntry: Identifiable, Sendable {
    let id: String
    let model: DeviceModel
    let makeController: @Sendable (_ deviceID: String) -> any HeadphoneControlling

    var name: String { model.name }
}
