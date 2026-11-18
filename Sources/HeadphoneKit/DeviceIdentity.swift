import Foundation

public struct DeviceIdentity: Codable, Hashable, Sendable {
    public let name: String
    public let linkID: String
    public let classicAddress: String?

    public init(name: String, linkID: String, classicAddress: String?) {
        self.name = name
        self.linkID = linkID
        self.classicAddress = classicAddress
    }

    public var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    public static func decode(_ text: String) -> DeviceIdentity? {
        try? JSONDecoder().decode(DeviceIdentity.self, from: Data(text.utf8))
    }

    func with(classicAddress: String?) -> DeviceIdentity {
        DeviceIdentity(name: name, linkID: linkID, classicAddress: classicAddress)
    }
}
