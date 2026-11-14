// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Synthesis", platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Synthesis", targets: ["SynthesisApp"]),
    .library(name: "SynthesisCore", targets: ["SynthesisCore"]),
  ],
  dependencies: [.package(path: "Vendor/SwiftFlow")],
  targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "SynthesisCore", dependencies: ["CSQLite"], resources: [.copy("Migrations")]),
    .target(
      name: "SynthesisUI",
      dependencies: ["SynthesisCore", .product(name: "SwiftFlow", package: "SwiftFlow")],
      resources: [.copy("Assets")]),
    .executableTarget(name: "SynthesisApp", dependencies: ["SynthesisUI", "SynthesisCore"]),
    .testTarget(name: "SynthesisCoreTests", dependencies: ["SynthesisCore"]),
    .testTarget(name: "SynthesisUITests", dependencies: ["SynthesisUI", "SynthesisCore"]),
  ], swiftLanguageModes: [.v5]
)
