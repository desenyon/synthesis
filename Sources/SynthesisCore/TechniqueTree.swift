import Foundation

/// "Learning `ruleID` requires `requiresID` first." Both belong to the same system.
public struct RulePrerequisite: Equatable, Hashable, Sendable {
  public var ruleID: String
  public var requiresID: String
}

extension WorkspaceStore {
  /// Kinds that form a tree: what can be done, and how someone grows into it.
  public static let treeKinds: Set<WorldRule.Kind> = [.technique, .progression]

  /// Active prerequisite edges between active rules of one system.
  public func prerequisites(worldID: String, systemID: String) throws -> [RulePrerequisite] {
    try storedPrerequisites(worldID: worldID, systemID: systemID)
      .filter { !$0.sourceArchived && !$0.targetArchived }.map { $0.edge }
  }

  private func storedPrerequisites(worldID: String, systemID: String) throws
    -> [(edge: RulePrerequisite, sourceArchived: Bool, targetArchived: Bool)]
  {
    _ = try record(worldID: worldID, id: systemID)
    return try db.rows(
      "SELECT p.rule_id,p.requires_id,a.archived AS source_archived,b.archived AS target_archived FROM rule_prerequisites p JOIN rules a ON a.id=p.rule_id AND a.world_id=p.world_id JOIN rules b ON b.id=p.requires_id AND b.world_id=p.world_id AND b.system_id=a.system_id WHERE p.world_id=? AND p.archived=0 AND a.system_id=? ORDER BY p.created_at,p.rowid",
      [worldID, systemID]
    ).map {
      (
        RulePrerequisite(ruleID: $0["rule_id"]!, requiresID: $0["requires_id"]!),
        $0["source_archived"] == "1", $0["target_archived"] == "1"
      )
    }
  }

  /// Replaces a rule's visible requirements and preserves dormant edges for archive Undo.
  /// A dormant edge still participates in loop checks because either endpoint can be restored.
  public func setPrerequisites(worldID: String, ruleID: String, requires: [String]) throws {
    try db.transaction {
      let rule = try activeRule(worldID: worldID, id: ruleID)
      let stored = try storedPrerequisites(worldID: worldID, systemID: rule.systemID)
      let outgoing = stored.filter { $0.edge.ruleID == ruleID }
      let current = Set(outgoing.map { $0.edge.requiresID })
      let dormant = Set(outgoing.filter { $0.targetArchived }.map { $0.edge.requiresID })
      let supplied = Set(requires)
      let wanted = Self.treeKinds.contains(rule.kind) ? supplied.union(dormant) : supplied
      guard wanted.count <= 24 else {
        throw SynthesisError.invalid("A technique can require up to 24 others.")
      }
      for id in wanted.subtracting(dormant) {
        let other = try activeRule(worldID: worldID, id: id)
        guard other.systemID == rule.systemID, id != ruleID else {
          throw SynthesisError.invalid("A requirement must be another active rule of this system.")
        }
      }
      var graph: [String: Set<String>] = [:]
      for (edge, _, _) in stored where edge.ruleID != ruleID {
        graph[edge.ruleID, default: []].insert(edge.requiresID)
      }
      var remaining = Array(wanted)
      var visited = Set<String>()
      while let node = remaining.popLast() {
        guard node != ruleID else {
          throw SynthesisError.invalid(
            "That would make a loop: a technique cannot, through others, require itself.")
        }
        if visited.insert(node).inserted { remaining.append(contentsOf: graph[node] ?? []) }
      }
      let now = timestamp()
      for id in current.subtracting(wanted).sorted() {
        try db.execute(
          "UPDATE rule_prerequisites SET archived=1,updated_at=? WHERE world_id=? AND rule_id=? AND requires_id=?",
          [now, worldID, ruleID, id])
      }
      for id in wanted.subtracting(current).sorted() {
        try db.execute(
          "INSERT INTO rule_prerequisites VALUES(?,?,?,?,0,?,?) ON CONFLICT(rule_id,requires_id) DO UPDATE SET archived=0,updated_at=excluded.updated_at",
          [UUID().uuidString, worldID, ruleID, id, now, now])
      }
    }
  }

  /// Saves a rule and, for tree kinds, what it requires, in one transaction: a rejected loop
  /// leaves both the wording and the requirements unchanged.
  @discardableResult public func saveRule(
    worldID: String, systemID: String, existing: WorldRule?, kind: WorldRule.Kind, title: String,
    body: String, requires: [String]
  ) throws -> WorldRule {
    try db.transaction {
      let saved =
        try existing.map {
          try updateRule(
            worldID: worldID, id: $0.id, kind: kind, title: title, body: body, expected: $0)
        }
        ?? addRule(worldID: worldID, systemID: systemID, kind: kind, title: title, body: body)
      try setPrerequisites(
        worldID: worldID, ruleID: saved.id,
        requires: Self.treeKinds.contains(kind) ? requires : [])
      return saved
    }
  }
}
