import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct AssistantContextTests {
  @Test func worldScopeRetainsSectionsAndNeighborsOfSelectedOrAttachedLore() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Selected context")
    let entity = try store.createRecord(worldID: world.id, title: "Navigator", kind: "entity")
    let section = try store.createRecordSection(
      worldID: world.id, parentID: entity.id, title: "Childhood", body: "Grew up at sea")
    let neighbor = try store.createRecord(worldID: world.id, title: "Harbor", kind: "entity")
    try store.addRelation(
      worldID: world.id, source: entity.id, target: neighbor.id, label: "lives in")
    for index in 0..<20 {
      try store.createRecord(worldID: world.id, title: "Unrelated \(index)")
    }
    var options = AssistantContextOptions()
    for pinned in [false, true] {
      options.recordIDs = pinned ? [entity.id] : []
      let context = try store.assistantContext(
        worldID: world.id, prompt: "Develop this", options: options,
        selectedRecordIDs: pinned ? [] : [entity.id])
      let ids = context.sources.map(\.id)
      #expect(ids.contains(entity.id))
      #expect(ids.contains(section.record.id))
      #expect(ids.contains(neighbor.id))
    }
  }
  @Test func unreadableContextSettingsDoNotSilentlyBroadenAccess() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Unreadable preferences")
    try store.setPreference("assistant-context:\(world.id)", value: "{broken}")
    let restored = try store.assistantContextOptions(worldID: world.id)
    #expect(restored.scope == .attachments)
    #expect(restored.intent == .explore)
    #expect(!restored.includeSelection && !restored.includeHistory)
  }
  @Test func exploreCannotStageEvenWhenTheModelIgnoresTheInstruction() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Explore")
    let chat = try store.createConversation(worldID: world.id)
    let engine = AgentEngine(
      store: store,
      transport: ScriptedTransport(
        answer:
          "An idea to consider.\n```synthesis-proposal\n{\"summary\":\"Create\",\"changes\":[{\"action\":\"create_record\",\"title\":\"Unwanted\",\"body\":\"No\"}]}\n```"
      ))
    var options = AssistantContextOptions()
    options.intent = .explore
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Imagine", preset: "Create",
      contextOptions: options
    ) { _ in }
    #expect(try store.records(worldID: world.id).isEmpty)
    #expect(try store.proposals(worldID: world.id).isEmpty)
    let messages = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(messages.contains { $0.body == "An idea to consider." })
    #expect(messages.contains { $0.role == "system" && $0.body.contains("Explore") })
    #expect(!messages.contains { $0.body.contains("synthesis-proposal") })
  }

  @Test func exclusionsRemoveIndexRulesRelationsAndPriorConversation() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Scope")
    let visible = try store.createRecord(
      worldID: world.id, title: "Harbor", body: "Public harbor", kind: "entity")
    let hidden = try store.createRecord(
      worldID: world.id, title: "EXCLUDED_SENTINEL", body: "PRIVATE_BODY", kind: "entity")
    try store.addRelation(
      worldID: world.id, source: visible.id, target: hidden.id, label: "SECRET_EDGE")
    try store.addRule(
      worldID: world.id, systemID: hidden.id, kind: .cost, title: "PRIVATE_RULE",
      body: "SECRET_COST")
    var options = AssistantContextOptions()
    options.excludedRecordIDs = [hidden.id]
    let chat = try store.createConversation(worldID: world.id)
    try store.appendMessage(
      worldID: world.id, conversationID: chat.id, role: "assistant", body: "OLD_PRIVATE_HISTORY",
      state: "complete")
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    let preview = try store.assistantContext(worldID: world.id, prompt: "Harbor", options: options)
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Harbor", preset: "Develop",
      contextOptions: options
    ) { _ in }
    let request = try #require(await transport.lastRequest)
    #expect(request.instructions.contains(preview.workspace))
    #expect(request.instructions.contains(preview.lore))
    for sentinel in [
      hidden.id, "EXCLUDED_SENTINEL", "PRIVATE_BODY", "SECRET_EDGE", "PRIVATE_RULE", "SECRET_COST",
    ] {
      #expect(!request.instructions.contains(sentinel))
    }
    #expect(!request.messages.contains { $0["content"]?.contains("OLD_PRIVATE_HISTORY") == true })
    #expect(preview.sources.map(\.id) == [visible.id])
    #expect(!preview.includesHistory)
  }

  @Test func explicitlyAttachedOldBoardsAreNotLostBehindTheIndexLimit() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Many boards")
    for index in 0..<27 {
      try store.saveBoard(worldID: world.id, name: "Board \(index)", kind: "canvas", content: "{}")
    }
    let boards = try store.assistantBoards(worldID: world.id)
    let last = try #require(boards.last)
    var options = AssistantContextOptions()
    options.boardIDs = [last.id]
    for scope in AssistantContextScope.allCases {
      options.scope = scope
      let context = try store.assistantContext(
        worldID: world.id, prompt: "Arrange", options: options)
      #expect(context.workspace.contains(last.id))
    }
  }

  @Test func archivedExclusionsSurviveReloadAndRestoreWithoutReintroducingHistory() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Excluded history")
    let record = try store.createRecord(worldID: world.id, title: "Private lore")
    var options = AssistantContextOptions()
    options.excludedRecordIDs = [record.id]
    try store.setAssistantContextOptions(worldID: world.id, options: options)
    try store.archiveRecord(worldID: world.id, id: record.id)
    let restored = try store.assistantContextOptions(worldID: world.id)
    #expect(restored.excludedRecordIDs == [record.id])
    #expect(
      try !store.assistantContext(worldID: world.id, prompt: "Hello", options: restored)
        .includesHistory)
    try store.setAssistantContextOptions(worldID: world.id, options: restored)
    try store.restoreRecord(worldID: world.id, id: record.id)
    let afterUndo = try store.assistantContext(
      worldID: world.id, prompt: "Private lore",
      options: store.assistantContextOptions(worldID: world.id))
    #expect(afterUndo.sources.isEmpty)
    #expect(!afterUndo.includesHistory)
  }

  @Test func truncatedBoardPlacementsRetainTheirActualTotal() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Large board")
    let record = try store.createRecord(worldID: world.id, title: "Repeated reference")
    let cards = (0..<90).map { ["recordID": record.id, "id": "card-\($0)"] }
    let board = try store.saveBoard(
      worldID: world.id, name: "Placements", kind: "canvas",
      content: String(
        decoding: JSONSerialization.data(withJSONObject: ["cards": cards]), as: UTF8.self))
    var options = AssistantContextOptions()
    options.boardIDs = [board.id]
    let context = try store.assistantContext(worldID: world.id, prompt: "Arrange", options: options)
    let json = try #require(
      JSONSerialization.jsonObject(with: Data(context.workspace.utf8)) as? [String: Any])
    let item = try #require((json["boards"] as? [[String: Any]])?.first)
    #expect((item["placements"] as? [[String: Any]])?.count == 80)
    #expect(item["totalPlacements"] as? Int == 90)
  }

  @Test func attachedHistoryIncludesDescendantsAndExclusionsStillWin() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History context")
    let branch = try store.createChronologyLane(
      worldID: world.id, name: "Eastern history", kind: "branch")
    let child = try store.createChronologyLane(
      worldID: world.id, name: "Year 60", kind: "period", parentID: branch.id)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Freezing sea", date: "Year 60", source: nil, order: nil,
      laneID: child.id)
    var options = AssistantContextOptions()
    options.scope = .attachments
    options.laneIDs = [branch.id]
    let context = try store.assistantContext(worldID: world.id, prompt: "History", options: options)
    #expect(context.sources.map(\.id) == [event.sourceID])
    #expect(context.workspace.contains(child.id))
    options.excludedRecordIDs = [event.sourceID]
    let filtered = try store.assistantContext(
      worldID: world.id, prompt: "History", options: options)
    #expect(filtered.sources.isEmpty)
    #expect(!filtered.workspace.contains("Freezing sea"))
  }

  @Test func explicitlyAttachedHistoryIsPrioritizedOverTheUnfilteredIndex() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Many histories")
    for index in 0..<65 {
      try store.createChronologyLane(worldID: world.id, name: "Period \(index)", kind: "period")
    }
    let lane = try #require(store.chronologyLanes(worldID: world.id).last)
    var options = AssistantContextOptions()
    options.laneIDs = [lane.id]
    let context = try store.assistantContext(worldID: world.id, prompt: "History", options: options)
    #expect(context.workspace.contains(lane.id))
  }

  @Test func archivedAttachmentsArePrunedOnReloadButRejectedAtSubmission() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Archived")
    let record = try store.createRecord(worldID: world.id, title: "Old context")
    var options = AssistantContextOptions()
    options.recordIDs = [record.id]
    try store.setAssistantContextOptions(worldID: world.id, options: options)
    try store.archiveRecord(worldID: world.id, id: record.id)
    #expect(try store.assistantContextOptions(worldID: world.id).recordIDs.isEmpty)
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    await #expect(throws: (any Error).self) {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Read", preset: "Create",
        contextOptions: options
      ) { _ in }
    }
    #expect(await transport.calls == 0)
    #expect(try store.messages(worldID: world.id, conversationID: chat.id).isEmpty)
  }

  @Test func attachmentsOnlyDoesNotFallBackToRecentLoreOrForeignIDs() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Local")
    let foreign = try store.createWorld(name: "Foreign")
    let local = try store.createRecord(worldID: world.id, title: "Selected", body: "Kept")
    let unrelated = try store.createRecord(worldID: world.id, title: "Unrelated", body: "OMIT_ME")
    let outsider = try store.createRecord(worldID: foreign.id, title: "Other universe")
    var options = AssistantContextOptions()
    options.scope = .attachments
    let empty = try store.assistantContext(worldID: world.id, prompt: "Unrelated", options: options)
    #expect(empty.sources.isEmpty)
    #expect(!empty.workspace.contains(unrelated.id))
    options.recordIDs = [local.id]
    let context = try store.assistantContext(
      worldID: world.id, prompt: "Unrelated", options: options)
    #expect(context.sources.map(\.id) == [local.id])
    #expect(!context.workspace.contains("Unrelated"))
    options.recordIDs = [outsider.id]
    #expect(throws: Error.self) {
      try store.assistantContext(worldID: world.id, prompt: "Test", options: options)
    }
  }

  @Test func boardAttachmentsShareLinkedLoreNotImageBytes() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Board")
    let record = try store.createRecord(worldID: world.id, title: "Mira", body: "A cartographer")
    let board = try store.saveBoard(
      worldID: world.id, id: nil, name: "Crossing", kind: "canvas",
      content:
        "{\"cards\":[{\"recordID\":\"\(record.id)\",\"x\":42,\"y\":80}],\"image\":\"IMAGE_BYTES\"}")
    var options = AssistantContextOptions()
    options.scope = .attachments
    options.boardIDs = [board.id]
    let context = try store.assistantContext(worldID: world.id, prompt: "Explain", options: options)
    #expect(context.sources.map(\.id) == [record.id])
    #expect(context.workspace.contains(board.id))
    #expect(!context.workspace.contains("IMAGE_BYTES"))
    #expect(context.sources.first?.reason.contains("Crossing") == true)
  }

  @Test func contextChoicesPersistPerWorldAndPinnedRecordsCannotSilentlyOverflow() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    var store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "One")
    let other = try store.createWorld(name: "Two")
    var options = AssistantContextOptions()
    options.intent = .explore
    options.scope = .attachments
    options.includeSelection = false
    options.budget = .focused
    for index in 0..<9 {
      options.recordIDs.append(
        try store.createRecord(worldID: world.id, title: "Record \(index)").id)
    }
    try store.setAssistantContextOptions(worldID: world.id, options: options)
    store = try WorkspaceStore(path: path)
    #expect(try store.assistantContextOptions(worldID: world.id) == options)
    #expect(try store.assistantContextOptions(worldID: other.id) == AssistantContextOptions())
    #expect(throws: Error.self) {
      try store.assistantContext(worldID: world.id, prompt: "Test", options: options)
    }
    options.budget = .broad
    #expect(
      try store.assistantContext(worldID: world.id, prompt: "Test", options: options).sources.count
        == 9)
  }
}
