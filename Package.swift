// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quietbar",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "JBLProtocol"),
        .target(name: "JBLDevice", dependencies: ["JBLProtocol"]),
        .target(name: "JBLBluetooth", dependencies: ["JBLDevice", "JBLProtocol"]),
        .executableTarget(name: "Quietbar", dependencies: ["JBLBluetooth", "JBLDevice", "JBLProtocol"]),
        .testTarget(name: "JBLProtocolTests", dependencies: ["JBLProtocol"]),
        .testTarget(name: "JBLDeviceTests", dependencies: ["JBLDevice", "JBLProtocol"]),
        .testTarget(name: "QuietbarTests", dependencies: ["Quietbar", "JBLDevice", "JBLProtocol"]),
    ],
    swiftLanguageModes: [.v6]
)
