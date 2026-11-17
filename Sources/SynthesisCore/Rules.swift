import Foundation

/// One mechanic of a power system: where the power comes from, what it costs, what it cannot
/// do, how it grows, what can be done with it, or a stated exception.
public struct WorldRule: Identifiable, Codable, Equatable, Sendable {
  public enum Kind: String, CaseIterable, Codable, Sendable {
    case source, cost, limit, progression, technique, exception
    public var title: String {
      switch self {
      case .source: return "Source"
      case .cost: return "Costs"
      case .limit: return "Limits"
      case .progression: return "Progression"
      case .technique: return "Techniques"
      case .exception: return "Exceptions"
      }
    }
    public var singular: String {
      switch self {
      case .source: return "source"
      case .cost: return "cost"
      case .limit: return "limit"
      case .progression: return "step"
      case .technique: return "technique"
      case .exception: return "exception"
      }
    }
    public var prompt: String {
      switch self {
      case .source: return "Where does this power come from?"
      case .cost: return "What does using it take away?"
      case .limit: return "What can it never do?"
      case .progression: return "How does someone grow in it?"
      case .technique: return "What can be done with it?"
      case .exception: return "When does a rule above not hold?"
      }
    }
  }
  public var id: String
  public var worldID: String
  public var systemID: String
  public var kind: Kind
  public var title: String
  public var body: String
  public var state: String
  public var origin: String
  /// JSON of the accepted `{title, body}` when this rule has been made canon.
  public var canonical: String?
  public var updatedAt: String
  /// The accepted wording, if any.
  public var accepted: (title: String, body: String)? {
    guard let data = canonical?.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return nil }
    return (object["title"] ?? "", object["body"] ?? "")
  }
}
/// A situation used to test a system: something that should work, should fail, or is unclear.
public struct RuleScenario: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var worldID: String
  public var systemID: String
  public var title: String
  public var situation: String
  /// `works`, `fails` or `unclear`.
  public var expectation: String
  /// The creator's own conclusion after testing; empty until written.
  public var verdict: String
}
/// A local observation about a power system's rules. Computed, never stored.
public struct RuleFinding: Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var detail: String
  /// The kind of rule that would answer it, when adding one is the natural next step.
  public var suggests: WorldRule.Kind?
}

