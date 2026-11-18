import Foundation

public enum EntityNameKind: String, CaseIterable, Codable, Sendable {
  case name, alias
  public var title: String { rawValue.capitalized }
}

public struct EntityNamePeriodDraft: Equatable, Sendable {
  public var kind: EntityNameKind
  public var name: String
  public var startLabel: String
  public var endLabel: String
  public static let textLimit = 160

  public init(
    kind: EntityNameKind = .name, name: String = "", startLabel: String = "", endLabel: String = ""
  ) {
    self.kind = kind
    self.name = name
    self.startLabel = startLabel
    self.endLabel = endLabel
  }

  private static func validLabel(_ text: String) -> Bool {
    text.count <= textLimit && text.utf8.count <= 2048 && !text.contains("\0")
      && !text.unicodeScalars.contains(where: CharacterSet.newlines.contains)
  }

  fileprivate func validated() throws -> Self {
    guard [name, startLabel, endLabel].allSatisfy(Self.validLabel) else {
      throw SynthesisError.invalid(
        "Use a name and optional date labels of up to \(Self.textLimit) characters each.")
    }
    let value = Self(
      kind: kind, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      startLabel: startLabel.trimmingCharacters(in: .whitespacesAndNewlines),
      endLabel: endLabel.trimmingCharacters(in: .whitespacesAndNewlines))
    guard !value.name.isEmpty else { throw SynthesisError.invalid("Enter a name for this period.") }
    return value
  }
}

/// A name used during a creator-described period. Empty bounds preserve uncertainty.
/// The public title, current aliases and accepted record snapshot are edited separately.
public struct EntityNamePeriod: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let worldID: String
  public let recordID: String
  public let kind: EntityNameKind
  public let name: String
  public let startLabel: String
  public let endLabel: String
  public let revision: Int
  public let archived: Bool
  public let createdAt: String
  public let updatedAt: String

  public var draft: EntityNamePeriodDraft {
    .init(kind: kind, name: name, startLabel: startLabel, endLabel: endLabel)
  }
}

extension WorkspaceStore {
  public func entityNamePeriods(
    worldID: String, recordID: String, archived: Bool = false
  ) throws -> [EntityNamePeriod] {
    try requireEntityNameOwner(worldID: worldID, recordID: recordID)
    return try db.rows(
      "SELECT * FROM entity_name_periods WHERE world_id=? AND record_id=? AND archived=? ORDER BY created_at,rowid",
      [worldID, recordID, archived ? "1" : "0"]
    ).map(decodeEntityNamePeriod)
  }

