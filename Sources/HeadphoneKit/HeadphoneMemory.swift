struct HeadphoneMemory {
    private(set) var identity: DeviceIdentity?
    private let nameFragment: String
    private var pendingClassic: ClassicConnection?

    init(identity: DeviceIdentity?, nameFragment: String) {
        self.identity = identity
        self.nameFragment = nameFragment
    }

    var displayName: String? { identity?.displayName }

    func isOurs(_ connection: ClassicConnection) -> Bool {
        if let address = identity?.classicAddress {
            return address == connection.address
        }
        return connection.name.localizedCaseInsensitiveContains(nameFragment)
    }

    mutating func noteClassic(_ connection: ClassicConnection) {
        guard isOurs(connection) else { return }
        if let identity {
            self.identity = identity.with(classic: connection)
        } else {
            pendingClassic = connection
        }
    }

    mutating func connected(as link: DeviceIdentity) {
        let learned =
            identity.map {
                DeviceIdentity(
                    name: link.name, linkID: link.linkID, classicAddress: $0.classicAddress, classicName: $0.classicName
                )
            } ?? link
        identity = learned.with(classic: pendingClassic)
        pendingClassic = nil
    }
}
