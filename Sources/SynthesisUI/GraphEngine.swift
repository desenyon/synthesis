import Foundation
import SwiftFlow
import SynthesisCore

/// The only translation layer between persisted world records and the graph engine.
/// Engine changes never write lore, approve canon, or delete source records.
enum GraphEngine {
  struct Snapshot: Sendable {
    var nodes: [Node<LoreRecord>]
    var edges: [FlowEdge<EmptyEdgeData>]
  }

  static func project(worldID: String, records: [LoreRecord], relationships: [Relation]) -> Snapshot
  {
    let entities = records.filter { $0.worldID == worldID && $0.kind == "entity" }.sorted {
      $0.id < $1.id
    }
    let ids = Set(entities.map(\.id))
    let nodes = entities.enumerated().map { index, record in
      Node(
        id: record.id, position: XYPosition(x: Double(index % 3) * 340, y: Double(index / 3) * 210),
        data: record, width: 220, height: 116, draggable: false, deletable: false,
        sourcePosition: .right, targetPosition: .left)
    }
    let edges = relationships.filter {
      ids.contains($0.sourceID) && ids.contains($0.targetID)
    }.sorted { $0.id < $1.id }.map { relation in
      FlowEdge<EmptyEdgeData>(
        id: relation.id, source: relation.sourceID, target: relation.targetID,
        sourceHandle: "out", targetHandle: "in", type: .bezier, label: relation.label,
        markerEnd: .arrowClosed, reconnectable: false, deletable: false)
    }
    return Snapshot(nodes: arranged(nodes, edges: edges), edges: edges)
  }

  static func arranged<T>(
    _ nodes: [Node<T>], edges: [FlowEdge<EmptyEdgeData>],
    cardSize: CGSize = CGSize(width: 220, height: 116)
  ) -> [Node<T>] where T: Equatable & Sendable {
    let sizes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, cardSize) })
    // Grid provides distinct fallback positions for fully cyclic graphs (no tree roots).
    let grid = applyNodeChanges(
      computeAutoLayout(
        nodes: nodes, edges: edges,
        algorithm: .grid(columns: max(1, Int(ceil(sqrt(Double(nodes.count))))), nodeSpacing: 90),
        nodeSizes: sizes), nodes: nodes)
    return applyNodeChanges(
      computeAutoLayout(
        nodes: grid, edges: edges,
        algorithm: .tree(
          direction: .leftToRight, nodeSpacing: 90, levelSpacing: cardSize.width + 170),
        nodeSizes: sizes), nodes: grid)
  }

  static func canConnect(_ connection: Connection, in snapshot: Snapshot) -> Bool {
    guard connection.source != connection.target,
      snapshot.nodes.contains(where: { $0.id == connection.source }),
      snapshot.nodes.contains(where: { $0.id == connection.target })
    else { return false }
    return true  // Different labeled relationships between the same entities are valid.
  }

  static func neighborhood(_ selected: String?, in snapshot: Snapshot) -> Set<String> {
    guard let selected, let node = snapshot.nodes.first(where: { $0.id == selected }) else {
      return Set(snapshot.nodes.map(\.id))
    }
    return Set(
      ([node] + getIncomers(node: node, nodes: snapshot.nodes, edges: snapshot.edges)
        + getOutgoers(node: node, nodes: snapshot.nodes, edges: snapshot.edges)).map(\.id))
  }

  static func canvasDocument(from snapshot: Snapshot, selected: String? = nil) -> CanvasDocument {
    let ids = neighborhood(selected, in: snapshot)
    let nodes = arranged(
      snapshot.nodes.filter { ids.contains($0.id) },
      edges: snapshot.edges.filter { ids.contains($0.source) && ids.contains($0.target) },
      cardSize: CGSize(width: 300, height: 320))
    var document = CanvasDocument()
    document.cards = nodes.map { node in
      var card = CanvasCard(text: node.data.title, recordID: node.id)
      card.width = 300
      card.x = node.position.x + 150
      card.y = node.position.y + 160
      return card
    }
    return document
  }
}
