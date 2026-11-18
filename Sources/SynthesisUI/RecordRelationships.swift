import SynthesisCore

struct RecordRelationship: Identifiable {
  let relation: Relation
  let counterpart: LoreRecord
  let incoming: Bool
  var id: String { relation.id }
  var detail: String { "\(incoming ? "Incoming" : "Outgoing") · \(relation.label)" }
}

extension Studio {
  /// Projects one stored edge from the entity currently being viewed.
  func recordRelationships(for record: LoreRecord) throws -> [RecordRelationship] {
    guard record.worldID == worldID, record.kind == "entity" else { return [] }
    let edges = try store.relations(worldID: worldID, recordID: record.id)
    guard !edges.isEmpty else { return [] }
    let available = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    return edges.compactMap { edge in
      let incoming = edge.targetID == record.id
      let id = incoming ? edge.sourceID : edge.targetID
      guard let counterpart = available[id] else { return nil }
      return RecordRelationship(relation: edge, counterpart: counterpart, incoming: incoming)
    }
  }
}
