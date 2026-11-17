import CoreFoundation
import Foundation

/// Splits a model answer into prose and an optional machine-readable change set.
/// The model may append one fenced block labelled `synthesis-proposal` containing JSON.
public enum ProposalParser {
  public static let fence = "```synthesis-proposal"
  /// Text safe to show while an answer is still streaming: everything before the change set.
  public static func visible(_ partial: String) -> String {
    guard let range = partial.range(of: fence) else { return partial }
    return String(partial[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
  }
  public static func split(_ answer: String) -> (prose: String, payload: [String: Any]?) {
    guard let start = answer.range(of: fence) else { return (answer, nil) }
    let after = answer[start.upperBound...]
    let end = after.range(of: "```")
    let json = String(end.map { after[..<$0.lowerBound] } ?? after)
    let remainder = end.map { String(after[$0.upperBound...]) } ?? ""
    let prose = (String(answer[..<start.lowerBound]) + remainder)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let object =
      json.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }
      as? [String: Any]
    return (prose, object)
  }
}

extension WorkspaceStore {
  private func decodeProposal(_ row: [String: String]) -> Proposal? {
    guard
      let changes = try? JSONDecoder().decode(
        [ProposedChange].self, from: Data((row["payload"] ?? "[]").utf8))
    else { return nil }
    return Proposal(
      id: row["id"]!, worldID: row["world_id"]!, conversationID: row["conversation_id"],
      messageID: row["message_id"], summary: row["reason"] ?? "", changes: changes,
      state: row["state"]!, createdAt: row["created_at"]!)
  }
  public func proposals(worldID: String, conversationID: String? = nil) throws -> [Proposal] {
    _ = try world(worldID)
    let rows =
      try conversationID.map {
        try db.rows(
          "SELECT * FROM proposals WHERE world_id=? AND conversation_id=? ORDER BY created_at,rowid",
          [worldID, $0])
      } ?? db.rows("SELECT * FROM proposals WHERE world_id=? ORDER BY created_at,rowid", [worldID])
    return rows.compactMap(decodeProposal)
  }
  public func proposal(worldID: String, id: String) throws -> Proposal {
    guard
      let row = try db.rows("SELECT * FROM proposals WHERE world_id=? AND id=?", [worldID, id])
        .first, let value = decodeProposal(row)
    else { throw SynthesisError.notFound }
    return value
  }
  /// Validates a model-supplied change set against the selected world and stores it as pending.
  /// Returns nil when nothing in it is usable. Staging never creates or changes lore.
  @discardableResult public func stageProposal(
    worldID: String, conversationID: String?, messageID: String?, payload: [String: Any]
  ) throws -> Proposal? {
    let known = Dictionary(
      uniqueKeysWithValues: try records(worldID: worldID).map { ($0.id, $0) })
    func text(_ value: Any?, limit: Int) -> String? {
      guard let string = value as? String else { return nil }
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : String(trimmed.prefix(limit))
    }
    let raw = (payload["changes"] as? [[String: Any]] ?? []).prefix(12)
    let boards =
      try boards(worldID: worldID, kind: "canvas") + boards(worldID: worldID, kind: "atlas")
    var createdBoards: [String: String] = [:]
    let lanes = try chronologyLanes(worldID: worldID)
    func coordinate(_ item: [String: Any], _ key: String, map: Bool) -> Double? {
      guard let raw = item[key] else { return map ? 0.5 : 0 }
      guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else {
        return nil
      }
      let number = value.doubleValue
      return number.isFinite && (map ? (0...1).contains(number) : abs(number) <= 100_000)
        ? number : nil
    }
    var changes: [ProposedChange] = []
    var created: [String: String] = [:]  // lowercased title → change reference
    func resolve(_ value: Any?) -> String? {
      guard let name = text(value, limit: 200) else { return nil }
      if known[name] != nil { return name }
      if let reference = created[name.lowercased()] { return reference }
      let matches = known.values.filter { $0.title.caseInsensitiveCompare(name) == .orderedSame }
      return matches.count == 1 ? matches[0].id : nil
    }
    for item in raw {
      let id = UUID().uuidString
      let evidence = (item["evidence"] as? [String] ?? []).filter { known[$0] != nil }.prefix(8)
      var change = ProposedChange(
        id: id, action: item["action"] as? String ?? "", kind: nil, title: nil, category: nil,
        body: nil, recordID: nil, baseVersion: nil, source: nil, target: nil, label: nil,
        date: nil, reason: text(item["reason"], limit: 400), evidence: Array(evidence),
        status: "pending", resultID: nil)
      switch change.action {
      case "create_record":
        let kind = item["kind"] as? String ?? "lore"
        guard ["lore", "entity", "capture"].contains(kind),
          let title = text(item["title"], limit: 160)
        else { continue }
        change.kind = kind
        change.title = title
        change.category = text(item["category"], limit: 60)
        change.body = text(item["body"], limit: 100_000) ?? ""
        created[title.lowercased()] = "change:\(id)"
      case "revise_record":
        guard let target = resolve(item["id"] ?? item["record"]), let record = known[target],
          let body = text(item["body"], limit: 100_000), body != record.body
        else { continue }
        change.recordID = record.id
        change.baseVersion = record.version
        change.title = text(item["title"], limit: 160) ?? record.title
        change.body = body
      case "relate":
        guard let source = resolve(item["source"]), let target = resolve(item["target"]),
          source != target, let label = text(item["label"], limit: 80)
        else { continue }
        // Relationships join entities; skip pairs that already exist as other kinds.
        if let record = known[source], record.kind != "entity" { continue }
        if let record = known[target], record.kind != "entity" { continue }
        change.source = source
        change.target = target
        change.label = label
      case "create_branch", "create_period":
        guard let title = text(item["title"], limit: 160) else { continue }
        change.title = title
        change.date = text(item["date"], limit: 160)
        change.endDate = text(item["endDate"], limit: 160)
        change.body = text(item["body"], limit: 30_000)
        if let lane = item["lane"] as? String {
          guard lanes.contains(where: { $0.id == lane }) else { continue }
          change.laneID = lane
        }
      case "add_event":
        if let lane = item["lane"] as? String {
          guard lanes.contains(where: { $0.id == lane }) else { continue }
          change.laneID = lane
        }
        guard let title = text(item["title"], limit: 160), let source = resolve(item["source"])
        else { continue }
        change.title = title
        change.date = text(item["date"], limit: 160)
        change.source = source
      case "create_map":
        guard let title = text(item["title"], limit: 120) else { continue }
        if item["source"] != nil {
          guard let source = resolve(item["source"]) else { continue }
          if let record = known[source], record.kind != "entity" { continue }
          if source.hasPrefix("change:"),
            changes.first(where: { "change:\($0.id)" == source })?.kind != "entity"
          {
            continue
          }
          change.source = source
        }
        if let parent = item["parentMap"] {
          guard let parent = parent as? String,
            boards.contains(where: { $0.id == parent && $0.kind == "atlas" })
          else { continue }
          change.parentMapID = parent
        }
        change.title = title
      case "create_board":
        guard let title = text(item["title"], limit: 120) else { continue }
        change.title = title
        createdBoards[title.lowercased()] = "change:\(id)"
      case "place_record", "place_marker":
        let map = change.action == "place_marker"
        guard let source = resolve(item["source"]), let requested = text(item["board"], limit: 200),
          let x = coordinate(item, "x", map: map), let y = coordinate(item, "y", map: map)
        else { continue }
        let matches = boards.filter {
          $0.kind == (map ? "atlas" : "canvas") && ($0.id == requested || $0.name == requested)
        }
        let boardID =
          matches.count == 1 ? matches[0].id : (map ? nil : createdBoards[requested.lowercased()])
        guard let boardID else { continue }
        change.boardID = boardID
        change.source = source
        change.x = x
        change.y = y
        change.title = matches.first?.name ?? requested
      case "link_records":
        guard let source = resolve(item["source"]), let target = resolve(item["target"]),
          source != target
        else { continue }
        change.source = source
        change.target = target
      case "create_component":
        guard let kind = item["kind"] as? String, CreativeKind(rawValue: kind) != nil,
          let rawScope = item["scope"] as? String, let scope = CreativeScope(rawValue: rawScope),
          let title = text(item["title"], limit: 160), let body = text(item["body"], limit: 100_000)
        else { continue }
        if scope == .entity {
          guard let parent = resolve(item["source"]) else { continue }
          if let record = known[parent], record.kind != "entity" { continue }
          if parent.hasPrefix("change:"),
            changes.first(where: { "change:\($0.id)" == parent })?.kind != "entity"
          {
            continue
          }
          change.source = parent
        } else if item["source"] != nil {
          continue
        }
        change.kind = kind
        change.componentScope = scope.rawValue
        change.title = title
        change.body = body
        created[title.lowercased()] = "change:\(id)"
      case "add_section":
        guard let source = resolve(item["source"]), let title = text(item["title"], limit: 160),
          let body = text(item["body"], limit: 100_000)
        else { continue }
        if let parent = known[source], parent.kind != "entity" { continue }
        if source.hasPrefix("change:"),
          changes.first(where: { "change:\($0.id)" == source })?.kind != "entity"
        {
          continue
        }
        change.source = source
        change.title = title
        change.body = body
      case "revise_rule":
        guard let id = item["id"] as? String,
          let before = try? rule(worldID: worldID, id: id),
          let body = text(item["body"], limit: 4_000),
          let owner = known[before.systemID], owner.kind == "entity",
          try rules(worldID: worldID, systemID: before.systemID).contains(where: { $0.id == id })
        else { continue }
        let kind = (item["kind"] as? String) ?? before.kind.rawValue
        guard WorldRule.Kind(rawValue: kind) != nil else { continue }
        change.recordID = id
        change.source = before.systemID
        change.ruleBefore = before
        change.title = text(item["title"], limit: 160) ?? before.title
        change.kind = kind
        change.body = body
      case "add_scenario":
        guard let source = resolve(item["source"]), let title = text(item["title"], limit: 160),
          let body = text(item["body"], limit: 4_000),
          let expectation = item["expectation"] as? String,
          ["works", "fails", "unclear"].contains(expectation)
        else { continue }
        if let parent = known[source], parent.kind != "entity" { continue }
        if source.hasPrefix("change:"),
          changes.first(where: { "change:\($0.id)" == source })?.kind != "entity"
        {
          continue
        }
        change.source = source
        change.title = title
        change.body = body
        change.kind = expectation
      case "add_rule":
        guard let source = resolve(item["source"]), let title = text(item["title"], limit: 160),
          let body = text(item["body"], limit: 4_000),
          let kind = item["kind"] as? String, WorldRule.Kind(rawValue: kind) != nil
        else { continue }
        if let record = known[source], record.kind != "entity" { continue }
        if source.hasPrefix("change:"),
          changes.first(where: { "change:\($0.id)" == source })?.kind != "entity"
        {
          continue
        }
        change.source = source
        change.title = title
        change.body = body
        change.kind = kind
      default: continue
      }
      changes.append(change)
    }
    guard !changes.isEmpty else { return nil }
    let id = UUID().uuidString
    let now = timestamp()
    let summary = text(payload["summary"], limit: 300) ?? "Proposed changes"
    try db.execute(
      "INSERT INTO proposals(id,world_id,payload,base_version,before,evidence,reason,origin,state,created_at,updated_at,message_id,conversation_id) VALUES(?,?,?,NULL,NULL,'[]',?,'ai-proposed','pending',?,?,?,?)",
      [
        id, worldID, String(decoding: try JSONEncoder().encode(changes), as: UTF8.self), summary,
        now, now, messageID, conversationID,
      ])
    return try proposal(worldID: worldID, id: id)
  }
  /// Applies or dismisses one staged change. Requires the proposal's own ID as confirmation so
  /// only an explicit, scoped creator action can reach it; the agent engine never calls this.
  /// Accepted changes become drafts. Canon is untouched and still needs its own review.
  public func resolveChange(
    worldID: String, proposalID: String, changeID: String, accept: Bool, confirmation: String
  ) throws -> Proposal {
    guard confirmation == proposalID else {
      throw SynthesisError.invalid("Explicit approval of this exact proposal is required.")
    }
    return try db.transaction {
      var proposal = try proposal(worldID: worldID, id: proposalID)
      guard let index = proposal.changes.firstIndex(where: { $0.id == changeID }) else {
        throw SynthesisError.notFound
      }
      var change = proposal.changes[index]
      guard change.status == "pending" else { return proposal }
      func resolved(_ reference: String?) throws -> String {
        guard let reference else { throw SynthesisError.notFound }
        guard reference.hasPrefix("change:") else { return reference }
        let dependency = proposal.changes.first { "change:\($0.id)" == reference }
        guard let id = dependency?.resultID else {
          throw SynthesisError.invalid(
            "Accept “\(dependency?.title ?? "the new record")” first; this change depends on it.")
        }
        return id
      }
      if accept {
        // Rule revisions identify a rule, not a lore record. Its owner is checked here;
        // the exact active rule and captured revision are checked in the rule branch below.
        let recordReferences =
          change.action == "revise_rule"
          ? [change.source, change.target] : [change.recordID, change.source, change.target]
        for reference in recordReferences.compactMap({ $0 }) {
          let id = try resolved(reference)
          _ = try record(worldID: worldID, id: id)
          guard try !isArchived(worldID: worldID, recordID: id) else {
            throw SynthesisError.invalid(
              "Restore the archived record before accepting this change.")
          }
        }
        switch change.action {
        case "create_record":
          change.resultID = try createRecord(
            worldID: worldID, title: change.title ?? "Untitled", body: change.body ?? "",
            kind: change.kind ?? "lore", category: change.category ?? "", origin: "ai-proposed"
          ).id
        case "revise_record":
          let current = try record(worldID: worldID, id: try resolved(change.recordID))
          guard current.version == change.baseVersion else { throw SynthesisError.stale }
          change.resultID = try saveRecord(
            worldID: worldID, id: current.id, version: current.version,
            title: change.title ?? current.title, body: change.body ?? current.body, rtf: nil
          ).id
        case "relate":
          change.resultID = try addRelation(
            worldID: worldID, source: try resolved(change.source),
            target: try resolved(change.target), label: change.label ?? "related to",
            origin: "ai-proposed"
          ).id
        case "create_branch", "create_period":
          change.resultID = try createChronologyLane(
            worldID: worldID, name: change.title ?? "Untitled",
            kind: change.action == "create_branch" ? "branch" : "period", parentID: change.laneID,
            start: change.date ?? "", end: change.endDate ?? "", notes: change.body ?? ""
          ).id
        case "add_event":
          change.resultID = try saveChronologyEvent(
            worldID: worldID, id: nil, title: change.title ?? "Untitled event",
            date: change.date ?? "",
            source: try resolved(change.source), order: nil, laneID: change.laneID,
            origin: "ai-proposed"
          ).id
        case "create_map":
          change.resultID = try createAtlasMap(
            worldID: worldID, name: change.title ?? "Map",
            placeID: change.source.map { try resolved($0) }, parentMapID: change.parentMapID
          ).id
        case "create_board":
          change.resultID = try saveBoard(
            worldID: worldID, name: change.title ?? "Untitled board", kind: "canvas",
            content:
              #"{"format":"excalidraw","version":1,"scene":{"elements":[],"appState":{}},"hiddenRelations":[]}"#
          ).id
        case "place_record":
          change.resultID = try placeRecord(
            worldID: worldID, boardID: resolved(change.boardID),
            recordID: resolved(change.source), x: change.x ?? 0, y: change.y ?? 0
          ).id
        case "place_marker":
          change.resultID = try placeMapMarker(
            worldID: worldID, boardID: resolved(change.boardID),
            recordID: resolved(change.source), x: change.x ?? 0.5, y: change.y ?? 0.5
          ).id
        case "link_records":
          try linkRecord(
            worldID: worldID, source: resolved(change.source), target: resolved(change.target))
          change.resultID = try resolved(change.source)
        case "create_component":
          guard let kind = CreativeKind(rawValue: change.kind ?? ""),
            let scope = CreativeScope(rawValue: change.componentScope ?? "")
          else {
            throw SynthesisError.invalid("Unknown creative component.")
          }
          change.resultID = try createCreativeComponent(
            worldID: worldID, scope: scope, kind: kind,
            parentID: scope == .entity ? resolved(change.source) : nil,
            title: change.title ?? "Component", body: change.body ?? "", origin: "ai-proposed"
          ).record.id
        case "add_section":
          change.resultID = try createRecordSection(
            worldID: worldID, parentID: resolved(change.source),
            title: change.title ?? "Section", body: change.body ?? "", origin: "ai-proposed"
          ).record.id
        case "revise_rule":
          guard let before = change.ruleBefore, let id = change.recordID,
            try rule(worldID: worldID, id: id) == before,
            let kind = WorldRule.Kind(rawValue: change.kind ?? "")
          else { throw SynthesisError.stale }
          change.resultID = try updateRule(
            worldID: worldID, id: id, kind: kind, title: change.title ?? before.title,
            body: change.body ?? before.body, expected: before
          ).id
        case "add_scenario":
          change.resultID = try saveScenario(
            worldID: worldID, systemID: resolved(change.source), title: change.title ?? "Scenario",
            situation: change.body ?? "", expectation: change.kind ?? "unclear"
          ).id
        case "add_rule":
          guard let kind = WorldRule.Kind(rawValue: change.kind ?? "") else {
            throw SynthesisError.invalid("Unknown rule kind.")
          }
          change.resultID = try addRule(
            worldID: worldID, systemID: resolved(change.source), kind: kind,
            title: change.title ?? "Rule", body: change.body ?? "", origin: "ai-proposed"
          ).id
        default: throw SynthesisError.invalid("Unknown proposed change.")
        }
      }
      change.status = accept ? "accepted" : "rejected"
      proposal.changes[index] = change
      let statuses = Set(proposal.changes.map(\.status))
      proposal.state =
        statuses.contains("pending")
        ? "pending" : (statuses.contains("accepted") ? "accepted" : "rejected")
      try db.execute(
        "UPDATE proposals SET payload=?,state=?,updated_at=? WHERE id=? AND world_id=?",
        [
          String(decoding: try JSONEncoder().encode(proposal.changes), as: UTF8.self),
          proposal.state, timestamp(), proposalID, worldID,
        ])
      return proposal
    }
  }
}
