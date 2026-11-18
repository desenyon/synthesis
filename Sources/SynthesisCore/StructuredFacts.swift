import Foundation

public enum StructuredFactStatus: String, Codable, Sendable {
  case draft, disputed, canon

  public var title: String { rawValue.capitalized }
}

public enum StructuredFactValue: Codable, Equatable, Sendable {
  case text(String)
  case entity(String)
}

public struct StructuredFactEvidence: Codable, Hashable, Sendable {
  public let recordID: String
  public let version: Int

  public init(recordID: String, version: Int) {
    self.recordID = recordID
    self.version = version
  }
}

public struct StructuredFactDraft: Equatable, Sendable {
  public var value: StructuredFactValue
  public var evidence: StructuredFactEvidence?
  public var disputed: Bool

  public init(
    value: StructuredFactValue, evidence: StructuredFactEvidence? = nil, disputed: Bool = false
  ) {
    self.value = value
    self.evidence = evidence
    self.disputed = disputed
  }
}

public struct StructuredFactRevision: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let revision: Int
  public let status: StructuredFactStatus
  public let value: StructuredFactValue
  public let evidence: StructuredFactEvidence?
  public let author: String
  public let origin: String
  public let recordedAt: String

  public var draft: StructuredFactDraft {
    .init(value: value, evidence: evidence, disputed: status == .disputed)
  }

  fileprivate init(row: [String: String]) throws {
    guard let id = row["id"], let revision = row["revision"].flatMap(Int.init),
      let status = row["status"].flatMap(StructuredFactStatus.init(rawValue:)),
      let author = row["author"], let origin = row["origin"], let recordedAt = row["recorded_at"]
    else { throw SynthesisError.invalid("A saved fact revision could not be read.") }
    self.id = id
    self.revision = revision
    self.status = status
    self.author = author
    self.origin = origin
    self.recordedAt = recordedAt
    if let entityID = row["entity_value_id"] {
      value = .entity(entityID)
    } else if let text = row["text_value"] {
      value = .text(text)
    } else {
      throw SynthesisError.invalid("A saved fact is missing a value.")
    }
    if let recordID = row["evidence_record_id"],
      let version = row["evidence_version"].flatMap(Int.init)
    {
      evidence = .init(recordID: recordID, version: version)
    } else {
      evidence = nil
    }
  }
}

public struct StructuredFact: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let worldID: String
  public let subjectID: String
  public let predicate: String
  public let working: StructuredFactRevision
  public let accepted: StructuredFactRevision?
  public let version: Int
  public let archived: Bool
}

extension WorkspaceStore {
  /// A world-scoped structured lookup, usable independently of the subject's prose and profile.
  public func structuredFacts(
    worldID: String, subjectID: String, predicate: String? = nil
  ) throws -> [StructuredFact] {
    try requireFactEntity(worldID: worldID, id: subjectID)
    let scope = predicate == nil ? "" : " AND predicate=? COLLATE synthesis_search"
    return try db.rows(
      "SELECT * FROM structured_facts WHERE world_id=? AND subject_id=? AND archived=0\(scope) ORDER BY predicate COLLATE synthesis_search,rowid",
      [worldID, subjectID] + (predicate.map { [$0] } ?? [])
    ).map { try decodeStructuredFact(worldID: worldID, row: $0) }
  }

  public func structuredFactHistory(worldID: String, factID: String) throws
    -> [StructuredFactRevision]
  {
    _ = try structuredFact(worldID: worldID, id: factID)
    return try factRevisions(worldID: worldID, factID: factID)
  }

  private func factRevisions(worldID: String, factID: String) throws -> [StructuredFactRevision] {
    try db.rows(
      "SELECT * FROM structured_fact_revisions WHERE world_id=? AND fact_id=? ORDER BY revision",
      [worldID, factID]
    ).map(StructuredFactRevision.init(row:))
  }

  /// Pin the chosen document's current saved revision when it enters the draft.
  public func structuredFactEvidence(worldID: String, recordID: String) throws
    -> StructuredFactEvidence
  {
    let record = try record(worldID: worldID, id: recordID)
    guard try !isArchived(worldID: worldID, recordID: recordID) else { throw SynthesisError.stale }
    let evidence = StructuredFactEvidence(recordID: record.id, version: record.version)
    _ = try structuredFactSource(worldID: worldID, evidence: evidence)
    return evidence
  }

  public func structuredFactSource(worldID: String, evidence: StructuredFactEvidence) throws
    -> LoreRecord
  {
    guard
      let snapshot = try db.rows(
        "SELECT snapshot FROM native_revisions WHERE world_id=? AND record_id=? AND version=?",
        [worldID, evidence.recordID, String(evidence.version)]
      ).first?["snapshot"]
    else { throw SynthesisError.notFound }
    let source = try JSONDecoder().decode(LoreRecord.self, from: Data(snapshot.utf8))
    guard source.worldID == worldID, source.id == evidence.recordID,
      source.version == evidence.version,
      source.kind != "capture"
    else { throw SynthesisError.invalid("Select a saved document or entity revision.") }
    return source
  }

