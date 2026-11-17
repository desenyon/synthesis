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
    _ = try record(worldID: worldID, id: systemID)
    return try db.rows(
      "SELECT p.rule_id,p.requires_id FROM rule_prerequisites p JOIN rules a ON a.id=p.rule_id AND a.world_id=p.world_id JOIN rules b ON b.id=p.requires_id AND b.world_id=p.world_id WHERE p.world_id=? AND p.archived=0 AND a.archived=0 AND b.archived=0 AND a.system_id=? ORDER BY p.created_at,p.rowid",
      [worldID, systemID]
    ).map { RulePrerequisite(ruleID: $0["rule_id"]!, requiresID: $0["requires_id"]!) }
  }

  /// Replaces what a rule requires. Edges no longer listed are archived, not deleted.
  /// Rejects rules from another system or world and any loop ("A needs B needs A").
  public func setPrerequisites(worldID: String, ruleID: String, requires: [String]) throws {
    try db.transaction {
      let rule = try rule(worldID: worldID, id: ruleID)
      let wanted = Set(requires)
      guard wanted.count <= 24 else {
        throw SynthesisError.invalid("A technique can require up to 24 others.")
      }
      for id in wanted {
        let other = try self.rule(worldID: worldID, id: id)
        guard other.systemID == rule.systemID, id != ruleID,
          try db.rows("SELECT archived FROM rules WHERE id=?", [id]).first?["archived"] == "0"
        else {
          throw SynthesisError.invalid("A requirement must be another active rule of this system.")
        }
      }
      // Loop check on the edges as they would be after this change.
      var graph: [String: Set<String>] = [:]
      for edge in try prerequisites(worldID: worldID, systemID: rule.systemID)
      where edge.ruleID != ruleID {
        graph[edge.ruleID, default: []].insert(edge.requiresID)
      }
      graph[ruleID] = wanted
      var visiting = Set<String>()
      var done = Set<String>()
      func loops(_ node: String) -> Bool {
        if done.contains(node) { return false }
        if !visiting.insert(node).inserted { return true }
        for next in graph[node] ?? [] where loops(next) { return true }
        visiting.remove(node)
        done.insert(node)
        return false
      }
      guard !loops(ruleID) else {
        throw SynthesisError.invalid(
          "That would make a loop: a technique cannot, through others, require itself.")
      }
      let now = timestamp()
      try db.execute(
        "UPDATE rule_prerequisites SET archived=1,updated_at=? WHERE world_id=? AND rule_id=? AND archived=0",
        [now, worldID, ruleID])
      for id in wanted.sorted() {
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
