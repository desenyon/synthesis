import Foundation

public struct EntityPropertyImage: Equatable, Sendable {
  public var ownerID: String
  public var name: String
  public var mimeType: String
  public var data: Data
}

extension WorkspaceStore {
  /// Saved images from active schemas, templates and profiles, including a profile's frozen
  /// accepted image. Media bytes never enter assistant context. Archived material is opt-in,
  /// matching other image-export sources; the complete world archive always keeps histories.
  public func entityPropertyImages(worldID: String, includingArchived: Bool = false) throws
    -> [EntityPropertyImage]
  {
    _ = try world(worldID)
    var result: [EntityPropertyImage] = []
    var seen = Set<Data>()
    func collect(_ values: [String: EntityValue], ownerID: String) throws {
      for key in values.keys.sorted() {
        guard case .media(let name, let mime, let encoded) = values[key] else { continue }
        guard let data = Data(base64Encoded: encoded), try Self.validateArtwork(data) == mime else {
          throw SynthesisError.invalid(
            "A saved property image could not be exported. The original value is preserved.")
        }
        if seen.insert(data).inserted {
          result.append(
            EntityPropertyImage(ownerID: ownerID, name: name, mimeType: mime, data: data))
        }
      }
    }
    for type in try entityTypes(worldID: worldID, includingArchived: includingArchived) {
      let resolved = try resolvedEntityType(worldID: worldID, id: type.id)
      try collect(resolved.defaults, ownerID: type.id)
      for field in resolved.fields {
        if let condition = field.condition {
          try collect([field.key: condition.equals], ownerID: type.id)
        }
      }
    }
    for template in try entityTemplates(worldID: worldID, includingArchived: includingArchived) {
      try collect(template.values, ownerID: template.id)
    }
    let profiles = try db.rows(
      "SELECT p.record_id FROM entity_profiles p JOIN records r ON r.id=p.record_id AND r.world_id=p.world_id WHERE p.world_id=? \(includingArchived ? "" : "AND r.archived=0") ORDER BY p.created_at,p.id",
      [worldID])
    for row in profiles {
      let id = row["record_id"]!
      guard let review = try entityProfileReview(worldID: worldID, recordID: id) else { continue }
      try collect(review.snapshot.values, ownerID: id)
      if let canonical = review.profile.canonical {
        try collect(canonical.values, ownerID: id)
        for field in canonical.fields {
          if let condition = field.condition {
            try collect([field.key: condition.equals], ownerID: id)
          }
        }
      }
    }
    return result
  }
}
