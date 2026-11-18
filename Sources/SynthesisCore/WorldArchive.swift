import Foundation

/// Portable, versioned world snapshot. Preferences are explicitly allowlisted: never auth,
/// provider settings, device paths, or other worlds. SQLite remains the live working copy.
struct WorldArchive: Codable {
  var format = "dev.synthesis.world"
  var version = 12
  var tables: [String: [[String: String]]]
  var preferences: [String: String]
}

extension WorkspaceStore {
  private static let archiveTables = [
    "worlds", "records", "rich_documents", "revisions", "native_revisions", "links",
    "relationships", "relationship_history", "events", "conversations", "messages",
    "proposals", "message_context", "boards", "rules", "rule_history", "rule_scenarios",
    "chronology_lanes",
    "chronology_placements", "record_sections", "creative_components", "rule_prerequisites",
    "record_artwork", "world_activity", "entity_types", "entity_profiles", "entity_profile_history",
    "entity_type_history", "entity_templates", "entity_template_history", "conversation_branches",
    "conversation_message_origins", "prompt_recipes", "entity_name_periods",
    "entity_name_period_history",
  ]
  public func exportWorldArchive(worldID: String) throws -> Data {
    _ = try world(worldID)
    var tables: [String: [[String: String]]] = [:]
    for table in Self.archiveTables {
      if table == "worlds" {
        tables[table] = try db.rows("SELECT * FROM worlds WHERE id=?", [worldID])
      } else if table == "rich_documents" {
        tables[table] = try db.rows(
          "SELECT * FROM rich_documents WHERE record_id IN (SELECT id FROM records WHERE world_id=?)",
          [worldID])
      } else {
        tables[table] = try db.rows(
          "SELECT * FROM \(table) WHERE world_id=? ORDER BY rowid", [worldID])
      }
    }
    var preferences: [String: String] = [:]
    for key in ["world-cover", "composer", "world-defaults"] {
      preferences[key] = try preference("\(key):\(worldID)")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(WorldArchive(tables: tables, preferences: preferences))
  }

  /// Imports an independent copy, even if this snapshot was exported from this installation.
  /// Fresh IDs prevent cross-world links. Everything rolls back if validation or a write fails.
  public func importWorldArchive(_ data: Data) throws -> World {
    try importWorldArchiveMapping(data).world
  }
  /// The import, also returning old → new identifiers so a what-if branch can trace its copies.
  func importWorldArchiveMapping(_ data: Data) throws -> (world: World, ids: [String: String]) {
    guard data.count <= 200_000_000 else {
      throw SynthesisError.invalid("This world file exceeds 200 MB.")
    }
    var archive = try JSONDecoder().decode(WorldArchive.self, from: data)
    if archive.version == 1 {
      archive.tables["chronology_lanes"] = []
      archive.tables["chronology_placements"] = []
    }
    if [1, 2].contains(archive.version) { archive.tables["record_sections"] = [] }
    if (1...4).contains(archive.version) { archive.tables["creative_components"] = [] }
    if (1...5).contains(archive.version) { archive.tables["rule_history"] = [] }
    if (1...6).contains(archive.version) { archive.tables["rule_prerequisites"] = [] }
    if (1...7).contains(archive.version) { archive.tables["record_artwork"] = [] }
    if (1...8).contains(archive.version) { archive.tables["world_activity"] = [] }
    if (1...9).contains(archive.version) {
      for table in [
        "entity_types", "entity_profiles", "entity_profile_history", "entity_type_history",
        "entity_templates", "entity_template_history", "conversation_branches",
        "conversation_message_origins",
        "prompt_recipes",
      ] { archive.tables[table] = [] }
    }
    if (1...11).contains(archive.version) {
      for table in ["entity_name_periods", "entity_name_period_history"] {
        archive.tables[table] = archive.tables[table] ?? []
      }
    }
    guard archive.format == "dev.synthesis.world", (1...12).contains(archive.version),
      Set(archive.tables.keys) == Set(Self.archiveTables),
      archive.tables["worlds"]?.count == 1,
      let original = archive.tables["worlds"]?.first, let oldWorld = original["id"],
      UUID(uuidString: oldWorld) != nil,
      archive.tables.values.reduce(0, { $0 + $1.count }) <= 100_000,
      Set(archive.preferences.keys).isSubset(of: ["world-cover", "composer", "world-defaults"])
    else { throw SynthesisError.invalid("This is not a supported Synthesis world file.") }
    var ids: [String: String] = [:]
    for table in Self.archiveTables {
      let info = try db.rows("PRAGMA table_info(\(table))")
      let columns = Set(info.compactMap { $0["name"] })
      let primaryKeys = info.filter { Int($0["pk"] ?? "0") ?? 0 > 0 }.compactMap { $0["name"] }
      for row in archive.tables[table] ?? [] {
        guard !row.isEmpty, Set(row.keys).isSubset(of: columns),
          primaryKeys.allSatisfy({ row[$0].flatMap(UUID.init(uuidString:)) != nil }),
          table == "worlds" || table == "rich_documents" || row["world_id"] == oldWorld
        else {
          throw SynthesisError.invalid("The world file contains invalid or mixed-world records.")
        }
        if let id = row["id"] {
          guard UUID(uuidString: id) != nil, ids[id] == nil else {
            throw SynthesisError.invalid(
              "The world file contains invalid or duplicate identifiers.")
          }
          ids[id] = UUID().uuidString
        }
      }
    }
    func remap(_ text: String) -> String {
      // UUID matches are replaced in one pass, including references inside JSON and links.
      let pattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
      let result = NSMutableString(string: text)
      for match in regex.matches(in: text, range: NSRange(location: 0, length: result.length))
        .reversed()
      {
        let id = result.substring(with: match.range)
        if let replacement = ids[id] {
          result.replaceCharacters(in: match.range, with: replacement)
        }
      }
      return result as String
    }
    func remapRTF(_ raw: String) -> String {
      guard let bytes = Data(base64Encoded: raw), let text = String(data: bytes, encoding: .utf8)
      else { return raw }
      let updated = remap(text)
      return updated == text ? raw : Data(updated.utf8).base64EncodedString()
    }
    func remapSnapshotRTF(_ raw: String, includesCanon: Bool = false) throws -> String {
      guard
        var snapshot = (try? JSONSerialization.jsonObject(with: Data(raw.utf8)))
          as? [String: Any]
      else { return raw }
      var changed = false
      if let rtf = snapshot["rtf"] as? String {
        let updated = remapRTF(rtf)
        if updated != rtf {
          snapshot["rtf"] = updated
          changed = true
        }
      }
      if includesCanon, let canon = snapshot["canonical"] as? String {
        let updated = try remapSnapshotRTF(canon)
        if updated != canon {
          snapshot["canonical"] = updated
          changed = true
        }
      }
      guard changed else { return raw }
      return String(
        decoding: try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys]),
        as: UTF8.self)
    }
    archive.tables["chronology_lanes"] = try chronologyLanesInImportOrder(
      archive.tables["chronology_lanes"] ?? [])
    return try db.transaction {
      let newWorld = ids[oldWorld]!
      try db.execute("INSERT INTO activity_imports(world_id) VALUES(?)", [newWorld])
      for table in Self.archiveTables {
        for source in archive.tables[table] ?? [] {
          var row = source.mapValues(remap)
          if table == "record_artwork" {
            guard let image = source["image"], let data = Data(base64Encoded: image),
              try Self.validateArtwork(data) == source["mime_type"],
              ["imported", "user-authored", "ai-generated"].contains(source["origin"] ?? "")
            else { throw SynthesisError.invalid("The world file contains invalid artwork.") }
            row["image"] = image
          }
          if ["relationships", "relationship_history"].contains(table),
            let raw = source["attributes"]
          {
            // Only evidence addresses are IDs. Date labels are the creator's own wording.
            var attributes = try RelationshipAttributes.decodeStored(raw)
            attributes.evidenceRecordIDs = try attributes.evidenceRecordIDs.map { id in
              guard let replacement = ids[id] else {
                throw SynthesisError.invalid(
                  "The world file contains relationship evidence outside this world.")
              }
              return replacement
            }
            row["attributes"] = try attributes.encodeStored()
          }
          if ["entity_name_periods", "entity_name_period_history"].contains(table) {
            // Names and date labels are fictional wording, never addresses.
            try validateEntityNameArchiveLabels(source)
            for key in ["name", "start_label", "end_label"] { row[key] = source[key] }
          }
          // Reject external references even on tables whose historical schema lacks FKs.
          for (key, value) in source where key.hasSuffix("_id") && key != "owner_id" {
            guard ids[value] != nil else {
              throw SynthesisError.invalid("The world file references content outside this world.")
            }
          }
          if table == "worlds" { row["owner_id"] = "local" }
          if table == "rich_documents", let rtf = source["rtf"] {
            row["rtf"] = remapRTF(rtf)
          }
          if table == "records", let canon = row["canonical"] {
            row["canonical"] = try remapSnapshotRTF(canon)
          }
          if table == "native_revisions", let snapshot = row["snapshot"] {
            row["snapshot"] = try remapSnapshotRTF(snapshot, includesCanon: true)
          }
          let columns = row.keys.sorted()
          let placeholders = columns.map { _ in "?" }.joined(separator: ",")
          try db.execute(
            "INSERT INTO \(table)(\(columns.joined(separator: ","))) VALUES(\(placeholders))",
            columns.map { row[$0] })
        }
      }
      if (archive.tables["world_activity"] ?? []).isEmpty {
        try ActivityHistoryMigration.backfill(db, worldID: newWorld)
      }
      try validateActivitySources(worldID: newWorld)
      try validateRelationshipArchive(worldID: newWorld)
      try validateEntityNameArchive(worldID: newWorld)
      try validateEntitySchemas(worldID: newWorld)
      try refreshEntityPropertySearch(worldID: newWorld)
      try validateConversationTools(worldID: newWorld)
      // Membership is presentation data, but must still obey the entity -> lore contract.
      // Validate imports as well as interactive writes to prevent recursive/cyclic pages.
      guard
        try db.rows(
          "SELECT s.id FROM record_sections s JOIN records p ON p.id=s.parent_id JOIN records r ON r.id=s.record_id WHERE s.world_id=? AND (p.kind!='entity' OR r.kind!='lore') LIMIT 1",
          [newWorld]
        ).isEmpty
      else { throw SynthesisError.invalid("The world file contains invalid entity sections.") }
      guard
        try db.rows(
          "SELECT c.id FROM creative_components c JOIN records r ON r.id=c.record_id LEFT JOIN record_sections s ON s.record_id=c.record_id AND s.parent_id=c.parent_id AND s.world_id=c.world_id WHERE c.world_id=? AND (r.kind!='lore' OR (c.scope='entity' AND s.id IS NULL)) LIMIT 1",
          [newWorld]
        ).isEmpty
      else { throw SynthesisError.invalid("The world file contains invalid creative components.") }
      guard
        try db.rows(
          "SELECT a.id FROM record_artwork a JOIN records r ON r.id=a.record_id WHERE a.world_id=? AND (r.kind!='entity' OR r.world_id!=a.world_id) LIMIT 1",
          [newWorld]
        ).isEmpty
      else { throw SynthesisError.invalid("The world file contains invalid artwork owners.") }
      for map in try db.rows(
        "SELECT id,content FROM boards WHERE world_id=? AND kind='atlas'", [newWorld])
      {
        try validateAtlasMap(
          worldID: newWorld, id: map["id"], content: map["content"] ?? "", includingArchived: true)
      }
      for (key, value) in archive.preferences {
        if key == "world-defaults" {
          let defaults = try JSONDecoder().decode(WorldPreferences.self, from: Data(value.utf8))
          try setWorldPreferences(worldID: newWorld, value: defaults)
        } else {
          try setPreference(
            "\(key):\(newWorld)", value: key == "world-cover" ? value : remap(value))
        }
      }
      try db.execute("DELETE FROM activity_imports WHERE world_id=?", [newWorld])
      try db.execute(
        "INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at) VALUES(?,?,?,'world','created',?,'World imported',?)",
        [UUID().uuidString, newWorld, newWorld, try world(newWorld).name, timestamp()])
      return (try world(newWorld), ids)
    }
  }
}
