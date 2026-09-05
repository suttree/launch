// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Launch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Launch", targets: ["Launch"])],
    targets: [
        .executableTarget(name: "Launch"),
        .testTarget(name: "LaunchTests", dependencies: ["Launch"])
    ]
)
