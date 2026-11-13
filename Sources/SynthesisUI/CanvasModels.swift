import AppKit
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

/// Serialized shapes stored in the world-scoped boards table. New fields must stay optional or
/// defaulted so earlier board documents continue to decode.
struct CanvasCard: Identifiable, Codable, Equatable {
  var id = UUID().uuidString
  var text = "An unwritten thought"
  var recordID: String?
  var image: String?
  var x = 0.0
  var y = 0.0
  var width = 230.0
  var height = 160.0
  var group: String?
}
struct CanvasEdge: Codable, Equatable {
  var label: String?
  var source: String
  var target: String
}
struct CanvasDocument: Codable, Equatable {
  var viewport: BoardViewport?
  var cards: [CanvasCard] = []
  var edges: [CanvasEdge] = []
}
struct BoardViewport: Codable, Equatable {
  var x = 0.0
  var y = 0.0
  var zoom = 1.0
}
struct MapMarker: Identifiable, Codable, Equatable {
  var id = UUID().uuidString
  var recordID: String
  var x: Double
  var y: Double
}
struct AtlasDocument: Codable, Equatable {
  var image: String?
  var markers: [MapMarker] = []
}

/// A relationship or board link resolved to the cards it joins.
struct DisplayEdge: Identifiable, Equatable {
  var id: String
  var source: String
  var target: String
  var label: String
  var localIndex: Int?
}

/// Connector path between two card rectangles: leaves and enters on facing sides.
struct EdgeGeometry {
  var start: CGPoint
  var end: CGPoint
  var control1: CGPoint
  var control2: CGPoint
  /// Unit direction the connector travels as it reaches `end`.
  var heading: CGVector
  var path: Path {
    var path = Path()
    path.move(to: start)
    path.addCurve(to: end, control1: control1, control2: control2)
    return path
  }
  var arrow: Path {
    let size = 7.0
    let back = CGPoint(x: end.x - heading.dx * size, y: end.y - heading.dy * size)
    let normal = CGVector(dx: -heading.dy, dy: heading.dx)
    var path = Path()
    path.move(to: end)
    path.addLine(
      to: CGPoint(x: back.x + normal.dx * size * 0.55, y: back.y + normal.dy * size * 0.55))
    path.addLine(
      to: CGPoint(x: back.x - normal.dx * size * 0.55, y: back.y - normal.dy * size * 0.55))
    path.closeSubpath()
    return path
  }
  var midpoint: CGPoint {
    // Cubic Bézier at t = 0.5.
    CGPoint(
      x: (start.x + 3 * control1.x + 3 * control2.x + end.x) / 8,
      y: (start.y + 3 * control1.y + 3 * control2.y + end.y) / 8)
  }
  /// `lane` separates parallel connectors between the same pair of cards.
  static func between(_ a: CGRect, _ b: CGRect, lane: Double = 0, gap: Double = 3) -> EdgeGeometry {
    let dx = b.midX - a.midX
    let dy = b.midY - a.midY
    let horizontal =
      abs(dx) / max(1, (a.width + b.width) / 2) >= abs(dy) / max(1, (a.height + b.height) / 2)
    if horizontal {
      let forward = dx >= 0
      let start = CGPoint(x: forward ? a.maxX + gap : a.minX - gap, y: a.midY + lane)
      let end = CGPoint(x: forward ? b.minX - gap : b.maxX + gap, y: b.midY + lane)
      let reach = max(24, abs(end.x - start.x) / 2) * (forward ? 1 : -1)
      return EdgeGeometry(
        start: start, end: end, control1: CGPoint(x: start.x + reach, y: start.y),
        control2: CGPoint(x: end.x - reach, y: end.y),
        heading: CGVector(dx: forward ? 1 : -1, dy: 0))
    }
    let forward = dy >= 0
    let start = CGPoint(x: a.midX + lane, y: forward ? a.maxY + gap : a.minY - gap)
    let end = CGPoint(x: b.midX + lane, y: forward ? b.minY - gap : b.maxY + gap)
    let reach = max(24, abs(end.y - start.y) / 2) * (forward ? 1 : -1)
    return EdgeGeometry(
      start: start, end: end, control1: CGPoint(x: start.x, y: start.y + reach),
      control2: CGPoint(x: end.x, y: end.y - reach), heading: CGVector(dx: 0, dy: forward ? 1 : -1))
  }
}

/// Lane offsets so several connectors between one pair of cards do not overlap.
func edgeLanes(_ edges: [DisplayEdge], spacing: Double = 26) -> [String: Double] {
  var groups: [Set<String>: [String]] = [:]
  for edge in edges { groups[[edge.source, edge.target], default: []].append(edge.id) }
  var lanes: [String: Double] = [:]
  for ids in groups.values {
    for (index, id) in ids.enumerated() {
      lanes[id] = (Double(index) - Double(ids.count - 1) / 2) * spacing
    }
  }
  return lanes
}

func pickImage(limit: Int = 6_000_000) throws -> String? {
  let panel = NSOpenPanel()
  panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
  panel.allowsMultipleSelection = false
  guard panel.runModal() == .OK, let url = panel.url else { return nil }
  let data = try Data(contentsOf: url)
  guard data.count <= limit, NSImage(data: data) != nil else {
    throw SynthesisError.invalid("Choose an image under \(limit / 1_000_000) MB.")
  }
  return data.base64EncodedString()
}
