import Foundation

/// Where a what-if branch came from.
public struct WorldBranch: Equatable, Sendable {
  public var worldID: String
  public var parentID: String
  public var parentName: String
  public var createdAt: String
  /// The latest merge proposal sent to the original, if any.
  public var lastProposalID: String?
}

/// One difference between a branch and its original, as previewed before sending.
public struct BranchChange: Identifiable, Equatable, Sendable {
  public enum Kind: String, Sendable {
    /// Text edited in the branch only.
    case revise
    /// New in the branch.
    case create, relate, event
    /// Edited in both the branch and the original since branching. Not sent; reconcile by hand.
    case conflict
    /// Archived in the branch. Archiving is never merged automatically.
    case archived
    /// Changed only in ways a merge cannot carry (category, formatting).
    case unsupported
  }
  public var id: String
  public var kind: Kind
  public var title: String
  public var detail: String
  public var sendable: Bool { [.revise, .create, .relate, .event].contains(kind) }
}

extension WorkspaceStore {
  /// Copies a world into a new, independent what-if world. The original is not changed.
  @discardableResult public func createWhatIfBranch(parentID: String, name: String) throws
    -> World
  {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 120 else {
      throw SynthesisError.invalid("Give the what-if a short name.")
    }
    let parent = try world(parentID)
    let parentRecords = try records(worldID: parentID)
    let archived = try archivedRecords(worldID: parentID)
    let data = try exportWorldArchive(worldID: parentID)
    return try db.transaction {
      let (copy, ids) = try importWorldArchiveMapping(data)
      try db.execute(
        "UPDATE worlds SET name=?,description=?,demo=0,updated_at=? WHERE id=?",
        [trimmed, "What-if of \(parent.name)", timestamp(), copy.id])
      try db.execute(
        "INSERT INTO world_branches VALUES(?,?,?,NULL)", [copy.id, parentID, timestamp()])
      for record in parentRecords + archived {
        guard let mapped = ids[record.id] else { continue }
        try db.execute(
          "INSERT INTO branch_origins VALUES(?,?,?,?,?,?,?)",
          [
            copy.id, mapped, record.id, String(record.version), record.title, record.body,
            record.category,
          ])
      }
      for row in try db.rows("SELECT id FROM relationships WHERE world_id=?", [copy.id]) {
        try db.execute(
          "INSERT INTO branch_items VALUES(?,?,'relationship')", [copy.id, row["id"]!])
      }
      for row in try db.rows("SELECT id FROM events WHERE world_id=?", [copy.id]) {
        try db.execute("INSERT INTO branch_items VALUES(?,?,'event')", [copy.id, row["id"]!])
      }
      return try world(copy.id)
    }
  }

  public func branchInfo(worldID: String) throws -> WorldBranch? {
    guard
      let row = try db.rows(
        "SELECT b.*,w.name FROM world_branches b JOIN worlds w ON w.id=b.parent_id WHERE b.world_id=?",
        [worldID]
      ).first
    else { return nil }
    return WorldBranch(
      worldID: worldID, parentID: row["parent_id"]!, parentName: row["name"]!,
      createdAt: row["created_at"]!, lastProposalID: row["last_proposal_id"])
  }

  /// Every what-if made from a world, keyed by branch ID, for labelling world lists.
  public func branchParents() throws -> [String: String] {
    Dictionary(
      uniqueKeysWithValues: try db.rows("SELECT world_id,parent_id FROM world_branches").map {
        ($0["world_id"]!, $0["parent_id"]!)
      })
  }

  private struct Origin {
    var id: String
    var version: Int
    var title: String
    var body: String
    var category: String
  }

  /// What sending this branch back would do, without changing anything.
  public func branchChanges(worldID: String) throws -> [BranchChange] {
    try branchPlan(worldID: worldID).preview
  }

