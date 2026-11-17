import Foundation
import ImageIO

/// Optional visual reference, separate from the record's accepted written canon.
/// Replacing or removing it archives the previous image, never deletes it.
public struct RecordArtwork: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var worldID: String
  public var recordID: String
  public var image: String
  public var mimeType: String
  public var origin: String
  public var createdAt: String
}

extension WorkspaceStore {
  public func recordArtwork(worldID: String, recordID: String) throws -> RecordArtwork? {
    _ = try record(worldID: worldID, id: recordID)
    return try db.rows(
      "SELECT * FROM record_artwork WHERE world_id=? AND record_id=? AND archived=0",
      [worldID, recordID]
    ).first.map(artworkRow)
  }

  public func recordArtworks(worldID: String) throws -> [RecordArtwork] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT a.* FROM record_artwork a JOIN records r ON r.id=a.record_id AND r.world_id=a.world_id WHERE a.world_id=? AND a.archived=0 AND r.archived=0 ORDER BY a.created_at",
      [worldID]
    ).map(artworkRow)
  }

  /// Lightweight index for spatial views. Image bytes are loaded only for visible cards.
  public func recordArtworkIDs(worldID: String) throws -> [String: String] {
    _ = try world(worldID)
    return Dictionary(
      uniqueKeysWithValues: try db.rows(
        "SELECT a.id,a.record_id FROM record_artwork a JOIN records r ON r.id=a.record_id AND r.world_id=a.world_id WHERE a.world_id=? AND a.archived=0 AND r.archived=0",
        [worldID]
      ).map { ($0["record_id"]!, $0["id"]!) })
  }

  @discardableResult public func saveRecordArtwork(
    worldID: String, recordID: String, data: Data, origin: String = "imported",
    expectedID: String?
  ) throws -> RecordArtwork {
    let mime = try Self.validateArtwork(data)
    guard ["imported", "user-authored", "ai-generated"].contains(origin) else {
      throw SynthesisError.invalid("Choose a supported artwork origin.")
    }
    return try db.transaction {
      let record = try record(worldID: worldID, id: recordID)
      guard record.kind == "entity" else {
        throw SynthesisError.invalid("Artwork belongs to an entity profile.")
      }
      guard try recordArtwork(worldID: worldID, recordID: recordID)?.id == expectedID else {
        throw SynthesisError.stale
      }
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        "UPDATE record_artwork SET archived=1,updated_at=? WHERE world_id=? AND record_id=? AND archived=0",
        [now, worldID, recordID])
      try db.execute(
        "INSERT INTO record_artwork VALUES(?,?,?,?,?,?,0,?,?)",
        [id, worldID, recordID, data.base64EncodedString(), mime, origin, now, now])
      return RecordArtwork(
        id: id, worldID: worldID, recordID: recordID, image: data.base64EncodedString(),
        mimeType: mime, origin: origin, createdAt: now)
    }
  }

  /// Select a saved revision, or nil to remove. The expected current ID prevents stale Undo
  /// from replacing artwork changed since the user saw the original operation.
  public func restoreRecordArtwork(
    worldID: String, recordID: String, id: String?, expectedID: String?
  ) throws {
    try db.transaction {
      _ = try record(worldID: worldID, id: recordID)
      guard try recordArtwork(worldID: worldID, recordID: recordID)?.id == expectedID else {
        throw SynthesisError.stale
      }
      if let id {
        guard
          try !db.rows(
            "SELECT id FROM record_artwork WHERE id=? AND world_id=? AND record_id=?",
            [id, worldID, recordID]
          ).isEmpty
        else { throw SynthesisError.notFound }
      }
      let now = timestamp()
      try db.execute(
        "UPDATE record_artwork SET archived=1,updated_at=? WHERE world_id=? AND record_id=? AND archived=0",
        [now, worldID, recordID])
      if let id {
        try db.execute(
          "UPDATE record_artwork SET archived=0,updated_at=? WHERE id=? AND world_id=? AND record_id=?",
          [now, id, worldID, recordID])
      }
    }
  }

  static func validateArtwork(_ data: Data) throws -> String {
    guard !data.isEmpty, data.count <= 6_000_000,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) == 1,
      let type = CGImageSourceGetType(source) as String?,
      ["public.png", "public.jpeg"].contains(type),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      (1...8192).contains(width), (1...8192).contains(height),
      CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary)
        != nil
    else {
      throw SynthesisError.invalid("Choose a PNG or JPEG up to 6 MB and 8192 pixels per side.")
    }
    return type == "public.png" ? "image/png" : "image/jpeg"
  }

  private func artworkRow(_ row: [String: String]) -> RecordArtwork {
    RecordArtwork(
      id: row["id"]!, worldID: row["world_id"]!, recordID: row["record_id"]!,
      image: row["image"]!, mimeType: row["mime_type"]!, origin: row["origin"]!,
      createdAt: row["created_at"]!)
  }
}
