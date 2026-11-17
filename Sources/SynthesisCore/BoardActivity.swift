import Foundation

/// Navigation and serialization order are not creative edits. Keep the complete saved board,
/// but omit viewport-only changes and engine bookkeeping from the activity comparison.
enum BoardActivity {
  static func changed(_ old: String, _ new: String) -> Bool {
    guard old != new else { return false }
    guard let left = normalized(old), let right = normalized(new) else { return true }
    return !NSDictionary(dictionary: left).isEqual(to: right)
  }
  private static func normalized(_ text: String) -> [String: Any]? {
    guard var object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
    else { return nil }
    if object["format"] as? String == "excalidraw", var scene = object["scene"] as? [String: Any] {
      scene.removeValue(forKey: "appState")
      if let elements = scene["elements"] as? [[String: Any]] {
        scene["elements"] = elements.map { element in
          var value = element
          for key in ["version", "versionNonce", "updated"] { value.removeValue(forKey: key) }
          return value
        }
      }
      object["scene"] = scene
    } else if object["cards"] != nil {
      object.removeValue(forKey: "viewport")
    }
    return object
  }
}
