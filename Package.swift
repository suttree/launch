// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GOTO",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "GOTO", targets: ["GOTO"])],
    targets: [.executableTarget(name: "GOTO")]
)