  @discardableResult public func createEntityNamePeriod(
    worldID: String, recordID: String, draft: EntityNamePeriodDraft
  ) throws -> EntityNamePeriod {
    let value = try draft.validated()
    return try db.transaction {
      try requireEntityNameOwner(worldID: worldID, recordID: recordID, active: true)
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        """
        INSERT INTO entity_name_periods(
          id,world_id,record_id,kind,name,start_label,end_label,created_at,updated_at
        ) VALUES(?,?,?,?,?,?,?,?,?)
        """,
        [
          id, worldID, recordID, value.kind.rawValue, value.name, value.startLabel, value.endLabel,
          now, now,
        ])
      return try entityNamePeriod(worldID: worldID, recordID: recordID, id: id)
    }
  }

  @discardableResult public func updateEntityNamePeriod(
    worldID: String, expected: EntityNamePeriod, draft: EntityNamePeriodDraft
  ) throws -> EntityNamePeriod {
    let value = try draft.validated()
    return try db.transaction {
      let current = try editableEntityNamePeriod(worldID: worldID, expected: expected)
      return try saveEntityNamePeriod(current, draft: value, archived: false)
    }
  }

  @discardableResult public func archiveEntityNamePeriod(
    worldID: String, expected: EntityNamePeriod
  ) throws -> EntityNamePeriod {
    try db.transaction {
      let current = try editableEntityNamePeriod(worldID: worldID, expected: expected)
      return try saveEntityNamePeriod(current, draft: current.draft, archived: true)
    }
  }

  @discardableResult public func restoreEntityNamePeriod(
    worldID: String, recordID: String, id: String, expectedRevision: Int? = nil
  ) throws -> EntityNamePeriod {
    try db.transaction {
      try requireEntityNameOwner(worldID: worldID, recordID: recordID, active: true)
      let current = try entityNamePeriod(worldID: worldID, recordID: recordID, id: id)
      if let expectedRevision, expectedRevision != current.revision { throw SynthesisError.stale }
      guard current.archived else { return current }
      return try saveEntityNamePeriod(current, draft: current.draft, archived: false)
    }
  }

  /// Explicitly changing the working title uses the same versioned draft path as the editor.
  @discardableResult public func updateEntityWorkingTitle(
    worldID: String, expected: LoreRecord, title: String
  ) throws -> LoreRecord {
    try db.transaction {
      guard expected.worldID == worldID else { throw SynthesisError.notFound }
      try requireEntityNameOwner(worldID: worldID, recordID: expected.id, active: true)
      let current = try record(worldID: worldID, id: expected.id)
      guard current == expected else { throw SynthesisError.stale }
      if title == current.title { return current }
      guard !title.contains("\0") else {
        throw SynthesisError.invalid("Enter a valid working title.")
      }
      return try saveRecord(
        worldID: worldID, id: current.id, version: current.version, title: title,
        body: current.body, rtf: current.rtf)
    }
  }

  private func requireEntityNameOwner(
    worldID: String, recordID: String, active: Bool = false
  ) throws {
    let owner = try record(worldID: worldID, id: recordID)
    guard owner.kind == "entity", try (!active || !isArchived(worldID: worldID, recordID: recordID))
    else { throw SynthesisError.invalid("Choose an available entity in this universe.") }
  }

  private func entityNamePeriod(worldID: String, recordID: String, id: String) throws
    -> EntityNamePeriod
  {
    guard
      let row = try db.rows(
        "SELECT * FROM entity_name_periods WHERE world_id=? AND record_id=? AND id=?",
        [worldID, recordID, id]
      ).first
    else { throw SynthesisError.notFound }
    return try decodeEntityNamePeriod(row)
  }

  private func editableEntityNamePeriod(worldID: String, expected: EntityNamePeriod) throws
    -> EntityNamePeriod
  {
    guard expected.worldID == worldID else { throw SynthesisError.notFound }
    try requireEntityNameOwner(worldID: worldID, recordID: expected.recordID, active: true)
    let current = try entityNamePeriod(
      worldID: worldID, recordID: expected.recordID, id: expected.id)
    guard current == expected, !current.archived else { throw SynthesisError.stale }
    return current
  }

  private func decodeEntityNamePeriod(_ row: [String: String]) throws -> EntityNamePeriod {
    guard let id = row["id"], let worldID = row["world_id"], let recordID = row["record_id"],
      let revision = row["revision"].flatMap(Int.init), let createdAt = row["created_at"],
      let updatedAt = row["updated_at"]
    else { throw SynthesisError.invalid("A saved name period could not be read.") }
    let draft = try entityNamePeriodDraft(row)
    return EntityNamePeriod(
      id: id, worldID: worldID, recordID: recordID, kind: draft.kind, name: draft.name,
      startLabel: draft.startLabel, endLabel: draft.endLabel, revision: revision,
      archived: row["archived"] == "1", createdAt: createdAt, updatedAt: updatedAt)
  }

  private func entityNamePeriodDraft(_ row: [String: String]) throws -> EntityNamePeriodDraft {
    guard let kind = row["kind"].flatMap(EntityNameKind.init(rawValue:)), let name = row["name"],
      let startLabel = row["start_label"], let endLabel = row["end_label"]
    else { throw SynthesisError.invalid("A saved name period could not be read.") }
    return .init(kind: kind, name: name, startLabel: startLabel, endLabel: endLabel)
  }

  private func saveEntityNamePeriod(
    _ current: EntityNamePeriod, draft: EntityNamePeriodDraft, archived: Bool
  ) throws -> EntityNamePeriod {
    guard draft != current.draft || archived != current.archived else { return current }
    try db.execute(
      """
      INSERT INTO entity_name_period_history(
        id,world_id,period_id,kind,name,start_label,end_label,revision,archived,updated_at
      ) SELECT ?,world_id,id,kind,name,start_label,end_label,revision,archived,updated_at
      FROM entity_name_periods WHERE world_id=? AND id=?
      """,
      [UUID().uuidString, current.worldID, current.id])
    try db.execute(
      """
      UPDATE entity_name_periods
      SET kind=?,name=?,start_label=?,end_label=?,archived=?,revision=revision+1,updated_at=?
      WHERE world_id=? AND record_id=? AND id=?
      """,
      [
        draft.kind.rawValue, draft.name, draft.startLabel, draft.endLabel, archived ? "1" : "0",
        timestamp(), current.worldID, current.recordID, current.id,
      ])
    return try entityNamePeriod(
      worldID: current.worldID, recordID: current.recordID, id: current.id)
  }

  func validateEntityNameArchive(worldID: String) throws {
    guard
      try db.rows(
        """
        SELECT p.id FROM entity_name_periods p
        JOIN records r ON r.id=p.record_id AND r.world_id=p.world_id
        WHERE p.world_id=? AND r.kind<>'entity' LIMIT 1
        """, [worldID]
      ).isEmpty
    else {
      throw SynthesisError.invalid("A saved name period must belong to an entity.")
    }
    guard
      try db.rows(
        """
        SELECT h.id FROM entity_name_period_history h
        JOIN entity_name_periods p ON p.id=h.period_id AND p.world_id=h.world_id
        WHERE h.world_id=? AND h.revision>=p.revision LIMIT 1
        """, [worldID]
      ).isEmpty
    else {
      throw SynthesisError.invalid("A saved name period revision is out of date order.")
    }
  }

  func validateEntityNameArchiveLabels(_ row: [String: String]) throws {
    _ = try entityNamePeriodDraft(row).validated()
  }
}