  @discardableResult public func createStructuredFact(
    worldID: String, subjectID: String, predicate: String, draft: StructuredFactDraft
  ) throws -> StructuredFact {
    let label = try factText(predicate, limit: 80)
    return try db.transaction {
      try requireFactEntity(worldID: worldID, id: subjectID, active: true)
      let value = try validatedFactDraft(worldID: worldID, draft: draft)
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        """
        INSERT INTO structured_facts(id,world_id,subject_id,predicate,working_revision,version,created_at,updated_at)
        VALUES(?,?,?,?,1,1,?,?)
        """,
        [id, worldID, subjectID, label, now, now])
      try insertFactRevision(
        worldID: worldID, factID: id, revision: 1, draft: value,
        status: value.disputed ? .disputed : .draft)
      return try structuredFact(worldID: worldID, id: id)
    }
  }

  @discardableResult public func reviseStructuredFact(
    worldID: String, expected: StructuredFact, draft: StructuredFactDraft
  ) throws -> StructuredFact {
    try db.transaction {
      let current = try editableFact(worldID: worldID, expected: expected)
      let value = try validatedFactDraft(worldID: worldID, draft: draft)
      if value == current.working.draft { return current }
      return try appendFactRevision(
        current, draft: value, status: value.disputed ? .disputed : .draft)
    }
  }

  /// This operation is called only from creator review. The exact reviewed revision is the
  /// confirmation token. Neither general draft writes nor agent proposal processing approve facts.
  @discardableResult public func approveStructuredFact(
    worldID: String, expected: StructuredFact, confirmation: String
  ) throws -> StructuredFact {
    try db.transaction {
      let current = try editableFact(worldID: worldID, expected: expected)
      guard confirmation == current.working.id, current.working.status == .draft else {
        throw SynthesisError.invalid("Review and approve this exact draft to accept it as canon.")
      }
      return try appendFactRevision(current, draft: current.working.draft, status: .canon)
    }
  }

  @discardableResult public func setStructuredFactArchived(
    worldID: String, expected: StructuredFact, archived: Bool
  ) throws -> StructuredFact {
    try db.transaction {
      let current = try editableFact(
        worldID: worldID, expected: expected, includingArchived: true)
      guard current.archived != archived else { return current }
      guard current.version < Int.max - 1 else { throw SynthesisError.stale }
      try db.execute(
        "UPDATE structured_facts SET archived=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
        [archived ? "1" : "0", timestamp(), worldID, current.id])
      return try structuredFact(worldID: worldID, id: current.id)
    }
  }

  private func requireFactEntity(worldID: String, id: String, active: Bool = false) throws {
    let entity = try record(worldID: worldID, id: id)
    guard entity.kind == "entity", try (!active || !isArchived(worldID: worldID, recordID: id))
    else { throw SynthesisError.invalid("Choose an available entity in this universe.") }
  }

  private func factText(_ text: String, limit: Int) throws -> String {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty, text.count <= limit, text.utf8.count <= 4 * limit,
      !text.contains("\0"), !text.unicodeScalars.contains(where: CharacterSet.newlines.contains)
    else { throw SynthesisError.invalid("Use one line of 1–\(limit) characters.") }
    return cleaned
  }

  private func validatedFactDraft(worldID: String, draft: StructuredFactDraft) throws
    -> StructuredFactDraft
  {
    var checked = draft
    switch draft.value {
    case .text(let value): checked.value = .text(try factText(value, limit: 400))
    case .entity(let id): try requireFactEntity(worldID: worldID, id: id)
    }
    if let evidence = draft.evidence {
      _ = try structuredFactSource(worldID: worldID, evidence: evidence)
    }
    return checked
  }

  private func editableFact(
    worldID: String, expected: StructuredFact, includingArchived: Bool = false
  ) throws -> StructuredFact {
    guard expected.worldID == worldID else { throw SynthesisError.notFound }
    let current = try structuredFact(worldID: worldID, id: expected.id)
    try requireFactEntity(worldID: worldID, id: current.subjectID, active: true)
    guard current == expected, includingArchived || !current.archived else {
      throw SynthesisError.stale
    }
    return current
  }

  private func structuredFact(worldID: String, id: String) throws -> StructuredFact {
    guard
      let row = try db.rows(
        "SELECT * FROM structured_facts WHERE world_id=? AND id=?", [worldID, id]
      ).first
    else { throw SynthesisError.notFound }
    return try decodeStructuredFact(worldID: worldID, row: row)
  }

  private func decodeStructuredFact(worldID: String, row: [String: String]) throws
    -> StructuredFact
  {
    guard let id = row["id"], let subject = row["subject_id"], let predicate = row["predicate"],
      let revision = row["working_revision"], let version = row["version"].flatMap(Int.init),
      version > 0, version < Int.max
    else { throw SynthesisError.invalid("A saved fact could not be read.") }
    let working = try factRevision(worldID: worldID, factID: id, revision: revision)
    let accepted = try row["accepted_revision"].map {
      try factRevision(worldID: worldID, factID: id, revision: $0)
    }
    return .init(
      id: id, worldID: worldID, subjectID: subject, predicate: predicate, working: working,
      accepted: accepted, version: version, archived: row["archived"] == "1")
  }

  private func factRevision(worldID: String, factID: String, revision: String) throws
    -> StructuredFactRevision
  {
    guard
      let row = try db.rows(
        "SELECT * FROM structured_fact_revisions WHERE world_id=? AND fact_id=? AND revision=?",
        [worldID, factID, revision]
      ).first
    else { throw SynthesisError.notFound }
    return try StructuredFactRevision(row: row)
  }

  private func appendFactRevision(
    _ current: StructuredFact, draft: StructuredFactDraft, status: StructuredFactStatus
  ) throws -> StructuredFact {
    guard current.version < Int.max - 1, current.working.revision < Int.max - 1 else {
      throw SynthesisError.stale
    }
    let revision = current.working.revision + 1
    try insertFactRevision(
      worldID: current.worldID, factID: current.id, revision: revision, draft: draft, status: status
    )
    let accepted = status == .canon ? revision : current.accepted?.revision
    try db.execute(
      """
      UPDATE structured_facts SET working_revision=?,accepted_revision=?,version=version+1,updated_at=?
      WHERE world_id=? AND id=?
      """,
      [String(revision), accepted.map(String.init), timestamp(), current.worldID, current.id])
    return try structuredFact(worldID: current.worldID, id: current.id)
  }

  private func insertFactRevision(
    worldID: String, factID: String, revision: Int, draft: StructuredFactDraft,
    status: StructuredFactStatus
  ) throws {
    let text: String?
    let entity: String?
    switch draft.value {
    case .text(let value): (text, entity) = (value, nil)
    case .entity(let id): (text, entity) = (nil, id)
    }
    try db.execute(
      """
      INSERT INTO structured_fact_revisions(
        id,world_id,fact_id,revision,status,author,origin,recorded_at,
        text_value,entity_value_id,evidence_record_id,evidence_version
      ) VALUES(?,?,?,?,?,'Local creator','user-authored',?,?,?,?,?)
      """,
      [
        UUID().uuidString, worldID, factID, String(revision), status.rawValue, timestamp(),
        text, entity, draft.evidence?.recordID, draft.evidence.map { String($0.version) },
      ])
  }

  /// Check imported heads and revision histories before the copy transaction commits.
  func validateStructuredFactArchive(worldID: String) throws {
    let facts = try db.rows("SELECT * FROM structured_facts WHERE world_id=?", [worldID])
    var checkedEntities: Set<String> = []
    var checkedEvidence: Set<StructuredFactEvidence> = []
    for row in facts {
      let fact = try decodeStructuredFact(worldID: worldID, row: row)
      if checkedEntities.insert(fact.subjectID).inserted {
        try requireFactEntity(worldID: worldID, id: fact.subjectID)
      }
      guard try factText(fact.predicate, limit: 80) == fact.predicate else {
        throw SynthesisError.invalid("Invalid structured fact label in world file.")
      }
      let revisions = try factRevisions(worldID: worldID, factID: fact.id)
      guard revisions.count == fact.working.revision,
        revisions.last(where: { $0.status == .canon }) == fact.accepted
      else { throw SynthesisError.invalid("Invalid structured fact history in world file.") }
      for (index, revision) in revisions.enumerated() {
        guard revision.revision == index + 1,
          try factText(revision.author, limit: 80) == revision.author,
          try factText(revision.recordedAt, limit: 80) == revision.recordedAt
        else { throw SynthesisError.invalid("Invalid structured fact revision in world file.") }
        switch revision.value {
        case .text(let text):
          guard try factText(text, limit: 400) == text else {
            throw SynthesisError.invalid("Invalid structured fact text in world file.")
          }
        case .entity(let id):
          if checkedEntities.insert(id).inserted {
            try requireFactEntity(worldID: worldID, id: id)
          }
        }
        if let evidence = revision.evidence, checkedEvidence.insert(evidence).inserted {
          _ = try structuredFactSource(worldID: worldID, evidence: evidence)
        }
        if revision.status == .canon {
          guard index > 0, revisions[index - 1].status == .draft,
            revisions[index - 1].draft == revision.draft
          else { throw SynthesisError.invalid("A fact approval has no matching draft.") }
        }
      }
    }
  }
}
