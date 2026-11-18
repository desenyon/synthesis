/// A presentation-only view around one existing entity. Edges keep their original
/// direction when drawn, while either direction counts when traversing the graph.
struct GraphNeighborhood: Codable, Equatable {
  var rootID: String
  var depth: Int

  struct Projection: Equatable {
    let nodeIDs: Set<String>
    let canExpand: Bool
  }

  func project(nodeIDs: Set<String>, edges: [(String, String)]) -> Projection? {
    guard nodeIDs.contains(rootID) else { return nil }
    var adjacent: [String: Set<String>] = [:]
    for (source, target) in edges where nodeIDs.contains(source) && nodeIDs.contains(target) {
      adjacent[source, default: []].insert(target)
      adjacent[target, default: []].insert(source)
    }

    var visited: Set<String> = [rootID]
    var frontier = visited
    var remaining = max(1, depth)
    while !frontier.isEmpty {
      let next = Set(frontier.flatMap { adjacent[$0] ?? [] }).subtracting(visited)
      if remaining == 0 { return Projection(nodeIDs: visited, canExpand: !next.isEmpty) }
      visited.formUnion(next)
      frontier = next
      remaining -= 1
    }
    return Projection(nodeIDs: visited, canExpand: false)
  }
}
