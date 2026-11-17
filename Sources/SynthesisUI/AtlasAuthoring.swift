import Foundation

/// Mutually exclusive map tools. Changing tools abandons only the uncommitted gesture,
/// never a saved marker or region.
struct AtlasAuthoring {
  enum Tool: Equatable {
    case browse
    case marker(String)
    case region(record: String, replacing: String?)
  }
  private(set) var tool = Tool.browse
  private(set) var points: [CGPoint] = []
  var markerID: String? {
    if case .marker(let id) = tool { return id }
    return nil
  }
  var regionRecordID: String? {
    if case .region(let id, _) = tool { return id }
    return nil
  }
  var replacedRegionID: String? {
    if case .region(_, let id) = tool { return id }
    return nil
  }
  mutating func choose(_ value: Tool) {
    tool = value
    points = []
  }
  mutating func addPoint(_ point: CGPoint) {
    guard regionRecordID != nil, points.count < 200, point.x.isFinite, point.y.isFinite else {
      return
    }
    points.append(CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y))))
  }
  mutating func undoPoint() { _ = points.popLast() }
}
