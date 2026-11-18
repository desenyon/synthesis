import Foundation

public final class WorkspaceStore {
  let db: Database
  public init(path: String) throws { db = try Database(path: path) }
  public static var defaultPath: String {
    ProcessInfo.processInfo.environment["SYNTHESIS_DATABASE_PATH"]
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
        "Library/Application Support/Synthesis/synthesis.sqlite"
      ).path
  }
  public func preference(_ key: String) throws -> String? {
    try db.rows("SELECT value FROM preferences WHERE key=?", [key]).first?["value"]
  }
  public func setPreference(_ key: String, value: String) throws {
    try db.execute(
      "INSERT INTO preferences(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
      [key, value])
  }
  /// Commit related presentation choices together, so storage failure cannot save half a layout.
  public func setPreferences(_ values: [String: String]) throws {
    try db.transaction {
      for (key, value) in values { try setPreference(key, value: value) }
    }
  }
  public func worlds() throws -> [World] {
    try db.rows("SELECT * FROM worlds WHERE owner_id='local' ORDER BY created_at,rowid").map {
      World(
        id: $0["id"]!, name: $0["name"]!, description: $0["description"]!, demo: $0["demo"] == "1")
    }
  }
  public func world(_ id: String) throws -> World {
    guard let world = try worlds().first(where: { $0.id == id }) else {
      throw SynthesisError.notFound
    }
    return world
  }
  public func createWorld(name: String, description: String = "", demo: Bool = false) throws
    -> World
  {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= 100 else {
      throw SynthesisError.invalid("Give your world a name of up to 100 characters.")
    }
    let id = UUID().uuidString
    let now = timestamp()
    try db.execute(
      "INSERT INTO worlds VALUES(?,'local',?,?,?,?,?)",
      [id, name, description, demo ? "1" : "0", now, now])
    return try world(id)
  }
  public func renameWorld(_ id: String, name: String) throws -> World {
    _ = try world(id)
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= 100 else {
      throw SynthesisError.invalid("Give your world a name of up to 100 characters.")
    }
    try db.execute("UPDATE worlds SET name=?,updated_at=? WHERE id=?", [name, timestamp(), id])
    return try world(id)
  }
  func decodeRecord(_ row: [String: String]) -> LoreRecord {
    LoreRecord(
      id: row["id"]!, worldID: row["world_id"]!, title: row["title"]!, body: row["body"]!,
      kind: row["kind"]!, category: row["category"]!, state: row["state"]!, origin: row["origin"]!,
      version: Int(row["version"]!)!, canonical: row["canonical"], rtf: row["rtf"],
      updatedAt: row["updated_at"]!,
      tags: (try? JSONDecoder().decode([String].self, from: Data((row["tags"] ?? "[]").utf8))),
      aliases: (try? JSONDecoder().decode([String].self, from: Data((row["aliases"] ?? "[]").utf8)))
    )
  }
  public func records(worldID: String) throws -> [LoreRecord] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT r.*,d.rtf FROM records r LEFT JOIN rich_documents d ON d.record_id=r.id WHERE r.world_id=? AND r.archived=0 ORDER BY r.updated_at DESC,r.rowid DESC",
      [worldID]
    ).map(decodeRecord)
  }
  /// Archived records stay resolvable by ID so links, revisions and canon snapshots survive.
  public func archivedRecords(worldID: String) throws -> [LoreRecord] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT r.*,d.rtf FROM records r LEFT JOIN rich_documents d ON d.record_id=r.id WHERE r.world_id=? AND r.archived=1 ORDER BY r.updated_at DESC,r.rowid DESC",
      [worldID]
    ).map(decodeRecord)
  }
  public func isArchived(worldID: String, recordID: String) throws -> Bool {
    try db.rows("SELECT archived FROM records WHERE world_id=? AND id=?", [worldID, recordID])
      .first?["archived"] == "1"
  }
  /// Reversible removal. Content, version, canon snapshot and history are untouched.
  public func archiveRecord(worldID: String, id: String) throws {
    _ = try record(worldID: worldID, id: id)
    try db.execute("UPDATE records SET archived=1 WHERE world_id=? AND id=?", [worldID, id])
  }
  public func restoreRecord(worldID: String, id: String) throws {
    _ = try record(worldID: worldID, id: id)
    try db.execute("UPDATE records SET archived=0 WHERE world_id=? AND id=?", [worldID, id])
  }
  public func record(worldID: String, id: String) throws -> LoreRecord {
    _ = try world(worldID)
    guard
      let row = try db.rows(
        "SELECT r.*,d.rtf FROM records r LEFT JOIN rich_documents d ON d.record_id=r.id WHERE r.world_id=? AND r.id=?",
        [worldID, id]
      ).first
    else { throw SynthesisError.notFound }
    return decodeRecord(row)
  }
  private func snapshot(_ r: LoreRecord) throws {
    let data = try JSONEncoder().encode(r)
    try db.execute(
      "INSERT INTO native_revisions VALUES(?,?,?,?,?,?)",
      [
        UUID().uuidString, r.worldID, r.id, String(r.version),
        String(decoding: data, as: UTF8.self), timestamp(),
      ])
  }
  public func createRecord(
    worldID: String, title: String, body: String = "", kind: String = "lore", category: String = "",
    origin: String = "user-authored"
  ) throws -> LoreRecord {
    _ = try world(worldID)
    guard ["lore", "entity", "capture"].contains(kind),
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 160,
      body.count <= 200000
    else {
      throw SynthesisError.invalid("Choose a title and keep the document under 200,000 characters.")
    }
    return try db.transaction {
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        "INSERT INTO records(id,world_id,kind,title,body,category,tags,aliases,state,origin,canonical,version,created_at,updated_at) VALUES(?,?,?,?,?,?,'[]','[]',?,?,NULL,1,?,?)",
        [
          id, worldID, kind, title, body, category, kind == "capture" ? "idea" : "draft", origin,
          now, now,
        ])
      let r = try record(worldID: worldID, id: id)
      try snapshot(r)
      return r
    }
  }
  public func saveRecord(
    worldID: String, id: String, version: Int, title: String, body: String, rtf: String?,
    category: String? = nil, tags: [String]? = nil, aliases: [String]? = nil
  ) throws -> LoreRecord {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 160,
      body.count <= 200000, (rtf?.count ?? 0) < 4_000_000
    else {
      throw SynthesisError.invalid(
        "A title is required. Keep the document under 200,000 characters.")
    }
    return try db.transaction {
      let current = try record(worldID: worldID, id: id)
      guard current.version == version else { throw SynthesisError.stale }
      try db.execute(
        "UPDATE records SET title=?,body=?,category=?,state=?,version=version+1,updated_at=? WHERE id=? AND world_id=?",
        [
          title, body, category ?? current.category, current.kind == "capture" ? "idea" : "draft",
          timestamp(), id, worldID,
        ])
      if let rtf {
        try db.execute(
          "INSERT INTO rich_documents VALUES(?,?) ON CONFLICT(record_id) DO UPDATE SET rtf=excluded.rtf",
          [id, rtf])
      } else {
        try db.execute("DELETE FROM rich_documents WHERE record_id=?", [id])
      }
      if tags != nil || aliases != nil {
        let encoder = JSONEncoder()
        try db.execute(
          "UPDATE records SET tags=?,aliases=? WHERE id=? AND world_id=?",
          [
            String(decoding: try encoder.encode(tags ?? current.tags ?? []), as: UTF8.self),
            String(decoding: try encoder.encode(aliases ?? current.aliases ?? []), as: UTF8.self),
            id, worldID,
          ])
      }
      let r = try record(worldID: worldID, id: id)
      try snapshot(r)
      return r
    }
  }
  public func restoreRevision(worldID: String, id: String, version: Int, revisionID: String) throws
    -> LoreRecord
  {
    guard let revision = try history(worldID: worldID, id: id).first(where: { $0.id == revisionID })
    else { throw SynthesisError.notFound }
    let r = revision.snapshot
    return try saveRecord(
      worldID: worldID, id: id, version: version, title: r.title, body: r.body, rtf: r.rtf,
      category: r.category, tags: r.tags ?? [], aliases: r.aliases ?? [])
  }
  public func convertCapture(worldID: String, id: String) throws -> LoreRecord {
    try db.transaction {
      let r = try record(worldID: worldID, id: id)
      if r.kind == "lore" { return r }
      guard r.kind == "capture" else {
        throw SynthesisError.invalid("Only an inbox idea can be converted.")
      }
      try db.execute(
        "UPDATE records SET kind='lore',state='draft',version=version+1,updated_at=? WHERE id=?",
        [timestamp(), id])
      let updated = try record(worldID: worldID, id: id)
      try snapshot(updated)
      return updated
    }
  }
  public func promote(worldID: String, id: String, version: Int, confirmation: String) throws
    -> LoreRecord
  {
    guard confirmation == id else {
      throw SynthesisError.invalid("Explicit approval of this exact record is required.")
    }
    return try db.transaction {
      let r = try record(worldID: worldID, id: id)
      guard r.version == version else { throw SynthesisError.stale }
      guard try !isArchived(worldID: worldID, recordID: id) else {
        throw SynthesisError.invalid("Restore this record before reviewing it for canon.")
      }
      guard r.kind != "capture" else {
        throw SynthesisError.invalid("Convert this idea into a document before canon review.")
      }
      var canonicalRecord = r
      canonicalRecord.canonical = nil
      let canonical = String(decoding: try JSONEncoder().encode(canonicalRecord), as: UTF8.self)
      try db.execute(
        "UPDATE records SET state='canon',canonical=?,version=version+1,updated_at=? WHERE id=?",
        [canonical, timestamp(), id])
      let accepted = try record(worldID: worldID, id: id)
      try snapshot(accepted)
      return accepted
    }
  }
  public func history(worldID: String, id: String) throws -> [RecordRevision] {
    _ = try record(worldID: worldID, id: id)
    return try db.rows(
      "SELECT * FROM native_revisions WHERE world_id=? AND record_id=? ORDER BY version DESC",
      [worldID, id]
    ).map {
      RecordRevision(
        id: $0["id"]!, version: Int($0["version"]!)!,
        snapshot: try JSONDecoder().decode(LoreRecord.self, from: Data($0["snapshot"]!.utf8)),
        createdAt: $0["created_at"]!)
    }
  }
  public func conversations(worldID: String, archived: Bool = false) throws -> [Conversation] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT * FROM conversations WHERE world_id=? AND archived=? ORDER BY updated_at DESC,rowid DESC",
      [worldID, archived ? "1" : "0"]
    ).map {
      Conversation(
        id: $0["id"]!, worldID: worldID, title: $0["title"]!, updatedAt: $0["updated_at"]!)
    }
  }
  public func createConversation(worldID: String, title: String = "New conversation") throws
    -> Conversation
  {
    _ = try world(worldID)
    let id = UUID().uuidString
    let now = timestamp()
    try db.execute(
      "INSERT INTO conversations(id,world_id,title,created_at,updated_at) VALUES(?,?,?,?,?)",
      [id, worldID, String(title.prefix(120)), now, now])
    return Conversation(id: id, worldID: worldID, title: String(title.prefix(120)), updatedAt: now)
  }
  public func renameConversation(worldID: String, id: String, title: String) throws {
    _ = try messages(worldID: worldID, conversationID: id)
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SynthesisError.invalid("A conversation needs a name.")
    }
    try db.execute(
      "UPDATE conversations SET title=?,updated_at=? WHERE id=? AND world_id=?",
      [String(title.prefix(120)), timestamp(), id, worldID])
  }
  public func setConversationArchived(worldID: String, id: String, archived: Bool) throws {
    _ = try messages(worldID: worldID, conversationID: id)
    try db.execute(
      "UPDATE conversations SET archived=? WHERE id=? AND world_id=?",
      [archived ? "1" : "0", id, worldID])
  }
  public func messages(worldID: String, conversationID: String) throws -> [ChatMessage] {
    _ = try world(worldID)
    guard
      try !db.rows(
        "SELECT id FROM conversations WHERE id=? AND world_id=?", [conversationID, worldID]
      ).isEmpty
    else { throw SynthesisError.notFound }
    return try db.rows(
      "SELECT * FROM messages WHERE conversation_id=? AND world_id=? ORDER BY rowid",
      [conversationID, worldID]
    ).map {
      ChatMessage(
        id: $0["id"]!, worldID: worldID, conversationID: conversationID, role: $0["role"]!,
        body: $0["body"]!, state: $0["state"]!)
    }
  }
  @discardableResult public func appendMessage(
    worldID: String, conversationID: String, role: String, body: String, state: String
  ) throws -> ChatMessage {
    _ = try messages(worldID: worldID, conversationID: conversationID)
    guard ["user", "assistant", "system"].contains(role), body.count <= 300000 else {
      throw SynthesisError.invalid("Invalid message.")
    }
    let id = UUID().uuidString
    let now = timestamp()
    try db.execute(
      "INSERT INTO messages VALUES(?,?,?,?,?,?,?,?)",
      [id, worldID, conversationID, role, body, state, now, now])
    try db.execute("UPDATE conversations SET updated_at=? WHERE id=?", [now, conversationID])
    return ChatMessage(
      id: id, worldID: worldID, conversationID: conversationID, role: role, body: body, state: state
    )
  }
  public func addRelation(
    worldID: String, source: String, target: String, label: String,
    origin: String = "user-authored", attributes: RelationshipAttributes = .init()
  ) throws -> Relation {
    let value = try relationshipLabel(label)
    let attributes = try attributes.validated()
    return try db.transaction {
      let a = try record(worldID: worldID, id: source)
      let b = try record(worldID: worldID, id: target)
      guard a.kind == "entity", b.kind == "entity", source != target,
        try !isArchived(worldID: worldID, recordID: source),
        try !isArchived(worldID: worldID, recordID: target)
      else { throw SynthesisError.invalid("Choose two different available entities.") }
      try validateRelationshipEvidence(worldID: worldID, attributes: attributes)
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        "INSERT INTO relationships(id,world_id,source_id,target_id,label,state,origin,created_at,updated_at,attributes) VALUES(?,?,?,?,?,'draft',?,?,?,?)",
        [id, worldID, source, target, value, origin, now, now, try attributes.encodeStored()])
      return Relation(
        id: id, sourceID: source, targetID: target, label: value, attributes: attributes)
    }
  }

  private static let visibleRelationships = """
    SELECT r.* FROM relationships r
    JOIN records a ON a.id=r.source_id AND a.world_id=r.world_id
    JOIN records b ON b.id=r.target_id AND b.world_id=r.world_id
    WHERE r.world_id=? AND r.archived=0 AND a.archived=0 AND b.archived=0
    """

  public func relations(worldID: String) throws -> [Relation] {
    _ = try world(worldID)
    return try db.rows(
      Self.visibleRelationships + " ORDER BY r.created_at,r.rowid",
      [worldID]
    ).map(decodeRelationship)
  }

  /// An outgoing edge is visible from both of its endpoints without saving a second edge.
  public func relations(worldID: String, recordID: String) throws -> [Relation] {
    _ = try record(worldID: worldID, id: recordID)
    return try db.rows(
      Self.visibleRelationships
        + " AND (r.source_id=? OR r.target_id=?) ORDER BY r.created_at,r.rowid",
      [worldID, recordID, recordID]
    ).map(decodeRelationship)
  }

  public func updateRelation(worldID: String, id: String, label: String) throws {
    try db.transaction {
      let current = try visibleRelationship(worldID: worldID, id: id)
      _ = try saveRelationship(
        worldID: worldID, current: current, label: label, attributes: current.attributes)
    }
  }

  /// Save against the version the creator opened, even if two edits share a timestamp.
  @discardableResult public func updateRelation(
    worldID: String, expected: Relation, label: String, attributes: RelationshipAttributes
  ) throws -> Relation {
    try db.transaction {
      let current = try visibleRelationship(worldID: worldID, id: expected.id)
      guard current == expected else { throw SynthesisError.stale }
      return try saveRelationship(
        worldID: worldID, current: current, label: label, attributes: attributes)
    }
  }

  public func archiveRelation(worldID: String, id: String, expected: Relation? = nil) throws {
    try db.transaction {
      let relation = try visibleRelationship(worldID: worldID, id: id)
      if let expected, expected != relation { throw SynthesisError.stale }
      try requireDraftRelationship(relation)
      try archiveRelationSnapshot(worldID: worldID, relation: relation, action: "archive")
      try db.execute(
        "UPDATE relationships SET archived=1,updated_at=?,revision=revision+1 WHERE id=? AND world_id=?",
        [timestamp(), id, worldID])
    }
  }

  public func restoreRelation(worldID: String, id: String) throws {
    _ = try world(worldID)
    try db.transaction {
      guard
        try !db.rows(
          "SELECT id FROM relationships WHERE world_id=? AND id=? AND archived=1", [worldID, id]
        ).isEmpty
      else { throw SynthesisError.notFound }
      try db.execute(
        "UPDATE relationships SET archived=0,updated_at=?,revision=revision+1 WHERE id=? AND world_id=?",
        [timestamp(), id, worldID])
    }
  }

  private func relationshipLabel(_ label: String) throws -> String {
    let value = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.count <= 80, !value.contains("\0") else {
      throw SynthesisError.invalid("Use a relationship label of 1–80 characters.")
    }
    return value
  }

  private func requireDraftRelationship(_ relation: Relation) throws {
    guard relation.state == "draft" else {
      throw SynthesisError.invalid(
        "Canonical relationships require a reviewed revision. This connection was not changed.")
    }
  }

  private func decodeRelationship(_ row: [String: String]) throws -> Relation {
    Relation(
      id: row["id"]!, sourceID: row["source_id"]!, targetID: row["target_id"]!,
      label: row["label"]!, attributes: try RelationshipAttributes.decodeStored(row["attributes"]!),
      state: row["state"]!, revision: Int(row["revision"]!)!)
  }

  private func visibleRelationship(worldID: String, id: String) throws -> Relation {
    _ = try world(worldID)
    guard
      let row = try db.rows(Self.visibleRelationships + " AND r.id=?", [worldID, id]).first
    else { throw SynthesisError.notFound }
    return try decodeRelationship(row)
  }

  private func validateRelationshipEvidence(
    worldID: String, attributes: RelationshipAttributes, allowedArchived: Set<String> = []
  ) throws {
    let ids = attributes.evidenceRecordIDs
    guard !ids.isEmpty else { return }
    let placeholders = ids.map { _ in "?" }.joined(separator: ",")
    let rows = try db.rows(
      "SELECT id,archived FROM records WHERE world_id=? AND id IN (\(placeholders))",
      [worldID] + ids)
    guard rows.count == ids.count,
      rows.allSatisfy({ $0["archived"] == "0" || $0["id"].map(allowedArchived.contains) == true })
    else {
      throw SynthesisError.invalid("Choose evidence from available records in this world.")
    }
  }

  private func saveRelationship(
    worldID: String, current: Relation, label: String, attributes: RelationshipAttributes
  ) throws -> Relation {
    try requireDraftRelationship(current)
    let value = try relationshipLabel(label)
    let attributes = try attributes.validated()
    guard value != current.label || attributes != current.attributes else { return current }
    try validateRelationshipEvidence(
      worldID: worldID, attributes: attributes,
      allowedArchived: Set(current.attributes.evidenceRecordIDs))
    try archiveRelationSnapshot(
      worldID: worldID, relation: current,
      action: attributes == current.attributes ? "rename" : "edit")
    try db.execute(
      "UPDATE relationships SET label=?,attributes=?,updated_at=?,revision=revision+1 WHERE id=? AND world_id=?",
      [value, try attributes.encodeStored(), timestamp(), current.id, worldID])
    return try visibleRelationship(worldID: worldID, id: current.id)
  }

  private func archiveRelationSnapshot(worldID: String, relation: Relation, action: String) throws {
    try db.execute(
      "INSERT INTO relationship_history(id,world_id,relationship_id,source_id,target_id,label,action,created_at,attributes,revision) VALUES(?,?,?,?,?,?,?,?,?,?)",
      [
        UUID().uuidString, worldID, relation.id, relation.sourceID, relation.targetID,
        relation.label, action, timestamp(), try relation.attributes.encodeStored(),
        String(relation.revision),
      ])
  }

  func validateRelationshipArchive(worldID: String) throws {
    let known = Set(
      try db.rows("SELECT id FROM records WHERE world_id=?", [worldID]).compactMap { $0["id"] })
    let attributes = try db.rows(
      """
      SELECT attributes FROM relationships WHERE world_id=?
      UNION ALL SELECT attributes FROM relationship_history WHERE world_id=?
      """, [worldID, worldID])
    for row in attributes {
      let value = try RelationshipAttributes.decodeStored(row["attributes"]!)
      guard value.evidenceRecordIDs.allSatisfy(known.contains) else {
        throw SynthesisError.invalid(
          "The world file contains relationship evidence outside this world.")
      }
    }
    guard
      try db.rows(
        """
        SELECT h.id FROM relationship_history h
        LEFT JOIN relationships r ON r.id=h.relationship_id AND r.world_id=h.world_id
        WHERE h.world_id=? AND (r.id IS NULL OR r.source_id<>h.source_id OR r.target_id<>h.target_id)
        LIMIT 1
        """, [worldID]
      ).isEmpty
    else { throw SynthesisError.invalid("The world file contains invalid relationship history.") }
  }

  public func addEvent(
    worldID: String, title: String, date: String, source: String, order: Int? = nil,
    origin: String = "user-authored"
  ) throws -> WorldEvent {
    _ = try record(worldID: worldID, id: source)
    guard !title.isEmpty, title.count <= 160, date.count <= 160 else {
      throw SynthesisError.invalid("Give the event a short title and date label.")
    }
    let id = UUID().uuidString
    let now = timestamp()
    let label = date.isEmpty ? "unknown" : date
    try db.execute(
      "INSERT INTO events(id,world_id,title,date_label,sort_order,source_id,body,origin,created_at,updated_at) VALUES(?,?,?,?,?,?,'',?,?,?)",
      [id, worldID, title, label, order.map(String.init), source, origin, now, now])
    return WorldEvent(id: id, title: title, dateLabel: label, sourceID: source, order: order)
  }
  public func events(worldID: String) throws -> [WorldEvent] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT * FROM events WHERE world_id=? AND archived=0 ORDER BY sort_order IS NULL,sort_order,created_at,rowid",
      [worldID]
    ).map {
      WorldEvent(
        id: $0["id"]!, title: $0["title"]!, dateLabel: $0["date_label"]!,
        sourceID: $0["source_id"]!, order: $0["sort_order"].flatMap(Int.init))
    }
  }
  public func updateEvent(
    worldID: String, id: String, title: String, date: String, source: String, order: Int?
  ) throws -> WorldEvent {
    _ = try record(worldID: worldID, id: source)
    guard try !db.rows("SELECT id FROM events WHERE world_id=? AND id=?", [worldID, id]).isEmpty
    else { throw SynthesisError.notFound }
    guard !title.isEmpty, title.count <= 160, date.count <= 160 else {
      throw SynthesisError.invalid("Give the event a short title and date label.")
    }
    let label = date.isEmpty ? "unknown" : date
    try db.execute(
      "UPDATE events SET title=?,date_label=?,sort_order=?,source_id=?,updated_at=? WHERE world_id=? AND id=?",
      [title, label, order.map(String.init), source, timestamp(), worldID, id])
    return WorldEvent(id: id, title: title, dateLabel: label, sourceID: source, order: order)
  }
  /// Reversible removal of a chronology entry; the row and its source reference are kept.
  public func setEventArchived(worldID: String, id: String, archived: Bool) throws {
    _ = try world(worldID)
    guard try !db.rows("SELECT id FROM events WHERE world_id=? AND id=?", [worldID, id]).isEmpty
    else { throw SynthesisError.notFound }
    try db.execute(
      "UPDATE events SET archived=?,updated_at=? WHERE world_id=? AND id=?",
      [archived ? "1" : "0", timestamp(), worldID, id])
  }
  public func saveBoard(
    worldID: String, id: String? = nil, name: String, kind: String, content: String
  ) throws -> Board {
    _ = try world(worldID)
    guard content.utf8.count <= 12_000_000, ["canvas", "atlas"].contains(kind) else {
      throw SynthesisError.invalid("Workspace is too large or has an unknown type.")
    }
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 120 else {
      throw SynthesisError.invalid("Give the board a name of up to 120 characters.")
    }
    if let id {
      guard
        try !db.rows(
          "SELECT id FROM boards WHERE id=? AND world_id=? AND kind=?", [id, worldID, kind]
        ).isEmpty
      else { throw SynthesisError.notFound }
    }
    let actual = id ?? UUID().uuidString
    let now = timestamp()
    try db.execute(
      "INSERT INTO boards(id,world_id,name,content,kind,created_at,updated_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,content=excluded.content,updated_at=excluded.updated_at",
      [actual, worldID, name, content, kind, now, now])
    return Board(id: actual, name: name, kind: kind, content: content)
  }
  public func boards(worldID: String, kind: String, archived: Bool = false) throws -> [Board] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT * FROM boards WHERE world_id=? AND kind=? AND archived=? ORDER BY created_at,rowid",
      [worldID, kind, archived ? "1" : "0"]
    ).map { Board(id: $0["id"]!, name: $0["name"]!, kind: $0["kind"]!, content: $0["content"]!) }
  }
  public func setBoardArchived(worldID: String, id: String, archived: Bool) throws {
    _ = try world(worldID)
    guard try !db.rows("SELECT id FROM boards WHERE id=? AND world_id=?", [id, worldID]).isEmpty
    else { throw SynthesisError.notFound }
    try db.execute(
      "UPDATE boards SET archived=?,updated_at=? WHERE id=? AND world_id=?",
      [archived ? "1" : "0", timestamp(), id, worldID])
  }
  public func archiveCanvasBoard(worldID: String, id: String, blankContent: String) throws -> String
  {
    try db.transaction {
      let active = try db.rows(
        "SELECT id FROM boards WHERE world_id=? AND kind='canvas' AND archived=0 ORDER BY created_at,rowid",
        [worldID]
      ).compactMap { $0["id"] }
      guard active.contains(id) else { throw SynthesisError.notFound }
      try setBoardArchived(worldID: worldID, id: id, archived: true)
      if let next = active.first(where: { $0 != id }) { return next }
      return try saveBoard(
        worldID: worldID, name: "Untitled board", kind: "canvas", content: blankContent
      ).id
    }
  }
  public func unlinkRecord(worldID: String, source: String, target: String) throws {
    _ = try world(worldID)
    try db.execute(
      "DELETE FROM links WHERE world_id=? AND source_id=? AND target_id=?",
      [worldID, source, target])
  }
  public func linkRecord(worldID: String, source: String, target: String) throws {
    _ = try record(worldID: worldID, id: source)
    _ = try record(worldID: worldID, id: target)
    guard source != target else { throw SynthesisError.invalid("Choose another record to link.") }
    let now = timestamp()
    try db.execute(
      "INSERT OR IGNORE INTO links VALUES(?,?,?,?,?,?)",
      [UUID().uuidString, worldID, source, target, now, now])
  }
  public func linkedRecords(worldID: String, id: String, incoming: Bool = false) throws
    -> [LoreRecord]
  {
    _ = try record(worldID: worldID, id: id)
    let rows = try db.rows(
      incoming
        ? "SELECT l.source_id AS id FROM links l JOIN records r ON r.id=l.source_id WHERE l.world_id=? AND l.target_id=? AND r.archived=0 ORDER BY l.created_at,l.rowid"
        : "SELECT l.target_id AS id FROM links l JOIN records r ON r.id=l.target_id WHERE l.world_id=? AND l.source_id=? AND r.archived=0 ORDER BY l.created_at,l.rowid",
      [worldID, id])
    return try rows.map { try record(worldID: worldID, id: $0["id"]!) }
  }
  public func metadata(worldID: String, id: String) throws -> (tags: [String], aliases: [String]) {
    _ = try record(worldID: worldID, id: id)
    let row = try db.rows(
      "SELECT tags,aliases FROM records WHERE world_id=? AND id=?", [worldID, id]
    ).first!
    func list(_ key: String) -> [String] {
      (try? JSONDecoder().decode([String].self, from: Data((row[key] ?? "[]").utf8))) ?? []
    }
    return (list("tags"), list("aliases"))
  }
  public func saveMetadata(
    worldID: String, id: String, version: Int, tags: [String], aliases: [String]
  ) throws -> LoreRecord {
    guard tags.count <= 30, aliases.count <= 30, (tags + aliases).allSatisfy({ $0.count <= 100 })
    else { throw SynthesisError.invalid("Use up to 30 short tags or aliases.") }
    return try db.transaction {
      let r = try record(worldID: worldID, id: id)
      guard r.version == version else { throw SynthesisError.stale }
      let encoder = JSONEncoder()
      try db.execute(
        "UPDATE records SET tags=?,aliases=?,state=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
        [
          String(decoding: try encoder.encode(tags), as: UTF8.self),
          String(decoding: try encoder.encode(aliases), as: UTF8.self),
          r.kind == "capture" ? "idea" : "draft", timestamp(), worldID, id,
        ])
      let updated = try record(worldID: worldID, id: id)
      try snapshot(updated)
      return updated
    }
  }
  public func exportWorld(_ id: String) throws -> Data {
    struct Export: Codable {
      var schemaVersion = 15
      var world: World
      var records: [LoreRecord]
      var conversations: [Conversation]
      var messages: [ChatMessage]
      var relationships: [Relation]
      var relationshipHistory: [[String: String]]
      var archivedRelationships: [[String: String]]
      var hiddenRelationships: [[String: String]]
      var events: [WorldEvent]
      var boards: [Board]
      var revisions: [RecordRevision]
      var links: [[String: String]]
      var metadata: [[String: String]]
      var archivedRecordIDs: [String]
      var archivedConversationIDs: [String]
      var archivedBoards: [Board]
      var archivedEvents: [[String: String]]
      var proposals: [Proposal]
      var messageContext: [[String: String]]
      var rules: [[String: String]]
      var ruleHistory: [[String: String]]
      var ruleScenarios: [[String: String]]
      var rulePrerequisites: [[String: String]]
      var chronology: [[String: String]]
      var chronologyPlacements: [[String: String]]
      var recordSections: [[String: String]]
      var creativeComponents: [[String: String]]
      var recordArtwork: [[String: String]]
      var activityHistory: [[String: String]]
      var entityTypes: [[String: String]]
      var entityProfiles: [[String: String]]
      var entityProfileHistory: [[String: String]]
      var entityTypeHistory: [[String: String]]
      var entityTemplates: [[String: String]]
      var entityTemplateHistory: [[String: String]]
      var entityNamePeriods: [[String: String]]
      var entityNamePeriodHistory: [[String: String]]
      var conversationBranches: [[String: String]]
      var conversationMessageOrigins: [[String: String]]
      var promptRecipes: [[String: String]]
    }
    // Archived material is exported too: archiving hides, it never discards.
    let hiddenChats = try conversations(worldID: id, archived: true)
    let hiddenPages = try archivedRecords(worldID: id)
    let chats = try conversations(worldID: id) + hiddenChats
    let pages = try records(worldID: id) + hiddenPages
    let export = try Export(
      world: world(id), records: pages, conversations: chats,
      messages: chats.flatMap { try messages(worldID: id, conversationID: $0.id) },
      relationships: relations(worldID: id),
      relationshipHistory: db.rows("SELECT * FROM relationship_history WHERE world_id=?", [id]),
      archivedRelationships: db.rows(
        "SELECT * FROM relationships WHERE world_id=? AND archived=1", [id]),
      hiddenRelationships: db.rows(
        """
        SELECT r.* FROM relationships r
        JOIN records a ON a.id=r.source_id AND a.world_id=r.world_id
        JOIN records b ON b.id=r.target_id AND b.world_id=r.world_id
        WHERE r.world_id=? AND r.archived=0 AND (a.archived=1 OR b.archived=1)
        """, [id]),
      events: events(worldID: id),
      boards: boards(worldID: id, kind: "canvas") + boards(worldID: id, kind: "atlas"),
      revisions: pages.flatMap { try history(worldID: id, id: $0.id) },
      links: db.rows("SELECT * FROM links WHERE world_id=?", [id]),
      metadata: db.rows("SELECT id,tags,aliases FROM records WHERE world_id=?", [id]),
      archivedRecordIDs: hiddenPages.map(\.id), archivedConversationIDs: hiddenChats.map(\.id),
      archivedBoards: boards(worldID: id, kind: "canvas", archived: true)
        + boards(worldID: id, kind: "atlas", archived: true),
      archivedEvents: db.rows("SELECT * FROM events WHERE world_id=? AND archived=1", [id]),
      proposals: proposals(worldID: id),
      messageContext: db.rows("SELECT * FROM message_context WHERE world_id=?", [id]),
      rules: db.rows("SELECT * FROM rules WHERE world_id=?", [id]),
      ruleHistory: db.rows("SELECT * FROM rule_history WHERE world_id=?", [id]),
      ruleScenarios: db.rows("SELECT * FROM rule_scenarios WHERE world_id=?", [id]),
      rulePrerequisites: db.rows("SELECT * FROM rule_prerequisites WHERE world_id=?", [id]),
      chronology: db.rows("SELECT * FROM chronology_lanes WHERE world_id=?", [id]),
      chronologyPlacements: db.rows("SELECT * FROM chronology_placements WHERE world_id=?", [id]),
      recordSections: db.rows(
        "SELECT * FROM record_sections WHERE world_id=? ORDER BY parent_id,position", [id]),
      creativeComponents: db.rows("SELECT * FROM creative_components WHERE world_id=?", [id]),
      recordArtwork: db.rows("SELECT * FROM record_artwork WHERE world_id=?", [id]),
      activityHistory: db.rows(
        "SELECT * FROM world_activity WHERE world_id=? ORDER BY rowid", [id]),
      entityTypes: db.rows("SELECT * FROM entity_types WHERE world_id=?", [id]),
      entityProfiles: db.rows("SELECT * FROM entity_profiles WHERE world_id=?", [id]),
      entityProfileHistory: db.rows("SELECT * FROM entity_profile_history WHERE world_id=?", [id]),
      entityTypeHistory: db.rows("SELECT * FROM entity_type_history WHERE world_id=?", [id]),
      entityTemplates: db.rows("SELECT * FROM entity_templates WHERE world_id=?", [id]),
      entityTemplateHistory: db.rows(
        "SELECT * FROM entity_template_history WHERE world_id=?", [id]),
      entityNamePeriods: db.rows(
        "SELECT * FROM entity_name_periods WHERE world_id=? ORDER BY rowid", [id]),
      entityNamePeriodHistory: db.rows(
        "SELECT * FROM entity_name_period_history WHERE world_id=? ORDER BY rowid", [id]),
      conversationBranches: db.rows("SELECT * FROM conversation_branches WHERE world_id=?", [id]),
      conversationMessageOrigins: db.rows(
        "SELECT * FROM conversation_message_origins WHERE world_id=?", [id]),
      promptRecipes: db.rows("SELECT * FROM prompt_recipes WHERE world_id=?", [id])
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(export)
  }
}