extension WorkspaceStore {
  private func decodeRule(_ row: [String: String]) -> WorldRule? {
    guard let kind = WorldRule.Kind(rawValue: row["kind"] ?? "") else { return nil }
    return WorldRule(
      id: row["id"]!, worldID: row["world_id"]!, systemID: row["system_id"]!, kind: kind,
      title: row["title"]!, body: row["body"]!, state: row["state"]!, origin: row["origin"]!,
      canonical: row["canonical"], updatedAt: row["updated_at"]!)
  }
  /// Entities filed as power systems in a world.
  public func powerSystems(worldID: String) throws -> [LoreRecord] {
    try records(worldID: worldID).filter {
      $0.kind == "entity" && $0.category.caseInsensitiveCompare("Power systems") == .orderedSame
    }
  }
  /// Active rules of one system, grouped order: kind, then the order they were written.
  public func rules(worldID: String, systemID: String) throws -> [WorldRule] {
    _ = try record(worldID: worldID, id: systemID)
    let order = Dictionary(
      uniqueKeysWithValues: WorldRule.Kind.allCases.enumerated().map { ($1, $0) })
    return try db.rows(
      "SELECT * FROM rules WHERE world_id=? AND system_id=? AND archived=0 ORDER BY position,created_at,rowid",
      [worldID, systemID]
    ).compactMap(decodeRule).enumerated().sorted {
      (order[$0.element.kind]!, $0.offset) < (order[$1.element.kind]!, $1.offset)
    }.map(\.element)
  }
  public func rule(worldID: String, id: String) throws -> WorldRule {
    guard
      let row = try db.rows("SELECT * FROM rules WHERE world_id=? AND id=?", [worldID, id]).first,
      let value = decodeRule(row)
    else { throw SynthesisError.notFound }
    return value
  }
  private func validate(title: String, body: String) throws -> (String, String) {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, title.count <= 160, body.count <= 4000 else {
      throw SynthesisError.invalid("Give the rule a short name and keep it under 4,000 characters.")
    }
    return (title, body)
  }
  public func addRule(
    worldID: String, systemID: String, kind: WorldRule.Kind, title: String, body: String,
    origin: String = "user-authored"
  ) throws -> WorldRule {
    return try db.transaction {
      let system = try record(worldID: worldID, id: systemID)
      guard system.kind == "entity", try !isArchived(worldID: worldID, recordID: systemID) else {
        throw SynthesisError.invalid("Rules belong to an entity such as a power system.")
      }
      let (title, body) = try validate(title: title, body: body)
      let id = UUID().uuidString
      let now = timestamp()
      let position =
        try db.rows(
          "SELECT COALESCE(MAX(position),0)+1 AS next FROM rules WHERE world_id=? AND system_id=?",
          [worldID, systemID]
        ).first?["next"] ?? "1"
      try db.execute(
        "INSERT INTO rules(id,world_id,system_id,kind,title,body,state,origin,canonical,position,archived,created_at,updated_at) VALUES(?,?,?,?,?,?,'draft',?,NULL,?,0,?,?)",
        [id, worldID, systemID, kind.rawValue, title, body, origin, position, now, now])
      let created = try rule(worldID: worldID, id: id)
      try snapshotRule(created)
      return created
    }
  }
  /// Edits a rule. An accepted rule becomes a draft again; its accepted wording is kept.
  public func updateRule(
    worldID: String, id: String, kind: WorldRule.Kind, title: String, body: String,
    expected: WorldRule? = nil
  )
    throws -> WorldRule
  {
    return try db.transaction {
      let before = try activeRule(worldID: worldID, id: id)
      if let expected, expected != before { throw SynthesisError.stale }
      try snapshotRule(before)
      let (title, body) = try validate(title: title, body: body)
      try db.execute(
        "UPDATE rules SET kind=?,title=?,body=?,state='draft',updated_at=? WHERE world_id=? AND id=?",
        [kind.rawValue, title, body, timestamp(), worldID, id])
      let updated = try rule(worldID: worldID, id: id)
      try snapshotRule(updated)
      return updated
    }
  }
  /// Accepts a rule's current wording as canon. Requires the rule's own ID as confirmation,
  /// so only an explicit, scoped creator action can reach it.
  public func promoteRule(
    worldID: String, id: String, confirmation: String, expected: WorldRule? = nil
  ) throws -> WorldRule {
    return try db.transaction {
      guard confirmation == id else {
        throw SynthesisError.invalid("Explicit approval of this exact rule is required.")
      }
      let current = try activeRule(worldID: worldID, id: id)
      if let expected, expected != current { throw SynthesisError.stale }
      try snapshotRule(current)
      let accepted = String(
        decoding: try JSONSerialization.data(
          withJSONObject: ["title": current.title, "body": current.body], options: [.sortedKeys]),
        as: UTF8.self)
      try db.execute(
        "UPDATE rules SET state='canon',canonical=?,updated_at=? WHERE world_id=? AND id=?",
        [accepted, timestamp(), worldID, id])
      let updated = try rule(worldID: worldID, id: id)
      try snapshotRule(updated)
      return updated
    }
  }
  public func setRuleArchived(worldID: String, id: String, archived: Bool) throws {
    _ = try rule(worldID: worldID, id: id)
    try db.execute(
      "UPDATE rules SET archived=?,updated_at=? WHERE world_id=? AND id=?",
      [archived ? "1" : "0", timestamp(), worldID, id])
  }

  // MARK: Scenarios

