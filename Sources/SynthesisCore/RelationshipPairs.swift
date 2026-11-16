import Foundation

extension WorkspaceStore {
  /// Two semantic directions are independent, traceable draft relationships. Either both save
  /// or neither does; a reverse label is never inferred from the forward label.
  public func addRelationshipPair(
    worldID: String, source: String, target: String, label: String, inverse: String? = nil
  ) throws {
    try db.transaction {
      _ = try addRelation(worldID: worldID, source: source, target: target, label: label)
      if let inverse {
        _ = try addRelation(worldID: worldID, source: target, target: source, label: inverse)
      }
    }
  }
}
