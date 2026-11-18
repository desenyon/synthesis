import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct PriorProposalPrivacyTests {
  @Test func earlierProposalCannotReintroduceExcludedIndexOnlyLore() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Proposal provenance")
    let secret = try store.createRecord(
      worldID: world.id, title: "PRIVATE_INDEX_ONLY", body: "PRIVATE_BODY")
    var earlierOptions = AssistantContextOptions()
    earlierOptions.budget = .focused
    earlierOptions.includeHistory = false
    for index in 1...earlierOptions.budget.limit {
      let record = try store.createRecord(worldID: world.id, title: "Attached record \(index)")
      earlierOptions.recordIDs.append(record.id)
    }
    let earlierPreview = try store.assistantContext(
      worldID: world.id, prompt: "Suggest a document.", options: earlierOptions)
    #expect(earlierPreview.workspace.contains(secret.title))
    #expect(!earlierPreview.sources.contains { $0.id == secret.id })

    let conversation = try store.createConversation(worldID: world.id)
    let answer = """
      Here is a possible idea.
      ```synthesis-proposal
      {"summary":"PRIVATE_INDEX_ONLY proposal","changes":[{"action":"create_record","title":"PRIVATE_INDEX_ONLY notes"}]}
      ```
      """
    try await AgentEngine(store: store, transport: ScriptedTransport(answer: answer)).submit(
      worldID: world.id, conversationID: conversation.id, prompt: "Suggest a document.",
      preset: "Develop", contextOptions: earlierOptions
    ) { _ in }
    let proposal = try #require(try store.proposals(worldID: world.id).first)
    let address = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
    let source = try store.resolveReference(address, worldID: world.id)
    #expect(!source.exclusionRecordIDs.contains(secret.id))

    var options = AssistantContextOptions()
    options.excludedRecordIDs = [secret.id]
    let transport = CountingTransport()
    let prompt = "What about \(source.markdown)?"
    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: conversation.id, prompt: prompt, preset: "Develop",
      contextOptions: options
    ) { _ in }

    let request = try #require(await transport.lastRequest)
    let input = try #require(request.messages.last?["content"])
    #expect(input == "What about [Excluded source]?")
    #expect(!request.instructions.contains("PRIVATE_"))
    #expect(!request.instructions.contains(proposal.id))
    let messages = try store.messages(worldID: world.id, conversationID: conversation.id)
    #expect(messages.last { $0.role == "user" }?.body == prompt)
  }
}
