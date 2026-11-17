import JavaScriptCore
import SwiftUI

/// Dagre handles directed layout; SwiftUI owns rendering, selection and world-record actions.
/// The bundled, fixed script receives IDs and dimensions only. No network, shell, or model code.
enum GraphLayout {
  static let cardSize = CGSize(width: 270, height: 176)
  private static let script: String? = {
    for bundle in [Bundle.main, Bundle.module] {
      if let url = bundle.resourceURL?.appendingPathComponent("Assets/Graph/dagre.min.js"),
        let source = try? String(contentsOf: url, encoding: .utf8)
      {
        return source
      }
    }
    return nil
  }()
  static var engineAvailable: Bool { script != nil }
  static func positions(
    nodes: [String], edges: [(String, String)], landscape: Bool = true,
    size: CGSize = cardSize, nodeSeparation: Double = 56, rankSeparation: Double = 112
  ) -> [String: CGPoint] {
    guard !nodes.isEmpty, !Task.isCancelled else { return [:] }
    guard let script, let context = JSContext() else { return grid(nodes, landscape) }
    // JavaScriptCore has no browser structuredClone. Dagre only clones the JSON-safe
    // node attributes and arrays supplied here; no host objects cross this boundary.
    context.evaluateScript(
      "globalThis.structuredClone = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value));"
    )
    context.evaluateScript(script)
    let function = context.evaluateScript(
      """
      (function(nodes, edges, landscape, width, height, nodesep, ranksep) {
        const graph = new dagre.graphlib.Graph({ multigraph: true });
        graph.setGraph({rankdir: landscape ? 'LR' : 'TB', nodesep, ranksep, edgesep: 32});
        graph.setDefaultEdgeLabel(() => ({}));
        nodes.forEach(id => graph.setNode(id, {width, height}));
        edges.forEach((pair, index) => {
          if(graph.hasNode(pair[0]) && graph.hasNode(pair[1])) graph.setEdge(pair[0], pair[1], {}, String(index));
        });
        dagre.layout(graph);
        return nodes.map(id => ({id, x: graph.node(id).x, y: graph.node(id).y}));
      })
      """)
    guard
      let rows = function?.call(withArguments: [
        nodes, edges.map { [$0.0, $0.1] }, landscape, Double(size.width), Double(size.height),
        nodeSeparation, rankSeparation,
      ])?
      .toArray() as? [[String: Any]],
      rows.count == nodes.count, context.exception == nil
    else { return grid(nodes, landscape) }
    var points: [String: CGPoint] = [:]
    for row in rows {
      guard let id = row["id"] as? String, let x = row["x"] as? Double, let y = row["y"] as? Double,
        x.isFinite, y.isFinite
      else { return grid(nodes, landscape) }
      points[id] = CGPoint(x: x, y: y)
    }
    let xs = points.values.map(\.x)
    let ys = points.values.map(\.y)
    let center = CGPoint(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
    return points.mapValues { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
  }
  private static func grid(_ nodes: [String], _ landscape: Bool) -> [String: CGPoint] {
    let columns = max(1, Int(Double(nodes.count).squareRoot().rounded(.up)))
    return Dictionary(
      uniqueKeysWithValues: nodes.enumerated().map { index, id in
        let column = index % columns
        let row = index / columns
        return (
          id,
          CGPoint(
            x: Double(landscape ? column : row) * 382,
            y: Double(landscape ? row : column) * 232)
        )
      })
  }
}

/// Rectangle ports and cubic tangents remain legible even when nodes overlap.
struct GraphRoute {
  var start: CGPoint
  var first: CGPoint
  var second: CGPoint
  var end: CGPoint
  var middle: CGPoint {
    CGPoint(
      x: (start.x + 3 * first.x + 3 * second.x + end.x) / 8,
      y: (start.y + 3 * first.y + 3 * second.y + end.y) / 8)
  }
  func point(at t: Double) -> CGPoint {
    let u = 1 - t
    return CGPoint(
      x: u * u * u * start.x + 3 * u * u * t * first.x + 3 * u * t * t * second.x + t * t * t
        * end.x,
      y: u * u * u * start.y + 3 * u * u * t * first.y + 3 * u * t * t * second.y + t * t * t
        * end.y)
  }
  static func between(
    _ a: CGPoint, _ b: CGPoint, scale: Double, lane: Double, obstacles: [CGRect] = []
  ) -> GraphRoute {
    let direct = direct(a, b, scale: scale, lane: lane)
    let xs = [direct.start.x, direct.first.x, direct.second.x, direct.end.x]
    let ys = [direct.start.y, direct.first.y, direct.second.y, direct.end.y]
    let extent = CGRect(
      x: xs.min()!, y: ys.min()!, width: max(1, xs.max()! - xs.min()!),
      height: max(1, ys.max()! - ys.min()!)
    ).insetBy(dx: -8, dy: -8)
    let samples = (0...32).map { direct.point(at: Double($0) / 32) }
    let blocked = obstacles.contains { rect in
      rect.intersects(extent) && samples.contains { rect.insetBy(dx: -8, dy: -8).contains($0) }
    }
    guard blocked else { return direct }
    let half = CGSize(
      width: GraphLayout.cardSize.width / 2 * scale + 7,
      height: GraphLayout.cardSize.height / 2 * scale + 7)
    let horizontal = abs(a.x - b.x) >= abs(a.y - b.y)
    let rects =
      obstacles
      + [a, b].map {
        CGRect(
          x: $0.x - half.width, y: $0.y - half.height, width: half.width * 2,
          height: half.height * 2)
      }
    let low = rects.map { horizontal ? $0.minY : $0.minX }.min()!
    let high = rects.map { horizontal ? $0.maxY : $0.maxX }.max()!
    let centre = horizontal ? (a.y + b.y) / 2 : (a.x + b.x) / 2
    let side: Double = centre - low <= high - centre ? -1 : 1
    let start = CGPoint(
      x: a.x + (horizontal ? 0 : side * half.width), y: a.y + (horizontal ? side * half.height : 0))
    let end = CGPoint(
      x: b.x + (horizontal ? 0 : side * half.width), y: b.y + (horizontal ? side * half.height : 0))
    let outer = (side < 0 ? low : high) + side * (120 * scale + abs(lane) + max(0, lane) * 2)
    return GraphRoute(
      start: start,
      first: CGPoint(x: horizontal ? start.x : outer, y: horizontal ? outer : start.y),
      second: CGPoint(x: horizontal ? end.x : outer, y: horizontal ? outer : end.y), end: end)
  }
  private static func direct(_ a: CGPoint, _ b: CGPoint, scale: Double, lane: Double) -> GraphRoute
  {
    let half = CGSize(
      width: GraphLayout.cardSize.width / 2 * scale + 7,
      height: GraphLayout.cardSize.height / 2 * scale + 7)
    let horizontal = abs(b.x - a.x) / half.width >= abs(b.y - a.y) / half.height
    let direction: Double = (horizontal ? b.x - a.x : b.y - a.y) >= 0 ? 1 : -1
    let start = CGPoint(
      x: a.x + (horizontal ? direction * half.width : 0),
      y: a.y + (horizontal ? 0 : direction * half.height))
    let end = CGPoint(
      x: b.x - (horizontal ? direction * half.width : 0),
      y: b.y - (horizontal ? 0 : direction * half.height))
    let gap = (horizontal ? end.x - start.x : end.y - start.y) * direction
    if gap < 42 * scale {
      let spread = abs(a.x - b.x) < 24 * scale ? half.width / 2 : 0
      let from = CGPoint(x: a.x - spread, y: a.y - half.height)
      let to = CGPoint(x: b.x + spread, y: b.y - half.height)
      let top = min(from.y, to.y) - 90 * scale - abs(lane) - max(0, lane) * 2
      return GraphRoute(
        start: from, first: CGPoint(x: from.x, y: top),
        second: CGPoint(x: to.x, y: top), end: to)
    }
    let tangent = gap / 2 * direction
    return GraphRoute(
      start: start,
      first: CGPoint(
        x: start.x + (horizontal ? tangent : lane), y: start.y + (horizontal ? lane : tangent)),
      second: CGPoint(
        x: end.x + (horizontal ? -tangent : lane), y: end.y + (horizontal ? lane : -tangent)),
      end: end)
  }
}