  private func decodeScenario(_ row: [String: String]) -> RuleScenario {
    RuleScenario(
      id: row["id"]!, worldID: row["world_id"]!, systemID: row["system_id"]!,
      title: row["title"]!, situation: row["situation"]!, expectation: row["expectation"]!,
      verdict: row["verdict"]!)
  }
  public func scenarios(worldID: String, systemID: String) throws -> [RuleScenario] {
    _ = try record(worldID: worldID, id: systemID)
    return try db.rows(
      "SELECT * FROM rule_scenarios WHERE world_id=? AND system_id=? AND archived=0 ORDER BY created_at,rowid",
      [worldID, systemID]
    ).map(decodeScenario)
  }
  /// Creates a scenario, or updates the one with `id`.
  public func saveScenario(
    worldID: String, systemID: String, id: String? = nil, title: String, situation: String,
    expectation: String, verdict: String = ""
  ) throws -> RuleScenario {
    let owner = try record(worldID: worldID, id: systemID)
    guard owner.kind == "entity", try !isArchived(worldID: worldID, recordID: systemID) else {
      throw SynthesisError.invalid("Scenarios belong to an active entity.")
    }
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, title.count <= 160, situation.count <= 4000, verdict.count <= 4000,
      ["works", "fails", "unclear"].contains(expectation)
    else { throw SynthesisError.invalid("Give the scenario a short name and an expectation.") }
    let now = timestamp()
    if let id {
      guard
        try !db.rows(
          "SELECT id FROM rule_scenarios WHERE world_id=? AND system_id=? AND id=? AND archived=0",
          [worldID, systemID, id]
        ).isEmpty
      else { throw SynthesisError.notFound }
      try db.execute(
        "UPDATE rule_scenarios SET title=?,situation=?,expectation=?,verdict=?,updated_at=? WHERE world_id=? AND id=?",
        [title, situation, expectation, verdict, now, worldID, id])
      return RuleScenario(
        id: id, worldID: worldID, systemID: systemID, title: title, situation: situation,
        expectation: expectation, verdict: verdict)
    }
    let new = UUID().uuidString
    try db.execute(
      "INSERT INTO rule_scenarios(id,world_id,system_id,title,situation,expectation,verdict,archived,created_at,updated_at) VALUES(?,?,?,?,?,?,?,0,?,?)",
      [new, worldID, systemID, title, situation, expectation, verdict, now, now])
    return RuleScenario(
      id: new, worldID: worldID, systemID: systemID, title: title, situation: situation,
      expectation: expectation, verdict: verdict)
  }
  public func setScenarioArchived(worldID: String, id: String, archived: Bool) throws {
    _ = try world(worldID)
    guard
      try !db.rows("SELECT id FROM rule_scenarios WHERE world_id=? AND id=?", [worldID, id]).isEmpty
    else { throw SynthesisError.notFound }
    try db.execute(
      "UPDATE rule_scenarios SET archived=?,updated_at=? WHERE world_id=? AND id=?",
      [archived ? "1" : "0", timestamp(), worldID, id])
  }

  // MARK: Review

