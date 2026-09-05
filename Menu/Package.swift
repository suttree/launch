// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Menu",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Menu", targets: ["Menu"])],
    targets: [.executableTarget(name: "Menu")]
)
