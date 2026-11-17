// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quietbar",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "JBLProtocol"),
        .target(name: "HeadphoneKit", dependencies: ["JBLProtocol"]),
        .target(name: "JBLBluetooth", dependencies: ["HeadphoneKit", "JBLProtocol"]),
        .executableTarget(name: "Quietbar", dependencies: ["JBLBluetooth", "HeadphoneKit", "JBLProtocol"]),
        .testTarget(name: "JBLProtocolTests", dependencies: ["JBLProtocol"]),
        .testTarget(name: "HeadphoneKitTests", dependencies: ["HeadphoneKit", "JBLProtocol"]),
        .testTarget(name: "QuietbarTests", dependencies: ["Quietbar", "HeadphoneKit", "JBLProtocol"]),
    ],
    swiftLanguageModes: [.v6]
)
