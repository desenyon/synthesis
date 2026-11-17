import Foundation

public enum AssistantIntent: String, Codable, CaseIterable, Sendable {
  case explore, propose
  public var title: String { self == .explore ? "Explore" : "Propose changes" }
}
public enum AssistantContextScope: String, Codable, CaseIterable, Sendable {
  case world, attachments
  public var title: String { self == .world ? "World context" : "Attachments only" }
}
public enum AssistantContextBudget: String, Codable, CaseIterable, Sendable {
  case focused, balanced, broad
  public var limit: Int {
    switch self {
    case .focused: return 8
    case .balanced: return 16
    case .broad: return 32
    }
  }
  public var title: String { "\(rawValue.capitalized) · \(limit) records" }
}

/// Device-local choices per universe. These are permissions for a request, never world facts.
public struct AssistantContextOptions: Codable, Equatable, Sendable {
  public var intent = AssistantIntent.propose
  public var scope = AssistantContextScope.world
  public var budget = AssistantContextBudget.balanced
  public var recordIDs: [String] = []
  public var boardIDs: [String] = []
  public var laneIDs: [String] = []
  public var excludedRecordIDs: [String] = []
  public var includeSelection = true
  public var includeHistory = true
  public init() {}
  public var restricted: Bool { scope == .attachments || !excludedRecordIDs.isEmpty }
}

/// Built once per preview/submission using the same world-scoped selection and serialization.
public struct AssistantContext: Sendable {
  public var sources: [ContextSource]
  public var workspace: String
  public var lore: String
  public var includesHistory: Bool
  public var eligibleCount: Int
  public var selectedIDs: [String]
}

extension WorkspaceStore {
  public func assistantContextOptions(worldID: String) throws -> AssistantContextOptions {
    _ = try world(worldID)
    guard let raw = try preference("assistant-context:\(worldID)") else { return .init() }
    guard var value = try? JSONDecoder().decode(AssistantContextOptions.self, from: Data(raw.utf8))
    else {
      // An unreadable saved restriction must never restore broader access by accident.
      var restricted = AssistantContextOptions()
      restricted.intent = .explore
      restricted.scope = .attachments
      restricted.includeSelection = false
      restricted.includeHistory = false
      return restricted
    }
    // Archived/removed attachments must not make a restored composer unusable.
    let records = Set(try records(worldID: worldID).map(\.id))
    let boards = Set(try assistantBoards(worldID: worldID).map(\.id))
    let lanes = Set(try chronologyLanes(worldID: worldID).map(\.id))
    value.recordIDs = value.recordIDs.filter(records.contains)
    // Keep exclusions through archive/Undo, including their restriction on earlier messages.
    value.boardIDs = value.boardIDs.filter(boards.contains)
    value.laneIDs = value.laneIDs.filter(lanes.contains)
    return value
  }

  public func setAssistantContextOptions(worldID: String, options: AssistantContextOptions) throws {
    _ = try world(worldID)
    let records = Set(try records(worldID: worldID).map(\.id))
    let boards = Set(try assistantBoards(worldID: worldID).map(\.id))
    let lanes = Set(try chronologyLanes(worldID: worldID).map(\.id))
    let exclusionIDs = try contextRecordIDs(worldID: worldID)
    guard options.recordIDs.allSatisfy(records.contains),
      options.excludedRecordIDs.allSatisfy(exclusionIDs.contains),
      options.boardIDs.allSatisfy(boards.contains), options.laneIDs.allSatisfy(lanes.contains)
    else { throw SynthesisError.invalid("Choose context from this universe's active records.") }
    try setPreference(
      "assistant-context:\(worldID)",
      value: String(decoding: JSONEncoder().encode(options), as: UTF8.self))
  }

  public func assistantBoards(worldID: String) throws -> [Board] {
    try boards(worldID: worldID, kind: "canvas") + boards(worldID: worldID, kind: "atlas")
  }

  private func contextRecordIDs(worldID: String) throws -> Set<String> {
    Set(try db.rows("SELECT id FROM records WHERE world_id=?", [worldID]).compactMap { $0["id"] })
  }

