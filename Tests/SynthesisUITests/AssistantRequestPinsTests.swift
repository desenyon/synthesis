import Combine
import SynthesisCore
import Testing

@testable import SynthesisUI

private struct PausedPinResponse: ModelTransport {
  let requests = AsyncStream<ModelRequest>.makeStream()
  let release = AsyncStream<Void>.makeStream()

  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    requests.continuation.yield(request)
    var gate = release.stream.makeAsyncIterator()
    _ = await gate.next()
    try Task.checkCancellation()
    return "A grounded response"
  }
}

@MainActor struct AssistantRequestPinsTests {
  @Test func previewMatchesOneRequestAndAdmissionClearsOnlyTheTemporaryPins() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = PausedPinResponse()
    defer {
      transport.release.continuation.finish()
      transport.requests.continuation.finish()
    }
    let studio = try Studio(store: store, transport: transport)
    let world = studio.worldID
    let mira = try store.createRecord(
      worldID: world, title: "Mira Vale", body: "Mira charts the surf.", kind: "entity")
    let keepers = try store.createRecord(
      worldID: world, title: "Tidekeepers", body: "The keepers tend the harbor.", kind: "entity")
    let attached = try store.createRecord(
      worldID: world, title: "Saved harbor notes", body: "The western pier needs a ledger.")
    let period = try store.createChronologyLane(worldID: world, name: "Year 40", kind: "period")
    let event = try store.saveChronologyEvent(
      worldID: world, id: nil, title: "First winter crossing", date: "Year 40", source: nil,
      order: nil, laneID: period.id)
    try studio.reload()
    studio.updateContext {
      $0.scope = .attachments
      $0.includeSelection = false
      $0.recordIDs = [attached.id]
    }
    let saved = studio.contextOptions
    studio.updateRequestPins {
      $0.recordIDs = [mira.id, keepers.id]
      $0.laneIDs = [period.id]
    }
    studio.draft = "What changed at the harbor?"
    let preview = try studio.previewContext(prompt: studio.draft)
    let expectedSources = Set([attached.id, mira.id, keepers.id, event.sourceID])
    #expect(Set(preview.sources.map(\.id)) == expectedSources)
    #expect(preview.workspace.contains(period.id))
    #expect(preview.workspace.contains("First winter crossing"))
    #expect(try store.assistantContextOptions(worldID: world) == saved)
    let reopened = try Studio(store: store, transport: RecordingResponse())
    #expect(reopened.activeRequestPins.isEmpty)

    studio.send()
    let request = try await waitFor("the admitted request") {
      await transport.requests.stream.first { _ in true }
    }
    #expect(studio.busy)
    #expect(request.instructions.contains(preview.lore))
    #expect(request.instructions.contains(preview.workspace))
    #expect(studio.activeRequestPins.isEmpty)
    #expect(studio.contextOptions == saved)
    #expect(try store.assistantContextOptions(worldID: world) == saved)

