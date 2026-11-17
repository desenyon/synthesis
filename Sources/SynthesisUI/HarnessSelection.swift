import Foundation

/// Per-window runtime selection. SQLite owns persistence; verification must never change
/// another app instance through process-external UserDefaults.
final class HarnessSelection: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: String] = [:]
  func string(forKey key: String) -> String {
    lock.withLock { values[key] ?? "" }
  }
  func set(_ value: String, forKey key: String) {
    lock.withLock { values[key] = value }
  }
}
