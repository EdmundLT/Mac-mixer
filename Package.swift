// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AppMixer", platforms: [.macOS("14.2")], products: [.executable(name: "AppMixer", targets: ["AppMixer"])], targets: [.target(name: "AudioDSP"), .executableTarget(name: "AppMixer", dependencies: ["AudioDSP"]), .testTarget(name: "AppMixerTests", dependencies: ["AppMixer", "AudioDSP"])])