    transport.release.continuation.finish()
    try await finish(studio)
    let next = try studio.previewContext(prompt: "What else should I know?")
    #expect(next.sources.map(\.id) == [attached.id])
    #expect(!next.workspace.contains(period.id))
  }

  @Test func blockedAndImmediatelyCancelledSubmissionsPreserveTheDraftAndPins() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    let record = try store.createRecord(worldID: studio.worldID, title: "Remember this lighthouse")
    try studio.reload()
    studio.updateRequestPins { $0.recordIDs = [record.id] }
    let prompt = "Keep this thought"
    studio.draft = prompt

    studio.setMode(.manual)
    studio.send()
    #expect(!studio.busy)
    #expect(studio.activeRequestPins.recordIDs == [record.id])
    #expect(studio.draft == prompt)

    studio.setMode(.assisted)
    studio.editorSave = { false }
    studio.send()
    #expect(!studio.busy)
    #expect(studio.activeRequestPins.recordIDs == [record.id])
    #expect(studio.draft == prompt)

    studio.editorSave = nil
    studio.send()
    #expect(studio.busy)
    let revision = studio.worldRevision
    // Both calls are synchronous on MainActor; the submission task has yet to run.
    studio.stop()
    _ = try await waitFor("the stopped request to drain") {
      await studio.$worldRevision.values.first { $0 > revision }
    }
    #expect(!studio.busy)
    #expect(studio.activeRequestPins.recordIDs == [record.id])
    #expect(studio.draft == prompt)
    #expect(try store.preference("composer:\(studio.worldID)") == prompt)
    #expect(await transport.requests.isEmpty)
  }

  @Test func pinsRespectExclusionsAndCannotFollowSendIntoAnotherUniverse() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    let world = studio.worldID
    let allowed = try store.createRecord(worldID: world, title: "VISIBLE_SOURCE")
    let hidden = try store.createRecord(
      worldID: world, title: "EXCLUDED_SOURCE", body: "EXCLUDED_BODY")
    let period = try store.createChronologyLane(
      worldID: world, name: "PRIVATE_PERIOD", kind: "period")
    _ = try store.saveChronologyEvent(
      worldID: world, id: nil, title: "EXCLUDED_EVENT", date: "Year 2", source: hidden.id,
      order: nil, laneID: period.id)
    let board = try store.createAtlasMap(worldID: world, name: "PRIVATE_MAP")
    let other = try store.createWorld(name: "Another universe")
    let foreign = try store.createRecord(worldID: other.id, title: "FOREIGN_SOURCE")
    let foreignMap = try store.createAtlasMap(worldID: other.id, name: "FOREIGN_MAP")
    let foreignPeriod = try store.createChronologyLane(
      worldID: other.id, name: "FOREIGN_PERIOD", kind: "period")
    try studio.reload()
    studio.updateRequestPins {
      $0.recordIDs = [allowed.id, hidden.id, foreign.id]
      $0.boardIDs = [board.id, foreignMap.id]
      $0.laneIDs = [period.id, foreignPeriod.id]
    }
    studio.updateContext {
      $0.scope = .attachments
      $0.excludedRecordIDs = [hidden.id]
    }
    studio.draft = "What's visible?"
    let preview = try studio.previewContext(prompt: studio.draft)
    #expect(studio.activeRequestPins.recordIDs == [allowed.id])
    #expect(studio.activeRequestPins.boardIDs == [board.id])
    #expect(studio.activeRequestPins.laneIDs == [period.id])
    #expect(preview.sources.map(\.id) == [allowed.id])
    #expect(preview.workspace.contains(period.id) && preview.workspace.contains(board.id))
    studio.send()
    try await finish(studio)
    let first = try #require(await transport.requests.last)
    #expect(first.instructions.contains(preview.workspace))
    #expect(first.instructions.contains("VISIBLE_SOURCE"))
    for omitted in [
      "EXCLUDED_SOURCE", "EXCLUDED_BODY", "EXCLUDED_EVENT", "FOREIGN_SOURCE", "FOREIGN_MAP",
      "FOREIGN_PERIOD",
    ] {
      #expect(!first.instructions.contains(omitted))
    }
    #expect(studio.activeRequestPins.isEmpty)

    studio.updateRequestPins {
      $0.recordIDs = [allowed.id]
      $0.boardIDs = [board.id]
      $0.laneIDs = [period.id]
    }
    studio.switchWorld(other.id)
    #expect(studio.worldID == other.id)
    #expect(studio.activeRequestPins.isEmpty)
    studio.updateContext { $0.scope = .attachments }
    studio.draft = "Anything here yet?"
    let otherPreview = try studio.previewContext(prompt: studio.draft)
    #expect(otherPreview.sources.isEmpty)
    studio.send()
    try await finish(studio)
    let requests = await transport.requests
    #expect(requests.count == 2)
    let second = try #require(requests.last)
    for omitted in ["VISIBLE_SOURCE", "EXCLUDED_SOURCE", "PRIVATE_MAP", "PRIVATE_PERIOD"] {
      #expect(!second.instructions.contains(omitted))
    }
  }

  private func finish(_ studio: Studio) async throws {
    _ = try await waitFor("the response to finish") {
      await studio.$busy.values.first { !$0 }
    }
    #expect(studio.error == nil)
  }

  /// Wait for an observed admission, response, or cancellation milestone with a failure deadline.
  private func waitFor<Value: Sendable>(
    _ description: String, observe: @escaping @MainActor @Sendable () async -> Value?
  ) async throws -> Value {
    try await withThrowingTaskGroup(of: Value?.self) { group in
      group.addTask { await observe() }
      group.addTask {
        try await Task.sleep(for: .seconds(10))
        return nil
      }
      defer { group.cancelAll() }
      let value = try await group.next() ?? nil
      return try #require(value, "Timed out waiting for \(description).")
    }
  }
}
