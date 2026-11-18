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
  public var title: String { "\(rawValue.capitalized) · \(limit) sources" }
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
  private var historyExclusions: [String]?
  private var acceptedRecordSnapshotsOnly: Bool?
  public var excludedLaneIDs: [String] {
    get { historyExclusions ?? [] }
    set { historyExclusions = newValue.isEmpty ? nil : newValue }
  }
  public var canonOnly: Bool {
    get { acceptedRecordSnapshotsOnly ?? false }
    set { acceptedRecordSnapshotsOnly = newValue ? true : nil }
  }
  public init() {}
  public var restricted: Bool {
    scope == .attachments || canonOnly || !excludedRecordIDs.isEmpty || !excludedLaneIDs.isEmpty
  }
}

/// Extra sources for one admitted request. These are never part of saved preferences.
public struct AssistantRequestPins: Equatable, Sendable {
  public var recordIDs: [String] = []
  public var boardIDs: [String] = []
  public var laneIDs: [String] = []
  public var isEmpty: Bool { recordIDs.isEmpty && boardIDs.isEmpty && laneIDs.isEmpty }
  public init() {}
}

/// Built once per preview/submission using the same world-scoped selection and serialization.
public struct AssistantContext: Sendable {
  public var sources: [ContextSource]
  public var workspace: String
  public var lore: String
  public var includesHistory: Bool
  public var eligibleCount: Int
  public var selectedIDs: [String]
  var providerPrompt: String
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
    _ = try assistantChronologyExclusions(worldID: worldID, laneIDs: options.excludedLaneIDs)
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

  public func assistantHistoryExclusions(worldID: String, laneIDs: [String]) throws
    -> (lanes: Set<String>, records: Set<String>)
  {
    let result = try assistantChronologyExclusions(worldID: worldID, laneIDs: laneIDs)
    return (result.laneIDs, result.recordIDs)
  }

  public static func assistantAcceptedRecordIDs(in records: [LoreRecord]) -> Set<String> {
    Set(assistantAcceptedRecords(records).map(\.id))
  }

  private func contextRecordIDs(worldID: String) throws -> Set<String> {
    Set(try db.rows("SELECT id FROM records WHERE world_id=?", [worldID]).compactMap { $0["id"] })
  }

