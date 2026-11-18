import Foundation

/// Current Library classification by structured profile, independent of saved legacy categories.
public struct EntityTypeCollection: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public internal(set) var recordIDs: Set<String> = []
}

extension WorkspaceStore {
  public func entityTypeCollections(worldID: String) throws -> [EntityTypeCollection] {
    _ = try world(worldID)
    let rows = try db.rows(
      """
      SELECT t.id,t.name,p.record_id
      FROM entity_types t LEFT JOIN entity_profiles p ON p.type_id=t.id AND p.world_id=t.world_id
      WHERE t.world_id=? AND t.archived=0
      ORDER BY t.name COLLATE synthesis_search,t.id
      """, [worldID])
    var collections: [EntityTypeCollection] = []
    for row in rows {
      let id = row["id"]!
      if collections.last?.id != id {
        collections.append(EntityTypeCollection(id: id, name: row["name"]!))
      }
      if let recordID = row["record_id"] {
        collections[collections.count - 1].recordIDs.insert(recordID)
      }
    }
    return collections
  }
}
