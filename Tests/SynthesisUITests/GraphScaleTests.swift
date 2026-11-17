import Foundation
import Testing

@testable import SynthesisUI

struct GraphScaleTests {
  @Test func dagreLayoutHandlesHundredsOfEntities() throws {
    #expect(GraphLayout.engineAvailable)
    for count in [100, 300] {
      let nodes = (0..<count).map { "n\($0)" }
      let edges = (0..<(count * 2)).map { ("n\($0 % count)", "n\(($0 * 7 + 1) % count)") }
      let start = ContinuousClock.now
      let points = GraphLayout.positions(nodes: nodes, edges: edges)
      let elapsed = start.duration(to: .now)
      print("Graph layout benchmark: \(count) entities, \(edges.count) relationships: \(elapsed)")
      #expect(points.count == count)
      #expect(points.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
      #expect(elapsed < .seconds(20))
    }
    // A chain laid out left to right proves Dagre ran, not the grid fallback.
    let chain = GraphLayout.positions(
      nodes: ["a", "b", "c", "d"], edges: [("a", "b"), ("b", "c"), ("c", "d")])
    let xs = ["a", "b", "c", "d"].compactMap { chain[$0]?.x }
    #expect(xs == xs.sorted() && Set(xs).count == 4)
    #expect(Set(["a", "b", "c", "d"].compactMap { chain[$0]?.y }).count == 1)
  }
}
