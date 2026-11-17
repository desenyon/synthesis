import Foundation

/// A closed presentation vocabulary, never agent-authored executable UI.
public enum CreativeKind: String, CaseIterable, Codable, Sendable {
  case notes, facts, checklist, progression
}
public enum CreativeScope: String, CaseIterable, Codable, Sendable {
  case conversation, canvas, library, graph, timeline, atlas, review, entity
}
public struct CreativeComponent: Identifiable, Sendable {
  public var id: String
  public var record: LoreRecord
  public var parentID: String?
  public var scope: CreativeScope
  public var kind: CreativeKind
  public var archived: Bool
}

extension WorkspaceStore {
  public func creativeComponents(worldID: String, archived: Bool = false) throws
    -> [CreativeComponent]
  {
    try db.rows(
      "SELECT c.*,r.archived AS record_archived FROM creative_components c JOIN records r ON r.id=c.record_id AND r.world_id=c.world_id LEFT JOIN records p ON p.id=c.parent_id AND p.world_id=c.world_id WHERE c.world_id=? AND c.archived=? AND r.archived=0 AND (c.parent_id IS NULL OR p.archived=0) ORDER BY c.created_at,c.rowid",
      [worldID, archived ? "1" : "0"]
    ).map { row in
      guard let scope = CreativeScope(rawValue: row["scope"] ?? ""),
        let kind = CreativeKind(rawValue: row["kind"] ?? "")
      else {
        throw SynthesisError.invalid("Unknown creative component format.")
      }
      return CreativeComponent(
        id: row["id"]!, record: try record(worldID: worldID, id: row["record_id"]!),
        parentID: row["parent_id"], scope: scope, kind: kind, archived: archived)
    }
  }

  @discardableResult public func createCreativeComponent(
    worldID: String, scope: CreativeScope, kind: CreativeKind, parentID: String? = nil,
    title: String, body: String = "", origin: String = "user-authored"
  ) throws -> CreativeComponent {
    try db.transaction {
      guard (scope == .entity) == (parentID != nil) else {
        throw SynthesisError.invalid(
          "Entity components need a parent; workspace components do not.")
      }
      let content: LoreRecord
      if let parentID {
        content = try createRecordSection(
          worldID: worldID, parentID: parentID, title: title, body: body, origin: origin
        ).record
      } else {
        content = try createRecord(
          worldID: worldID, title: title, body: body, kind: "lore", category: "Workspace notes",
          origin: origin)
      }
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        "INSERT INTO creative_components VALUES(?,?,?,?,?,?,0,?,?)",
        [id, worldID, content.id, parentID, scope.rawValue, kind.rawValue, now, now])
      return CreativeComponent(
        id: id, record: content, parentID: parentID, scope: scope, kind: kind, archived: false)
    }
  }

  public func setCreativeComponentArchived(worldID: String, id: String, archived: Bool) throws {
    guard
      try !db.rows("SELECT id FROM creative_components WHERE id=? AND world_id=?", [id, worldID])
        .isEmpty
    else { throw SynthesisError.notFound }
    try db.execute(
      "UPDATE creative_components SET archived=?,updated_at=? WHERE id=? AND world_id=?",
      [archived ? "1" : "0", timestamp(), id, worldID])
  }

  /// A checkbox is a revisioned draft edit. Never overwrites a rich document or accepted canon.
  public func toggleCreativeCheck(worldID: String, id: String, version: Int, line: Int) throws {
    try db.transaction {
      guard let component = try creativeComponents(worldID: worldID).first(where: { $0.id == id }),
        component.kind == .checklist
      else { throw SynthesisError.notFound }
      let record = component.record
      guard record.version == version else { throw SynthesisError.stale }
      guard record.rtf == nil else {
        throw SynthesisError.invalid(
          "Edit this rich document in the editor to preserve its formatting.")
      }
      var lines = record.body.components(separatedBy: "\n")
      guard lines.indices.contains(line),
        let checked = CreativeLine(lines[line], index: line).checked
      else { throw SynthesisError.invalid("This line is not a checklist item.") }
      // Replace only the first checkbox marker, preserving indentation and the rest of the text.
      guard let range = lines[line].range(of: checked ? "[x]" : "[ ]", options: .caseInsensitive)
      else { return }
      lines[line].replaceSubrange(range, with: checked ? "[ ]" : "[x]")
      _ = try saveRecord(
        worldID: worldID, id: record.id, version: version, title: record.title,
        body: lines.joined(separator: "\n"), rtf: nil)
    }
  }
}

/// Markdown remains the portable source of truth; rendering never drops unrecognized lines.
public struct CreativeLine: Identifiable, Sendable {
  public var id: Int
  public var text: String
  public var checked: Bool?
  public init(_ raw: String, index: Int) {
    id = index
    text = raw.trimmingCharacters(in: .whitespaces)
    if text.lowercased().hasPrefix("- [x] ") || text.hasPrefix("- [ ] ") {
      checked = text.lowercased().hasPrefix("- [x]")
      text = String(text.dropFirst(6))
    }
  }
}
