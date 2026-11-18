// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quietbar",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "JBLProtocol"),
        .target(name: "MotoProtocol", dependencies: ["HeadphoneKit"]),
        .target(name: "HeadphoneKit"),
        .target(name: "JBLDriver", dependencies: ["JBLProtocol", "HeadphoneKit"]),
        .target(name: "MotoDriver", dependencies: ["MotoProtocol", "HeadphoneKit"]),
        .target(name: "BluetoothLE", dependencies: ["HeadphoneKit"]),
        .target(
            name: "ClassicBluetooth",
            dependencies: ["HeadphoneKit"],
            linkerSettings: [.linkedFramework("IOBluetooth")]
        ),
        .executableTarget(
            name: "Quietbar",
            dependencies: ["BluetoothLE", "ClassicBluetooth", "HeadphoneKit", "JBLDriver", "MotoDriver"]
        ),
        .testTarget(name: "JBLProtocolTests", dependencies: ["JBLProtocol"]),
        .testTarget(name: "MotoProtocolTests", dependencies: ["MotoProtocol"]),
        .testTarget(name: "MotoDriverTests", dependencies: ["MotoDriver", "MotoProtocol", "HeadphoneKit"]),
        .testTarget(name: "HeadphoneKitTests", dependencies: ["HeadphoneKit"]),
        .testTarget(name: "JBLDriverTests", dependencies: ["JBLDriver", "JBLProtocol", "HeadphoneKit"]),
        .testTarget(name: "QuietbarTests", dependencies: ["Quietbar", "HeadphoneKit"]),
    ],
    swiftLanguageModes: [.v6]
)
