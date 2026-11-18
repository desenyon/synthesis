import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct PinnedHistoryContextTests {
  @Test(arguments: [AssistantContextScope.world, .attachments], [false, true])
  func pinnedHistoryKeepsItsEventAndPlacementWhenOrdinaryHistoryFillsTheIndex(
    scope: AssistantContextScope, applyExclusions: Bool
  ) async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Many periods")
    let commonSource = try store.createRecord(worldID: world.id, title: "Ordinary source")
    var options = AssistantContextOptions()
    options.scope = scope
    options.includeSelection = false
    for index in 0..<59 {
      let lane = try store.createChronologyLane(
        worldID: world.id, name: "Saved period \(index)", kind: "period")
      options.laneIDs.append(lane.id)
      _ = try store.saveChronologyEvent(
        worldID: world.id, id: nil, title: "Saved event \(index)", date: "Earlier",
        source: commonSource.id, order: index, laneID: lane.id)
    }
    // The first 60 ordinary groups/events are eligible before the newer pin.
    let child = try store.createChronologyLane(
      worldID: world.id, name: "Earlier nested period", kind: "period",
      parentID: try #require(options.laneIDs.first))
    _ = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Earlier nested event", date: "Earlier",
      source: commonSource.id, order: 59, laneID: child.id)

    let pinned = try store.createChronologyLane(
      worldID: world.id, name: "Year 40", kind: "period", start: "Deep winter")
    let pinnedSource = try store.createRecord(
      worldID: world.id, title: "Crossing log", body: "The ships sailed in winter.")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Winter crossing", date: "Third week",
      source: pinnedSource.id, order: 60, laneID: pinned.id)
    let privateLane = try store.createChronologyLane(
      worldID: world.id, name: "SECRET_PERIOD", kind: "period", parentID: pinned.id)
    let privateEvent = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "SECRET_EVENT", date: "SECRET_TIME",
      source: nil, order: 61, laneID: privateLane.id)
    let privateSource = try store.createRecord(worldID: world.id, title: "SECRET_SOURCE")
    _ = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "SECRET_SOURCE_EVENT", date: "SECRET_DATE",
      source: privateSource.id, order: 62, laneID: pinned.id)
    if applyExclusions {
      options.excludedLaneIDs = [privateLane.id]
      options.excludedRecordIDs = [privateSource.id]
    }
    var pins = AssistantRequestPins()
    pins.laneIDs = [pinned.id]

    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    var submitted: AssistantContext?
    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: "What happened in winter?",
      preset: "Develop", contextOptions: options, requestPins: pins,
      onContextPrepared: { submitted = $0 }, onDelta: { _ in })

    let snapshot = try #require(submitted)
    let request = try #require(await transport.lastRequest)
    #expect(request.instructions.contains(snapshot.workspace))
    #expect(request.instructions.contains("The ships sailed in winter."))
    let index = try #require(
      JSONSerialization.jsonObject(with: Data(snapshot.workspace.utf8)) as? [String: Any])
    let history = try #require(index["chronology"] as? [[String: String]])
    let events = try #require(index["events"] as? [[String: String]])
    let placements = try #require(index["eventPlacement"] as? [String: String])
    #expect(history.count == 60 && events.count == 60)
    #expect(history.contains { $0["id"] == pinned.id && $0["start"] == "Deep winter" })
    #expect(events.contains { $0["id"] == event.id && $0["date"] == "Third week" })
    #expect(placements[event.id] == pinned.id)
    if applyExclusions {
      for sentinel in ["SECRET_", privateLane.id, privateEvent.id, privateSource.id] {
        #expect(!request.instructions.contains(sentinel))
      }
    }
  }
}
