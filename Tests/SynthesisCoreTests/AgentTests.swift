import Foundation
import Testing

@testable import SynthesisCore

actor CountingTransport: ModelTransport {
  var calls = 0
  var lastRequest: ModelRequest?
  let delayed: Bool
  init(delayed: Bool = false) { self.delayed = delayed }
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    calls += 1
    lastRequest = request
    if delayed { try await Task.sleep(for: .seconds(30)) }
    await onDelta("A possible idea")
    return "A possible idea"
  }
}
/// Returns a fixed answer, as a provider would. Used to test what the app does with model output.
struct ScriptedTransport: ModelTransport {
  let answer: String
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    await onDelta(answer)
    return answer
  }
}
@MainActor struct AgentTests {
  @Test func simulationActivityRemainsExplicitlyHypothetical() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Isolated")
    let chat = try store.createConversation(worldID: world.id)
    let engine = AgentEngine(
      store: store, transport: ScriptedTransport(answer: "A possible outcome."))
    var activity: [AgentActivity] = []
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Explore this situation",
      preset: "Simulate", onActivity: { activity.append($0) }, onDelta: { _ in })
    let running = try #require(activity.first { $0.id == "response" && $0.state == .running })
    #expect(running.title == "Exploring hypothetical outcomes")
    #expect(running.detail.contains("not a deterministic simulation"))
    #expect(activity.last?.state == .complete)
    #expect(try store.records(worldID: world.id).isEmpty)
  }

  @Test func workspaceContextChangesWithoutLeakingOtherUniverses() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Chosen universe")
    let foreign = try store.createWorld(name: "Private other universe")
    try store.createRecord(worldID: foreign.id, title: "PRIVATE_SENTINEL", body: "Never included")
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    for workspace in ["Timeline", "Atlas"] {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "What can I do here?",
        preset: "Develop", workspaceName: workspace
      ) { _ in }
      let request = try #require(await transport.lastRequest)
      #expect(request.instructions.contains("Current workspace: \(workspace)"))
      #expect(!request.instructions.contains("PRIVATE_SENTINEL"))
      #expect(!request.instructions.contains("Private other universe"))
    }
  }

  @Test func oneNaturalLanguageRequestStagesThreeConnectedFactionDrafts() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "The old coast")
    let existing = try store.createRecord(
      worldID: world.id, title: "Salt League", kind: "entity", category: "Systems")
    let order = try store.createRecord(
      worldID: world.id, title: "Tidekeepers", kind: "entity", category: "Systems")
    let canon = try store.promote(
      worldID: world.id, id: order.id, version: order.version, confirmation: order.id)
    let chat = try store.createConversation(worldID: world.id)
    let answer = """
      These three coastal factions would compete with the Tidekeepers.

      ```synthesis-proposal
      {"summary":"Three competing coastal factions","changes":[
        {"action":"create_record","ref":"salt","kind":"entity","title":"Salt League","category":"Systems"},
        {"action":"create_record","ref":"reef","kind":"entity","title":"Reef Court","category":"Systems"},
        {"action":"create_record","ref":"shoal","kind":"entity","title":"Shoal Assembly","category":"Systems"},
        {"action":"relate","source":"$salt","target":"\(order.id)","label":"competes with"},
        {"action":"relate","source":"$reef","target":"\(order.id)","label":"competes with"},
        {"action":"relate","source":"$shoal","target":"\(order.id)","label":"competes with"},
        {"action":"relate","source":"Salt League","target":"\(order.id)","label":"ambiguous"}
      ]}
      ```
      """
    let engine = AgentEngine(store: store, transport: ScriptedTransport(answer: answer))
    try await engine.submit(
      worldID: world.id, conversationID: chat.id,
      prompt: "Create three competing coastal factions and connect them to the Tidekeepers.",
      preset: "Create"
    ) { _ in }
    let proposal = try #require(try store.proposals(worldID: world.id).first)
    #expect(proposal.changes.count == 6 && proposal.pending == 6)
    #expect(proposal.summary.contains("1 unsupported or invalid"))
    #expect(try store.records(worldID: world.id).count == 2)
    #expect(try store.relations(worldID: world.id).isEmpty)

    let declarations = Array(proposal.changes.prefix(3))
    let relationships = Array(proposal.changes.suffix(3))
    for (creation, relationship) in zip(declarations, relationships) {
      #expect(proposal.prerequisites(for: relationship).map(\.id) == [creation.id])
      #expect(throws: SynthesisError.self) {
        try store.resolveChange(
          worldID: world.id, proposalID: proposal.id, changeID: relationship.id,
          accept: true, confirmation: proposal.id)
      }
    }
    var reviewed = proposal
    for change in proposal.changes {
      reviewed = try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: change.id,
        accept: true, confirmation: proposal.id)
    }
    #expect(reviewed.pending == 0)
    let created = Set(reviewed.changes.prefix(3).compactMap(\.resultID))
    let edges = try store.relations(worldID: world.id)
    #expect(created.count == 3 && !created.contains(existing.id))
    #expect(Set(edges.map(\.sourceID)) == created)
    #expect(edges.allSatisfy { $0.targetID == order.id && $0.label == "competes with" })
    let records = try store.records(worldID: world.id).filter { created.contains($0.id) }
    #expect(records.allSatisfy { $0.state == "draft" && $0.canonical == nil })
    #expect(try store.record(worldID: world.id, id: order.id) == canon)
  }

  @Test func localProposalKeysRejectAmbiguousInvalidAndWrongKindDependencies() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Key validation")
    let target = try store.createRecord(worldID: world.id, title: "Keeper", kind: "entity")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "kind": "entity", "ref": "repeat", "title": "First"],
            ["action": "create_record", "kind": "entity", "ref": "repeat", "title": "Second"],
            ["action": "create_record", "kind": "entity", "ref": "bad/key", "title": "Bad key"],
            ["action": "create_record", "kind": "lore", "ref": "memo", "title": "Memo"],
            ["action": "relate", "source": "$repeat", "target": target.id, "label": "rivals"],
            ["action": "relate", "source": "$memo", "target": target.id, "label": "rivals"],
          ]
        ]))
    #expect(proposal.changes.map(\.title) == ["Memo"])
    #expect(proposal.summary.contains("5 unsupported or invalid"))
    #expect(try store.records(worldID: world.id) == [target])
  }

  @Test func modelChangeSetIsStagedForReviewAndNeverApplied() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "Aster")
    let other = try s.createWorld(name: "Elsewhere")
    let foreign = try s.createRecord(worldID: other.id, title: "Foreign", kind: "entity")
    var mira = try s.createRecord(
      worldID: w.id, title: "Mira Vale", body: "A cartographer.", kind: "entity",
      category: "Characters")
    mira = try s.promote(worldID: w.id, id: mira.id, version: mira.version, confirmation: mira.id)
    let chat = try s.createConversation(worldID: w.id)
    let answer = """
      Here is a mentor for Mira.

      ```synthesis-proposal
      {"summary":"Add Oren Ashe and connect him to Mira","changes":[
        {"action":"create_record","kind":"entity","title":"Oren Ashe","category":"Characters","body":"Eldest of the keepers.","evidence":["\(mira.id)","not-a-record"]},
        {"action":"relate","source":"Oren Ashe","target":"\(mira.id)","label":"mentors"},
        {"action":"revise_record","id":"\(mira.id)","body":"A cartographer trained by Oren Ashe.","reason":"Reflect the mentor"},
        {"action":"add_event","title":"Oren takes an apprentice","source":"Oren Ashe"},
        {"action":"revise_record","id":"\(foreign.id)","body":"Cross-world edit"},
        {"action":"promote_to_canon","id":"\(mira.id)"}
      ]}
      ```
      """
    let engine = AgentEngine(store: s, transport: ScriptedTransport(answer: answer))
    try await engine.submit(
      worldID: w.id, conversationID: chat.id,
      prompt: "Give [Mira Vale](synthesis://record/\(mira.id)) a mentor", preset: "Canonize"
    ) { _ in }

    // The transcript keeps the prose; the machine-readable block is not shown as text.
    let reply = try #require(try s.messages(worldID: w.id, conversationID: chat.id).last)
    #expect(reply.role == "assistant" && reply.body == "Here is a mentor for Mira.")
    // The context actually sent is recorded with the answer.
    let context = try s.messageContext(worldID: w.id, conversationID: chat.id)[reply.id]
    #expect(context?.first?.record.id == mira.id && context?.first?.reason == "You referenced it")

    // Staged, validated and scoped: foreign and unknown actions are dropped, nothing is applied.
    var proposal = try #require(try s.proposals(worldID: w.id, conversationID: chat.id).first)
    #expect(proposal.messageID == reply.id && proposal.state == "pending")
    #expect(
      proposal.changes.map(\.action) == ["create_record", "relate", "revise_record", "add_event"])
    #expect(proposal.changes[0].evidence == [mira.id])
    #expect(try s.records(worldID: w.id).count == 1 && s.relations(worldID: w.id).isEmpty)
    #expect(try s.record(worldID: w.id, id: mira.id).state == "canon")
    #expect(try s.proposals(worldID: other.id).isEmpty)

    // Only an explicit, correctly scoped confirmation can resolve a change.
    let create = proposal.changes[0]
    let relate = proposal.changes[1]
    #expect(throws: Error.self) {
      try s.resolveChange(
        worldID: w.id, proposalID: proposal.id, changeID: create.id, accept: true,
        confirmation: "")
    }
    #expect(throws: Error.self) {
      try s.resolveChange(
        worldID: other.id, proposalID: proposal.id, changeID: create.id, accept: true,
        confirmation: proposal.id)
    }
    // A change that depends on an unaccepted record explains itself and changes nothing.
    #expect(throws: Error.self) {
      try s.resolveChange(
        worldID: w.id, proposalID: proposal.id, changeID: relate.id, accept: true,
        confirmation: proposal.id)
    }
    #expect(try s.relations(worldID: w.id).isEmpty)

    proposal = try s.resolveChange(
      worldID: w.id, proposalID: proposal.id, changeID: create.id, accept: true,
      confirmation: proposal.id)
    let oren = try s.record(worldID: w.id, id: try #require(proposal.changes[0].resultID))
    #expect(oren.origin == "ai-proposed" && oren.state == "draft" && oren.canonical == nil)
    proposal = try s.resolveChange(
      worldID: w.id, proposalID: proposal.id, changeID: relate.id, accept: true,
      confirmation: proposal.id)
    #expect(try s.relations(worldID: w.id).first?.label == "mentors")

    // Accepting a revision makes a draft; the accepted canon snapshot is preserved.
    proposal = try s.resolveChange(
      worldID: w.id, proposalID: proposal.id, changeID: proposal.changes[2].id, accept: true,
      confirmation: proposal.id)
    let revised = try s.record(worldID: w.id, id: mira.id)
    #expect(revised.body == "A cartographer trained by Oren Ashe." && revised.state == "draft")
    #expect(
      revised.canonical == mira.canonical && revised.canonical?.contains("A cartographer.") == true)

    proposal = try s.resolveChange(
      worldID: w.id, proposalID: proposal.id, changeID: proposal.changes[3].id, accept: false,
      confirmation: proposal.id)
    #expect(proposal.state == "accepted" && proposal.pending == 0)
    #expect(try s.events(worldID: w.id).isEmpty)
    // Resolving again is a no-op rather than a duplicate.
    _ = try s.resolveChange(
      worldID: w.id, proposalID: proposal.id, changeID: create.id, accept: true,
      confirmation: proposal.id)
    #expect(try s.records(worldID: w.id).count == 2)
  }
  @Test func staleProposalCannotOverwriteNewWriting() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Revision boundary")
    let record = try store.createRecord(worldID: world.id, title: "Law", body: "Original")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [["action": "revise_record", "id": record.id, "body": "AI replacement"]]
        ]))
    _ = try store.saveRecord(
      worldID: world.id, id: record.id, version: record.version,
      title: record.title, body: "New writing", rtf: nil)
    #expect(throws: SynthesisError.self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id,
        changeID: proposal.changes[0].id, accept: true, confirmation: proposal.id)
    }
    #expect(try store.record(worldID: world.id, id: record.id).body == "New writing")
    #expect(try store.proposal(worldID: world.id, id: proposal.id).pending == 1)
  }
  @Test func streamingTextHidesAnUnfinishedChangeSet() {
    #expect(ProposalParser.visible("Idea.\n\n```synthesis-proposal\n{\"sum") == "Idea.")
    #expect(ProposalParser.visible("Plain answer") == "Plain answer")
    let broken = ProposalParser.split("Text\n```synthesis-proposal\n{not json\n```\nafter")
    #expect(broken.payload == nil && broken.prose == "Text\n\nafter")
  }
  @Test func manualModeBlocksTransportAtCoreBoundary() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "A")
    let c = try s.createConversation(worldID: w.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: s, transport: transport)
    try engine.setMode(.manual)
    await #expect(throws: Error.self) {
      try await engine.submit(
        worldID: w.id, conversationID: c.id, prompt: "Hello", preset: "Create"
      ) { _ in }
    }
    #expect(await transport.calls == 0)
    #expect(try s.messages(worldID: w.id, conversationID: c.id).isEmpty)
  }
  @Test func switchingToManualCancelsInFlightAndDoesNotPersistAssistant() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "A")
    let c = try s.createConversation(worldID: w.id)
    let transport = CountingTransport(delayed: true)
    let engine = AgentEngine(store: s, transport: transport)
    let task = Task {
      try await engine.submit(
        worldID: w.id, conversationID: c.id, prompt: "Hello", preset: "Develop"
      ) { _ in }
    }
    while await transport.calls == 0 { await Task.yield() }
    try engine.setMode(.manual)
    do {
      try await task.value
      Issue.record("Request should be cancelled")
    } catch {}
    #expect(
      try s.messages(worldID: w.id, conversationID: c.id).filter { $0.role == "assistant" }.isEmpty)
    #expect(try s.preference("mode") == "manual")
  }
  @Test func responsesPersistWithoutChangingCanon() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "A")
    let c = try s.createConversation(worldID: w.id)
    let r = try s.createRecord(worldID: w.id, title: "Rule", body: "One moon")
    let engine = AgentEngine(store: s, transport: CountingTransport())
    try await engine.submit(worldID: w.id, conversationID: c.id, prompt: "Expand", preset: "Create")
    { _ in }
    #expect(
      try s.messages(worldID: w.id, conversationID: c.id).map(\.role) == ["user", "assistant"])
    #expect(try s.record(worldID: w.id, id: r.id).canonical == nil)
  }
  @Test func cancellationBeforeQueuedSubmitNeverStartsTransport() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "A")
    let conversation = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    let task = Task {
      try await engine.submit(
        worldID: world.id, conversationID: conversation.id, prompt: "Do not send", preset: "Create"
      ) { _ in }
    }
    engine.cancel()
    task.cancel()
    do {
      try await task.value
      Issue.record("A queued cancelled submission must not run")
    } catch {}
    #expect(await transport.calls == 0)
    #expect(try store.messages(worldID: world.id, conversationID: conversation.id).isEmpty)
  }
  @Test func canonicalContextExcludesRichTextPayload() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Context")
    var record = try store.createRecord(
      worldID: world.id, title: "Rule", body: "Accepted law: there is only one moon.")
    record = try store.saveRecord(
      worldID: world.id, id: record.id, version: record.version, title: record.title,
      body: record.body, rtf: String(repeating: "RTFPAYLOAD", count: 2000))
    record = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    _ = try store.saveRecord(
      worldID: world.id, id: record.id, version: record.version, title: record.title,
      body: "A draft with two moons.", rtf: nil)
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Check the moons", preset: "Critique"
    ) { _ in }
    let instructions = await transport.lastRequest?.instructions ?? ""
    #expect(instructions.contains("Accepted law: there is only one moon."))
    #expect(instructions.contains("A draft with two moons."))
    #expect(!instructions.contains("RTFPAYLOAD"))
  }
}
