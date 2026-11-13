// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Synthesis", platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Synthesis", targets: ["SynthesisApp"]),
    .library(name: "SynthesisCore", targets: ["SynthesisCore"]),
  ],
  targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "SynthesisCore", dependencies: ["CSQLite"], resources: [.copy("Migrations")]),
    .target(name: "SynthesisUI", dependencies: ["SynthesisCore"]),
    .executableTarget(name: "SynthesisApp", dependencies: ["SynthesisUI", "SynthesisCore"]),
    .testTarget(name: "SynthesisCoreTests", dependencies: ["SynthesisCore"]),
  ], swiftLanguageModes: [.v5]
)
