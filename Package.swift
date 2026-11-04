// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Convertly",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Convertly", targets: ["Convertly"])],
    targets: [
        .executableTarget(name: "Convertly"),
        .testTarget(name: "ConvertlyTests", dependencies: ["Convertly"])
    ]
)