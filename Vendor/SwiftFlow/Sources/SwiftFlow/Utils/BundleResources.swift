import Foundation

extension Bundle {
  // Synthesis packaging patch: swift build's generated Bundle.module accessor does
  // not search Contents/Resources. Keep its fallback for package tests/development.
  static var swiftFlowResources: Bundle {
    if let url = Bundle.main.url(forResource: "SwiftFlow_SwiftFlow", withExtension: "bundle"),
      let packaged = Bundle(url: url) {
      return packaged
    }
    return .module
  }
}
