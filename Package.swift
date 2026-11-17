// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quietbar",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "JBLProtocol"),
        .target(name: "JBLDevice", dependencies: ["JBLProtocol"]),
        .testTarget(name: "JBLProtocolTests", dependencies: ["JBLProtocol"]),
        .testTarget(name: "JBLDeviceTests", dependencies: ["JBLDevice", "JBLProtocol"]),
    ],
    swiftLanguageModes: [.v6]
)