  private func branchPlan(worldID: String) throws -> (
    preview: [BranchChange], payload: [[String: Any]], parentID: String
  ) {
    guard let branch = try branchInfo(worldID: worldID) else {
      throw SynthesisError.invalid("This world is not a what-if branch.")
    }
    var origins: [String: Origin] = [:]
    for row in try db.rows("SELECT * FROM branch_origins WHERE world_id=?", [worldID]) {
      origins[row["record_id"]!] = Origin(
        id: row["origin_id"]!, version: Int(row["origin_version"]!) ?? 0, title: row["title"]!,
        body: row["body"]!, category: row["category"]!)
    }
    let parentActive = Dictionary(
      uniqueKeysWithValues: try records(worldID: branch.parentID).map { ($0.id, $0) })
    var preview: [BranchChange] = []
    var payload: [[String: Any]] = []
    // Branch record ID → how the merge refers to it in the original (an ID or a new title).
    var reference: [String: String] = [:]
    let records = try records(worldID: worldID)
    for record in records {
      guard let origin = origins[record.id] else {
        reference[record.id] = record.title
        preview.append(
          BranchChange(
            id: "create:\(record.id)", kind: .create, title: record.title,
            detail:
              "New \(record.kind == "entity" ? "entity" : record.kind == "capture" ? "idea" : "document") in the what-if."
          ))
        payload.append([
          "action": "create_record", "kind": record.kind, "title": record.title,
          "category": record.category, "body": record.body,
          "reason": "Written in the what-if “\(try world(worldID).name)”.",
        ])
        continue
      }
      reference[record.id] = origin.id
      let textChanged = record.title != origin.title || record.body != origin.body
      guard textChanged || record.category != origin.category else { continue }
      guard let current = parentActive[origin.id] else {
        preview.append(
          BranchChange(
            id: "conflict:\(record.id)", kind: .conflict, title: record.title,
            detail: "Archived in the original since branching. Restore it there first."))
        continue
      }
      if current.version != origin.version {
        preview.append(
          BranchChange(
            id: "conflict:\(record.id)", kind: .conflict, title: record.title,
            detail:
              "Edited in both worlds since branching. Not sent; open both and combine the text by hand."
          ))
      } else if record.body != origin.body {
        preview.append(
          BranchChange(
            id: "revise:\(record.id)", kind: .revise, title: record.title,
            detail: record.title != origin.title
              ? "Renamed from “\(origin.title)” and rewritten." : "Text rewritten in the what-if."
          ))
        payload.append([
          "action": "revise_record", "id": origin.id, "title": record.title, "body": record.body,
          "reason": "Revised in the what-if.",
        ])
      } else {
        preview.append(
          BranchChange(
            id: "unsupported:\(record.id)", kind: .unsupported, title: record.title,
            detail:
              "Only the title or category changed. Review proposals carry text; change these by hand."
          ))
      }
    }
    for record in try archivedRecords(worldID: worldID) where origins[record.id] != nil {
      preview.append(
        BranchChange(
          id: "archived:\(record.id)", kind: .archived, title: record.title,
          detail: "Archived in the what-if. Archive it in the original yourself if you want to."))
    }
    let existing = Set(
      try db.rows("SELECT item_id FROM branch_items WHERE world_id=?", [worldID]).map {
        $0["item_id"]!
      })
    let titles = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.title) })
    for relation in try relations(worldID: worldID) where !existing.contains(relation.id) {
      guard let source = reference[relation.sourceID], let target = reference[relation.targetID]
      else { continue }
      preview.append(
        BranchChange(
          id: "relate:\(relation.id)", kind: .relate,
          title:
            "\(titles[relation.sourceID] ?? "?") — \(relation.label) → \(titles[relation.targetID] ?? "?")",
          detail: "New relationship in the what-if."))
      payload.append([
        "action": "relate", "source": source, "target": target, "label": relation.label,
        "reason": "Connected in the what-if.",
      ])
    }
    for event in try events(worldID: worldID) where !existing.contains(event.id) {
      var item: [String: Any] = [
        "action": "add_event", "title": event.title, "date": event.dateLabel,
        "reason": "Recorded in the what-if.",
      ]
      if let source = reference[event.sourceID] { item["source"] = source }
      preview.append(
        BranchChange(
          id: "event:\(event.id)", kind: .event, title: event.title,
          detail: event.dateLabel.isEmpty ? "New event in the what-if." : event.dateLabel))
      payload.append(item)
    }
    return (preview, payload, branch.parentID)
  }

  /// Stages the branch's sendable changes as one pending proposal in the original world. Nothing
  /// in the original changes until the creator accepts individual changes in Review; canon still
  /// needs its own review after that.
  @discardableResult public func proposeBranchMerge(worldID: String) throws -> Proposal {
    let plan = try branchPlan(worldID: worldID)
    guard !plan.payload.isEmpty else {
      throw SynthesisError.invalid("Nothing in this what-if can be sent yet.")
    }
    let name = try world(worldID).name
    return try db.transaction {
      guard
        let proposal = try stageProposal(
          worldID: plan.parentID, conversationID: nil, messageID: nil,
          payload: ["summary": "Changes from the what-if “\(name)”", "changes": plan.payload],
          limit: 500, origin: "branch-merge")
      else { throw SynthesisError.invalid("None of these changes could be staged.") }
      try db.execute(
        "UPDATE world_branches SET last_proposal_id=? WHERE world_id=?", [proposal.id, worldID])
      return proposal
    }
  }
}
