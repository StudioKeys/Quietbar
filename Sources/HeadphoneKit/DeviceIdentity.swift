import Foundation

public struct DeviceIdentity: Codable, Hashable, Sendable {
    public let name: String
    public let linkID: String
    public let classicAddress: String?
    public let classicName: String?

    public init(name: String, linkID: String, classicAddress: String?, classicName: String? = nil) {
        self.name = name
        self.linkID = linkID
        self.classicAddress = classicAddress
        self.classicName = classicName
    }

    public var displayName: String { classicName ?? name }

    public var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    public static func decode(_ text: String) -> DeviceIdentity? {
        try? JSONDecoder().decode(DeviceIdentity.self, from: Data(text.utf8))
    }

    func with(classic connection: ClassicConnection?) -> DeviceIdentity {
        DeviceIdentity(
            name: name,
            linkID: linkID,
            classicAddress: connection?.address ?? classicAddress,
            classicName: connection?.name ?? classicName
        )
    }
}