  public func assistantContext(
    worldID: String, prompt: String, options: AssistantContextOptions = .init(),
    requestPins: AssistantRequestPins = .init(),
    selectedRecordIDs: [String] = [], boardID: String? = nil, chronologyLaneID: String? = nil
  ) throws -> AssistantContext {
    _ = try world(worldID)
    let all = try records(worldID: worldID)
    let activeIDs = Set(all.map(\.id))
    let available = options.canonOnly ? Self.assistantAcceptedRecords(all) : all
    let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
    let boards = try assistantBoards(worldID: worldID)
    let lanes = try chronologyLanes(worldID: worldID)
    let events = try events(worldID: worldID)
    let placements = try chronologyPlacements(worldID: worldID)
    let exclusionIDs = try contextRecordIDs(worldID: worldID)
    let excludedHistory = try assistantChronologyExclusions(
      worldID: worldID, laneIDs: options.excludedLaneIDs)
    let excluded = Set(options.excludedRecordIDs).union(excludedHistory.recordIDs)
      .union(activeIDs.subtracting(byID.keys))
    // A dropped link is explicit context, including in attachment-only mode. Resolve it
    // against the active world; a stale or foreign address must never become guessed lore.
    let approvedRecords = options.canonOnly ? byID.filter { !excluded.contains($0.key) } : nil
    let (referenceSources, excludedAddresses) = try assistantReferences(
      in: prompt, worldID: worldID, excludedRecords: excluded, excludedHistory: excludedHistory,
      approvedRecords: approvedRecords)
    let providerPrompt = try assistantPrompt(
      prompt, worldID: worldID, excluding: excludedAddresses, excludingRecordIDs: excluded,
      approvedRecords: approvedRecords)
    let referenceRecordIDs = referenceSources.flatMap(\.recordIDs).filter { byID[$0] != nil }
    let referenceBoardIDs = referenceSources.filter { $0.reference.kind == .board }.map {
      $0.reference.id
    }
    let selected = options.includeSelection ? selectedRecordIDs : []
    let directRecordAttachments = requestPins.recordIDs + options.recordIDs
    let boardIDs = Set(
      requestPins.boardIDs + options.boardIDs + referenceBoardIDs
        + (options.includeSelection ? boardID.map { [$0] } ?? [] : []))
    let requestedLaneIDs = Set(
      requestPins.laneIDs + options.laneIDs
        + (options.includeSelection ? chronologyLaneID.map { [$0] } ?? [] : []))
    guard
      (directRecordAttachments + selected).allSatisfy(activeIDs.contains),
      options.excludedRecordIDs.allSatisfy(exclusionIDs.contains),
      boardIDs.isSubset(of: Set(boards.map(\.id))),
      requestedLaneIDs.isSubset(of: Set(lanes.map(\.id)))
    else {
      throw SynthesisError.invalid(
        "Some context is no longer available in this universe. Reattach it before sending.")
    }
    let laneIDs = requestedLaneIDs.subtracting(excludedHistory.laneIDs)
    guard boardIDs.count <= 24, laneIDs.count <= 60 else {
      throw SynthesisError.invalid("Attach up to 24 boards and 60 history groups per request.")
    }
    let typedRecordIDs = Self.referencedRecordIDs(in: providerPrompt).filter { byID[$0] != nil }
    // A record chip and either link format identify the same source. An event or image
    // still counts as its own source even when it shares a backing record with another source.
    let modernRecordIDs = referenceSources.compactMap {
      $0.reference.kind == .record ? $0.reference.id : nil
    }
    let directRecordIDs = Set(directRecordAttachments + typedRecordIDs + modernRecordIDs)
      .subtracting(excluded)
    let otherDirectSources = referenceSources.count - modernRecordIDs.count
    guard directRecordIDs.count + otherDirectSources <= options.budget.limit else {
      throw SynthesisError.invalid(
        "The \(options.budget.rawValue) context fits \(options.budget.limit) directly referenced sources. Increase context size or remove an attachment."
      )
    }
    let children = Dictionary(grouping: lanes) { $0.parentID }
    func includeDescendants(of roots: Set<String>) -> Set<String> {
      var included = roots
      var pending = Array(roots)
      while let parentID = pending.popLast() {
        for child in children[parentID, default: []]
        where !excludedHistory.laneIDs.contains(child.id) && included.insert(child.id).inserted {
          pending.append(child.id)
        }
      }
      return included
    }
    let pinnedLanes = Set(requestPins.laneIDs).intersection(laneIDs)
    let pinnedHistory = includeDescendants(of: pinnedLanes)
    let includedLanes = includeDescendants(of: laneIDs)
    var anchors: [ContextSource] = []
    func add(_ id: String, _ reason: String) {
      guard !excluded.contains(id), let record = byID[id], !anchors.contains(where: { $0.id == id })
      else { return }
      anchors.append(.init(record: record, reason: reason))
    }
    for id in requestPins.recordIDs { add(id, "Pinned for this request") }
    for id in options.recordIDs { add(id, "Attached by you") }
    for id in referenceRecordIDs + typedRecordIDs { add(id, "You referenced it") }
    for event in events where placements[event.id].map(pinnedHistory.contains) == true {
      add(event.sourceID, "In pinned history")
    }
    for id in selected { add(id, "Current selection") }
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
          add(id, options.canonOnly ? "In an attached board" : "On \(board.name)")
        }
      }
      if let place = object["placeID"] as? String {
        add(place, options.canonOnly ? "Place of an attached map" : "Place of \(board.name)")
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
      let retrievalPrompt =
        providerPrompt + sources.map { " [](synthesis://record/\($0.id))" }.joined()
      let additional =
        if options.canonOnly {
          Self.assistantAcceptedSources(
            available.filter { allowed.contains($0.id) }, prompt: retrievalPrompt,
            limit: options.budget.limit)
        } else {
          try contextRecords(
            worldID: worldID, prompt: retrievalPrompt, limit: options.budget.limit,
            allowedIDs: allowed)
        }
      for source in additional
      where sources.count < options.budget.limit && !sources.contains(where: { $0.id == source.id })
      {
        sources.append(source)
      }
    }
    let activeLane =
      options.includeSelection && chronologyLaneID.map(laneIDs.contains) == true
      ? chronologyLaneID : nil
    var workspace =
      if options.canonOnly {
        try Self.assistantAcceptedContextIndex(
          available.filter { allowed.contains($0.id) }, prioritizedIDs: sources.map(\.id))
      } else {
        try scopedWorkspaceContext(
          worldID: worldID, allowedIDs: allowed, boardIDs: boardIDs, laneIDs: includedLanes,
          boardID: options.includeSelection ? boardID : nil,
          chronologyLaneID: activeLane, pinnedLaneIDs: pinnedLanes,
          pinnedHistoryIDs: pinnedHistory, restricted: options.restricted)
      }
    if !referenceSources.isEmpty {
      guard
        var object = try JSONSerialization.jsonObject(with: Data(workspace.utf8)) as? [String: Any]
      else {
        throw SynthesisError.invalid("The world context could not be prepared.")
      }
      // Only text metadata is shared for images. A reference does not enable vision, image
      // generation, another world, earlier chat history or broader context permissions.
      object["references"] = referenceSources.map { source -> [String: Any] in
        let excerpt =
          source.reference.kind == .record || source.reference.kind == .event ? "" : source.excerpt
        return [
          "url": source.reference.url.absoluteString, "kind": source.reference.kind.rawValue,
          "title": source.title, "detail": source.detail, "state": source.state,
          "excerpt": String(excerpt.prefix(1000)), "excerptTruncated": excerpt.count > 1000,
          "recordIDs": source.recordIDs.filter(allowed.contains),
          "authority": source.reference.kind == .proposal
            ? "Proposal history; not canon. Accepted changes are drafts." : "World source",
        ]
      }
      workspace = String(
        decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
        as: UTF8.self)
    }
    let lore = sources.map { source -> String in
      let r = source.record
      if options.canonOnly {
        return
          "Record \(r.id), title: \(r.title), kind: \(r.kind), category: \(r.category). Accepted canon: \(String(r.body.prefix(6000)))"
      }
      let canon = r.canonical.flatMap { $0.data(using: .utf8) }.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      }
      let accepted = canon?["body"] as? String ?? "none"
      let rules = (try? rulesText(worldID: worldID, systemID: r.id)) ?? ""
      let properties =
        (try? entityPropertyText(worldID: worldID, recordID: r.id, allowedIDs: allowed, limit: 4000))
        ?? ""
      return (rules.isEmpty ? "" : "Rules of \(r.title) —\n\(rules)\n")
        + (properties.isEmpty ? "" : properties + "\n")
        + "Record \(r.id), title: \(r.title), kind: \(r.kind), category: \(r.category), state: \(r.state), version: \(r.version). Working draft: \(String(r.body.prefix(3000))). Accepted canon snapshot: \(String(accepted.prefix(6000)))"
    }.joined(separator: "\n\n")
    return AssistantContext(
      sources: sources, workspace: workspace, lore: lore,
      includesHistory: options.includeHistory && !options.restricted,
      eligibleCount: allowed.count, selectedIDs: selected.filter(allowed.contains),
      providerPrompt: providerPrompt)
  }

  private func assistantReferences(
    in prompt: String, worldID: String, excludedRecords: Set<String>,
    excludedHistory: AssistantChronologyExclusions, approvedRecords: [String: LoreRecord]?
  ) throws -> ([WorldReferenceSource], Set<WorldReference>) {
    var sources: [WorldReferenceSource] = []
    var excluded: Set<WorldReference> = []
    for reference in try Self.requestWorldReferences(in: prompt) {
      let hiddenHistory = try isChronologyReferenceExcluded(
        reference, worldID: worldID, exclusions: excludedHistory)
      let hiddenRecord = reference.kind == .record && excludedRecords.contains(reference.id)
      if hiddenHistory || hiddenRecord {
        excluded.insert(reference)
        continue
      }
      if let approvedRecords {
        guard reference.kind == .record, let record = approvedRecords[reference.id] else {
          excluded.insert(reference)
          continue
        }
        sources.append(
          WorldReferenceSource(
            reference: reference, title: record.title,
            detail: record.kind == "entity" ? record.category : "Source",
            excerpt: "", state: "canon", recordIDs: [record.id], boardKind: nil,
            originRecordIDs: []))
        continue
      }
      if reference.kind == .proposal,
        !excludedRecords.isEmpty || !excludedHistory.laneIDs.isEmpty
      {
        let prior = try proposal(worldID: worldID, id: reference.id)
        // Earlier answers may use index entries and conversation text without excerpt IDs.
        // Do not re-share their generated proposal text when any explicit exclusion is set.
        if prior.messageID != nil && !prior.isBranchMerge {
          excluded.insert(reference)
          continue
        }
      }
      let source = try resolveReference(reference, worldID: worldID)
      if excludedRecords.isDisjoint(with: source.exclusionRecordIDs) {
        sources.append(source)
      } else {
        excluded.insert(reference)
      }
    }
    return (sources, excluded)
  }

  private func scopedWorkspaceContext(
    worldID: String, allowedIDs: Set<String>, boardIDs: Set<String>, laneIDs: Set<String>,
    boardID: String?, chronologyLaneID: String?, pinnedLaneIDs: Set<String>,
    pinnedHistoryIDs: Set<String>, restricted: Bool
  ) throws -> String {
    let raw = try workspaceContext(
      worldID: worldID, boardID: boardID, chronologyLaneID: chronologyLaneID,
      allowedRecordIDs: allowedIDs, includedBoardIDs: restricted ? boardIDs : nil,
      includedLaneIDs: restricted ? laneIDs : nil,
      preferredBoardIDs: boardIDs, preferredLaneIDs: laneIDs,
      pinnedLaneIDs: pinnedLaneIDs, pinnedHistoryIDs: pinnedHistoryIDs)
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