  public func assistantContext(
    worldID: String, prompt: String, options: AssistantContextOptions = .init(),
    selectedRecordIDs: [String] = [], boardID: String? = nil, chronologyLaneID: String? = nil
  ) throws -> AssistantContext {
    _ = try world(worldID)
    let all = try records(worldID: worldID)
    let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    let boards = try assistantBoards(worldID: worldID)
    let lanes = try chronologyLanes(worldID: worldID)
    let events = try events(worldID: worldID)
    let placements = try chronologyPlacements(worldID: worldID)
    let selected = options.includeSelection ? selectedRecordIDs : []
    let boardIDs = Set(
      options.boardIDs + (options.includeSelection ? boardID.map { [$0] } ?? [] : []))
    let laneIDs = Set(
      options.laneIDs + (options.includeSelection ? chronologyLaneID.map { [$0] } ?? [] : []))
    let exclusionIDs = try contextRecordIDs(worldID: worldID)
    guard
      (options.recordIDs + selected).allSatisfy({ byID[$0] != nil }),
      options.excludedRecordIDs.allSatisfy(exclusionIDs.contains),
      boardIDs.isSubset(of: Set(boards.map(\.id))), laneIDs.isSubset(of: Set(lanes.map(\.id)))
    else {
      throw SynthesisError.invalid(
        "Some context is no longer available in this universe. Reattach it before sending.")
    }
    guard boardIDs.count <= 24, laneIDs.count <= 60 else {
      throw SynthesisError.invalid("Attach up to 24 boards and 60 history groups per request.")
    }
    let excluded = Set(options.excludedRecordIDs)
    let explicit = Array(NSOrderedSet(array: options.recordIDs)).compactMap { $0 as? String }.filter
    { !excluded.contains($0) }
    guard explicit.count <= options.budget.limit else {
      throw SynthesisError.invalid(
        "The \(options.budget.rawValue) context fits \(options.budget.limit) records. Increase context size or remove an attachment."
      )
    }
    var anchors: [ContextSource] = []
    func add(_ id: String, _ reason: String) {
      guard !excluded.contains(id), let record = byID[id], !anchors.contains(where: { $0.id == id })
      else { return }
      anchors.append(.init(record: record, reason: reason))
    }
    for id in explicit { add(id, "Attached by you") }
    for id in selected { add(id, "Current selection") }
    for id in Self.referencedRecordIDs(in: prompt) { add(id, "You referenced it") }
    for board in boards where boardIDs.contains(board.id) {
      let object =
        (try? JSONSerialization.jsonObject(with: Data(board.content.utf8))) as? [String: Any] ?? [:]
      let scene = object["scene"] as? [String: Any] ?? [:]
      let entries =
        (scene["elements"] as? [[String: Any]]) ?? (object["cards"] as? [[String: Any]])
        ?? (object["markers"] as? [[String: Any]]) ?? []
      for entry in entries where entry["isDeleted"] as? Bool != true {
        let custom = entry["customData"] as? [String: Any]
        if let id = (custom?["recordID"] ?? entry["recordID"]) as? String {
          add(id, "On \(board.name)")
        }
      }
      if let place = object["placeID"] as? String { add(place, "Place of \(board.name)") }
    }
    var includedLanes = laneIDs
    var changed = true
    while changed {
      changed = false
      for lane in lanes where lane.parentID.map(includedLanes.contains) == true {
        if includedLanes.insert(lane.id).inserted { changed = true }
      }
    }
    for event in events where placements[event.id].map(includedLanes.contains) == true {
      add(event.sourceID, "In attached history")
    }
    let allowed =
      options.scope == .attachments ? Set(anchors.map(\.id)) : Set(byID.keys).subtracting(excluded)
    var sources = Array(anchors.prefix(options.budget.limit))
    if options.scope == .world {
      // Preserve entity sections and graph neighbours when the anchor came from a chip or
      // workspace selection instead of a typed mention. Restricted scope never expands this way.
      let retrievalPrompt = prompt + sources.map { " [](synthesis://record/\($0.id))" }.joined()
      for source in try contextRecords(
        worldID: worldID, prompt: retrievalPrompt, limit: options.budget.limit, allowedIDs: allowed)
      where sources.count < options.budget.limit && !sources.contains(where: { $0.id == source.id })
      {
        sources.append(source)
      }
    }
    let workspace = try scopedWorkspaceContext(
      worldID: worldID, allowedIDs: allowed, boardIDs: boardIDs, laneIDs: includedLanes,
      boardID: options.includeSelection ? boardID : nil,
      chronologyLaneID: options.includeSelection ? chronologyLaneID : nil,
      restricted: options.restricted)
    let lore = sources.map { source -> String in
      let r = source.record
      let canon = r.canonical.flatMap { $0.data(using: .utf8) }.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      }
      let accepted = canon?["body"] as? String ?? "none"
      let rules = (try? rulesText(worldID: worldID, systemID: r.id)) ?? ""
      return (rules.isEmpty ? "" : "Rules of \(r.title) —\n\(rules)\n")
        + "Record \(r.id), title: \(r.title), kind: \(r.kind), category: \(r.category), state: \(r.state), version: \(r.version). Working draft: \(String(r.body.prefix(3000))). Accepted canon snapshot: \(String(accepted.prefix(6000)))"
    }.joined(separator: "\n\n")
    return AssistantContext(
      sources: sources, workspace: workspace, lore: lore,
      includesHistory: options.includeHistory && !options.restricted,
      eligibleCount: allowed.count, selectedIDs: selected.filter(allowed.contains))
  }

  private func scopedWorkspaceContext(
    worldID: String, allowedIDs: Set<String>, boardIDs: Set<String>, laneIDs: Set<String>,
    boardID: String?, chronologyLaneID: String?, restricted: Bool
  ) throws -> String {
    let raw = try workspaceContext(
      worldID: worldID, boardID: boardID, chronologyLaneID: chronologyLaneID,
      allowedRecordIDs: allowedIDs, includedBoardIDs: restricted ? boardIDs : nil,
      includedLaneIDs: restricted ? laneIDs : nil,
      preferredBoardIDs: boardIDs, preferredLaneIDs: laneIDs)
    guard var object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
    else { throw SynthesisError.notFound }
    func filter(_ key: String, _ predicate: ([String: Any]) -> Bool) {
      object[key] = (object[key] as? [[String: Any]] ?? []).filter(predicate)
    }
    func allowed(_ item: [String: Any], _ key: String) -> Bool {
      (item[key] as? String).map(allowedIDs.contains) == true
    }
    filter("records") { allowed($0, "id") }
    filter("sections") { allowed($0, "parent") && allowed($0, "record") }
    filter("rules") { allowed($0, "system") }
    filter("scenarios") { allowed($0, "system") }
    filter("components") {
      allowed($0, "record") && (($0["parent"] as? String ?? "").isEmpty || allowed($0, "parent"))
    }
    filter("relationships") { allowed($0, "source") && allowed($0, "target") }
    filter("events") { allowed($0, "source") }
    if restricted {
      filter("boards") { ($0["id"] as? String).map(boardIDs.contains) == true }
      filter("chronology") { ($0["id"] as? String).map(laneIDs.contains) == true }
    }
    object["boards"] = (object["boards"] as? [[String: Any]] ?? []).map { item in
      var value = item
      let placements = (item["placements"] as? [[String: Any]] ?? []).filter {
        allowed($0, "record")
      }
      value["placements"] = placements
      if !allowed(item, "place") { value["place"] = "" }
      if restricted, (item["parentMap"] as? String).map(boardIDs.contains) != true {
        value["parentMap"] = ""
      }
      return value
    }
    let knownLanes = Set(
      (object["chronology"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    object["chronology"] = (object["chronology"] as? [[String: Any]] ?? []).map { item in
      var value = item
      if (item["parent"] as? String).map(knownLanes.contains) != true { value["parent"] = "" }
      return value
    }
    let eventIDs = Set(
      (object["events"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    object["eventPlacement"] = (object["eventPlacement"] as? [String: String] ?? [:]).filter {
      eventIDs.contains($0.key) && knownLanes.contains($0.value)
    }
    return String(
      decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
      as: UTF8.self)
  }
}
