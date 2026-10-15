// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AppMixer", platforms: [.macOS("14.2")], products: [.executable(name: "AppMixer", targets: ["AppMixer"])], dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")], targets: [.target(name: "AudioDSP"), .executableTarget(name: "AppMixer", dependencies: ["AudioDSP", .product(name: "Sparkle", package: "Sparkle")]), .testTarget(name: "AppMixerTests", dependencies: ["AppMixer", "AudioDSP"])])
