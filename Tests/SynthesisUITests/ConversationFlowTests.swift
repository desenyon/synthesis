import AppKit
import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

actor RecordingResponse: ModelTransport {
  private(set) var requests: [ModelRequest] = []
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    requests.append(request)
    await onDelta("A grounded response")
    return "A grounded response"
  }
}

@MainActor struct ConversationFlowTests {
  @Test func continueIncludesTheSavedInterruptedResponse() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    let chat = try store.createConversation(worldID: studio.worldID)
    try store.appendMessage(
      worldID: studio.worldID, conversationID: chat.id, role: "assistant",
      body: "A northern crossing", state: "interrupted")
    studio.conversationID = chat.id
    studio.draft = "Continue that idea"
    studio.send()
    try await finish(studio)
    let request = try #require(await transport.requests.last)
    #expect(
      request.messages.contains {
        $0["content"] == "[This response ended before completion.]\nA northern crossing"
      })
  }
  @Test func retryPreservesNewDraftAndCompanionWidthSurvivesRestart() throws {
    let store = try WorkspaceStore(path: ":memory:")
    try store.setPreference("companion-width", value: "438")
    let studio = try Studio(store: store, transport: RecordingResponse())
    let chat = try store.createConversation(worldID: studio.worldID)
    try store.appendMessage(
      worldID: studio.worldID, conversationID: chat.id, role: "user", body: "Original question",
      state: "complete")
    let failure = try store.appendMessage(
      worldID: studio.worldID, conversationID: chat.id, role: "system", body: "Connection failed",
      state: "error")
    studio.conversationID = chat.id
    try studio.reload()
    studio.draft = "A newer thought"
    studio.prepareRetry(after: failure.id)
    studio.prepareRetry(after: failure.id)
    #expect(studio.draft == "Original question\n\nA newer thought")
    #expect(try store.preference("composer:\(studio.worldID)") == studio.draft)
    #expect(studio.companionWidth == 438)
    #expect(!studio.busy)
  }
  @Test func canvasIsHiddenWhenConversationTakesOverACompactWindow() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: RecordingResponse())
    studio.destination = .canvas
    studio.companionExpanded = true
    #expect(!studio.canvasVisible(windowWidth: 1024))
    #expect(studio.canvasVisible(windowWidth: 1440))
    studio.mode = .manual
    #expect(studio.canvasVisible(windowWidth: 1024))
    studio.destination = .atlas
    #expect(!studio.canvasVisible(windowWidth: 1440))
  }
  @Test func transcriptObserverRespectsScrollingAwayAndReturningToLatest() async throws {
    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    let document = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 1600))
    let observer = TranscriptScrollObserver.ObserverView()
    document.addSubview(observer)
    scroll.documentView = document
    var follows: [Bool] = []
    observer.changed = { follows.append($0) }
    observer.viewDidMoveToWindow()
    try await Task.sleep(for: .milliseconds(10))
    scroll.contentView.scroll(to: CGPoint(x: 0, y: 200))
    try await Task.sleep(for: .milliseconds(10))
    #expect(follows.last == false)
    scroll.contentView.scroll(to: CGPoint(x: 0, y: 1200))
    try await Task.sleep(for: .milliseconds(10))
    #expect(follows.last == true)
    observer.detach()
  }
  private func finish(_ studio: Studio) async throws {
    for _ in 0..<200 where studio.busy { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!studio.busy && studio.error == nil)
  }
  @Test func requestFollowsSelectedGraphTimelineAtlasAndEditorContext() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    let entity = try store.createRecord(
      worldID: studio.worldID, title: "Selected person", kind: "entity")
    let lane = try store.createChronologyLane(
      worldID: studio.worldID, name: "Chosen branch", kind: "branch")
    let map = try store.createAtlasMap(worldID: studio.worldID, name: "Active map")
    try studio.reload()
    studio.graphSelectedID = entity.id
    studio.timelineLaneID = lane.id
    studio.atlasSelectedID = entity.id
    studio.mapBoardID = map.id
    for destination in [Destination.knowledge, .timeline, .atlas] {
      studio.navigate(destination)
      studio.draft = "Develop this selection"
      studio.send(keepWorkspace: true)
      try await finish(studio)
      let request = try #require(await transport.requests.last)
      #expect(request.instructions.contains("Current workspace: \(destination.rawValue)"))
      if destination == .timeline {
        #expect(request.instructions.contains("\"activeChronologyLane\":\"\(lane.id)\""))
      } else {
        #expect(request.instructions.contains("Selected records: \(entity.id)"))
        #expect(!request.instructions.contains("\"activeChronologyLane\":\"\(lane.id)\""))
      }
    }
    studio.openRecord(entity)
    studio.draft = "Revise this record"
    studio.send(keepWorkspace: true)
    try await finish(studio)
    #expect(
      await transport.requests.last?.instructions.contains("Current workspace: Editor in Atlas")
        == true)
    #expect(await transport.requests.count == 4)
    let other = try store.createWorld(name: "Other")
    studio.switchWorld(other.id)
    #expect(studio.contextualRecordIDs.isEmpty && studio.timelineLaneID == nil)
    #expect(await transport.requests.count == 4, "Navigation must not generate requests")
  }

  @Test func immediateStopRestoresAnUnsentDraftWithoutCallingTheProvider() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    studio.draft = "Preserve this thought"
    studio.send()
    studio.stop()
    try await Task.sleep(for: .milliseconds(20))
    #expect(studio.draft == "Preserve this thought")
    #expect(try store.preference("composer:\(studio.worldID)") == studio.draft)
    #expect(await transport.requests.isEmpty)
    #expect(!studio.busy)
  }
}
