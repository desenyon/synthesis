import Foundation
import SynthesisCore

extension Studio {
  /// Copy a graph projection into a separate board. The Canvas derives live edges from the
  /// record IDs, so no second relationship or static connector has to be saved.
  @discardableResult
  func copyGraphToCanvas(
    worldID sourceWorldID: String, neighborhood: GraphNeighborhood?, shownIDs: Set<String>,
    positions: [String: CGPoint]
  ) throws -> Board? {
    guard destination == .knowledge, worldID == sourceWorldID, flushEditor() else { return nil }
    let entities = try store.records(worldID: sourceWorldID).filter { $0.kind == "entity" }
    let activeIDs = Set(entities.map(\.id))
    guard !shownIDs.isEmpty, shownIDs.isSubset(of: activeIDs) else {
      throw SynthesisError.invalid("The graph view changed. Choose the entities again.")
    }
    var name = "Graph copy"
    if let neighborhood {
      let currentEdges = try store.relations(worldID: sourceWorldID)
      let current = neighborhood.project(
        nodeIDs: activeIDs, edges: currentEdges.map { ($0.sourceID, $0.targetID) })
      guard current?.nodeIDs == shownIDs,
        let root = entities.first(where: { $0.id == neighborhood.rootID })
      else { throw SynthesisError.invalid("The neighbourhood changed. Review it before copying.") }
      name = String("Around \(root.title)".prefix(120))
    }
    let included = entities.filter { shownIDs.contains($0.id) }
    var document = CanvasDocument()
    document.cards = try included.map { record in
      guard let centre = positions[record.id], centre.x.isFinite, centre.y.isFinite else {
        throw SynthesisError.invalid("Wait for the graph layout to finish and try again.")
      }
      var card = CanvasCard(text: record.title, recordID: record.id)
      card.width = 300
      card.x = centre.x * 1.2
      card.y = centre.y * 1.3
      return card
    }
    let data = try JSONEncoder().encode(document)
    let board = try store.saveBoard(
      worldID: sourceWorldID, name: name, kind: "canvas",
      content: String(decoding: data, as: UTF8.self))
    openBoard(board.id, kind: "canvas")
    show("Created board “\(name)”.")
    return board
  }
}