  /// What a system's rules leave open. A local reading of structure, not a judgement of content.
  public func ruleChecks(worldID: String, systemID: String) throws -> [RuleFinding] {
    let rules = try rules(worldID: worldID, systemID: systemID)
    let tests = try scenarios(worldID: worldID, systemID: systemID)
    func count(_ kind: WorldRule.Kind) -> Int { rules.filter { $0.kind == kind }.count }
    var findings: [RuleFinding] = []
    if rules.isEmpty {
      return [
        RuleFinding(
          id: "empty", title: "No rules yet",
          detail: "Start with what the power costs. A price is what makes it interesting.",
          suggests: .cost)
      ]
    }
    if count(.cost) == 0 {
      findings.append(
        RuleFinding(
          id: "no-cost", title: "Nothing here has a cost",
          detail: "Without a price, any problem can be solved by using more of it.", suggests: .cost
        ))
    }
    if count(.limit) == 0 {
      findings.append(
        RuleFinding(
          id: "no-limit", title: "No limits are stated",
          detail: "What can this power never do, however much is paid?", suggests: .limit))
    }
    if count(.source) == 0 {
      findings.append(
        RuleFinding(
          id: "no-source", title: "Its source is not described",
          detail: "Where the power comes from often decides who can have it.", suggests: .source))
    }
    if count(.exception) > 0, count(.limit) + count(.cost) == 0 {
      findings.append(
        RuleFinding(
          id: "orphan-exception", title: "An exception with nothing to except",
          detail: "Exceptions read best against a stated cost or limit.", suggests: .limit))
    }
    if count(.progression) == 1 {
      findings.append(
        RuleFinding(
          id: "one-step", title: "Progression has a single step",
          detail: "Growth needs at least a before and an after.", suggests: .progression))
    }
    var seen: [String: String] = [:]
    for rule in rules {
      let key = rule.title.lowercased()
      if let other = seen[key] {
        findings.append(
          RuleFinding(
            id: "duplicate:\(key)", title: "Two rules are both called “\(rule.title)”",
            detail: "One is under \(other), one under \(rule.kind.title).", suggests: nil))
      } else {
        seen[key] = rule.kind.title
      }
    }
    let changed = rules.filter { rule in
      rule.state != "canon"
        && rule.accepted.map { $0.title != rule.title || $0.body != rule.body } == true
    }
    if !changed.isEmpty {
      findings.append(
        RuleFinding(
          id: "changed-canon",
          title:
            "\(changed.count) accepted \(changed.count == 1 ? "rule has" : "rules have") changed",
          detail: changed.map(\.title).joined(separator: ", ")
            + " — review to accept the new wording.",
          suggests: nil))
    }
    let untested = tests.filter { $0.verdict.trimmingCharacters(in: .whitespaces).isEmpty }
    if tests.isEmpty {
      findings.append(
        RuleFinding(
          id: "no-scenarios", title: "No scenarios to test against",
          detail: "A situation that should fail is the quickest way to find a gap.", suggests: nil))
    } else if !untested.isEmpty {
      findings.append(
        RuleFinding(
          id: "untested",
          title:
            "\(untested.count) \(untested.count == 1 ? "scenario has" : "scenarios have") no verdict",
          detail: untested.map(\.title).joined(separator: ", "), suggests: nil))
    }
    return findings
  }
  /// Plain-text rules for a system, as given to the assistant and to Markdown export.
  public func rulesText(worldID: String, systemID: String) throws -> String {
    let rules = try rules(worldID: worldID, systemID: systemID)
    guard !rules.isEmpty else { return "" }
    return WorldRule.Kind.allCases.compactMap { kind -> String? in
      let group = rules.filter { $0.kind == kind }
      guard !group.isEmpty else { return nil }
      return "\(kind.title):\n"
        + group.map {
          "- \($0.title)\($0.body.isEmpty ? "" : ": \($0.body)") [\($0.state)]"
        }.joined(separator: "\n")
    }.joined(separator: "\n")
  }
}

extension WorkspaceStore {
  private func activeRule(worldID: String, id: String) throws -> WorldRule {
    let current = try rule(worldID: worldID, id: id)
    guard try !isArchived(worldID: worldID, recordID: current.systemID),
      try !db.rows("SELECT id FROM rules WHERE world_id=? AND id=? AND archived=0", [worldID, id])
        .isEmpty
    else { throw SynthesisError.invalid("Restore this rule and its entity before changing it.") }
    return current
  }
  private func snapshotRule(_ rule: WorldRule) throws {
    let data = try JSONEncoder().encode(rule)
    if let last = try db.rows(
      "SELECT snapshot FROM rule_history WHERE world_id=? AND rule_id=? ORDER BY rowid DESC LIMIT 1",
      [rule.worldID, rule.id]
    ).first?["snapshot"],
      let previous = try? JSONDecoder().decode(WorldRule.self, from: Data(last.utf8)),
      previous == rule
    {
      return
    }
    try db.execute(
      "INSERT INTO rule_history VALUES(?,?,?,?,?)",
      [
        UUID().uuidString, rule.worldID, rule.id, String(decoding: data, as: UTF8.self),
        timestamp(),
      ])
  }
  public func ruleHistory(worldID: String, id: String) throws -> [WorldRule] {
    _ = try rule(worldID: worldID, id: id)
    return try db.rows(
      "SELECT snapshot FROM rule_history WHERE world_id=? AND rule_id=? ORDER BY rowid DESC",
      [worldID, id]
    ).map {
      try JSONDecoder().decode(WorldRule.self, from: Data(($0["snapshot"] ?? "").utf8))
    }
  }
}
