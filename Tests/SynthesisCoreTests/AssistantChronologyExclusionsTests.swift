import Testing

@testable import SynthesisCore

struct AssistantChronologyExclusionsTests {
  @Test func archivedParentStillExcludesDescendantsAndTheirSources() throws {
    let (store, world, hidden, publicLane) = try Self.fixture()
    let intermediate = try store.createChronologyLane(
      worldID: world.id, name: "Archive this parent", kind: "branch", parentID: hidden.id)
    let child = try store.createChronologyLane(
      worldID: world.id, name: "Hidden child", kind: "period", parentID: intermediate.id)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Hidden event", date: "Unknown", source: nil,
      order: nil, laneID: child.id)
    let publicEvent = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Public occurrence", date: "After the crossing",
      source: event.sourceID, order: nil, laneID: publicLane.id)
    try store.setChronologyLaneArchived(worldID: world.id, id: intermediate.id, archived: true)
    try store.setChronologyLaneArchived(worldID: world.id, id: hidden.id, archived: true)
    try store.setEventArchived(worldID: world.id, id: event.id, archived: true)
    try store.archiveRecord(worldID: world.id, id: event.sourceID)

    let exclusions = try store.assistantChronologyExclusions(
      worldID: world.id, laneIDs: [hidden.id])
    #expect(exclusions.laneIDs == Set([hidden.id, intermediate.id, child.id]))
    #expect(exclusions.eventIDs == Set([event.id]))
    #expect(exclusions.recordIDs == Set([event.sourceID]))
    let hiddenAddress = WorldReference(worldID: world.id, kind: .event, id: event.id)
    let publicAddress = WorldReference(worldID: world.id, kind: .event, id: publicEvent.id)
    #expect(
      try store.isChronologyReferenceExcluded(
        hiddenAddress, worldID: world.id, exclusions: exclusions))
    #expect(
      try !store.isChronologyReferenceExcluded(
        publicAddress, worldID: world.id, exclusions: exclusions))

    let other = try store.createWorld(name: "Other world")
    #expect(throws: SynthesisError.self) {
      try store.assistantChronologyExclusions(worldID: other.id, laneIDs: [hidden.id])
    }
    #expect(throws: SynthesisError.self) {
      try store.isChronologyReferenceExcluded(hiddenAddress, worldID: other.id, exclusions: .init())
    }
  }

  @Test func proposalUsesHistoricalLaneAfterEventLeavesIt() throws {
    let (store, world, hidden, publicLane) = try Self.fixture()
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Original event", date: "Year 8", source: nil,
      order: nil, laneID: hidden.id)
    let proposal = try stage(
      store, worldID: world.id,
      change: ["action": "revise_event", "id": event.id, "lane": publicLane.id])
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
      confirmation: proposal.id)
    let exclusions = try store.assistantChronologyExclusions(
      worldID: world.id, laneIDs: [hidden.id])
    #expect(exclusions.eventIDs.isEmpty)
    #expect(proposal.changes[0].workspaceBefore?["lane"] == hidden.id)
    let address = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
    #expect(
      try store.isChronologyReferenceExcluded(address, worldID: world.id, exclusions: exclusions))
  }

  @Test func proposalsFollowCurrentEventPlacementAndAcceptedLaneResults() throws {
    let (store, world, hidden, publicLane) = try Self.fixture()
    let eventProposal = try stage(
      store, worldID: world.id, change: ["action": "add_event", "title": "New event"])
    let acceptedEvent = try store.resolveChange(
      worldID: world.id, proposalID: eventProposal.id, changeID: eventProposal.changes[0].id,
      accept: true, confirmation: eventProposal.id)
    let eventID = try #require(acceptedEvent.changes[0].resultID)
    let event = try #require(try store.events(worldID: world.id).first { $0.id == eventID })
    _ = try store.saveChronologyEvent(
      worldID: world.id, id: event.id, title: event.title, date: event.dateLabel,
      source: event.sourceID, order: event.order, laneID: hidden.id)

    let laneProposal = try stage(
      store, worldID: world.id, change: ["action": "create_period", "title": "New period"])
    let acceptedLane = try store.resolveChange(
      worldID: world.id, proposalID: laneProposal.id, changeID: laneProposal.changes[0].id,
      accept: true, confirmation: laneProposal.id)
    let periodID = try #require(acceptedLane.changes[0].resultID)
    let pendingProposal = try stage(
      store, worldID: world.id,
      change: ["action": "create_period", "title": "Hidden period", "lane": hidden.id])
    let publicProposal = try stage(
      store, worldID: world.id,
      change: ["action": "create_period", "title": "Public period", "lane": publicLane.id])

    let exclusions = try store.assistantChronologyExclusions(
      worldID: world.id, laneIDs: [hidden.id, periodID])
    for proposal in [eventProposal, laneProposal, pendingProposal] {
      let address = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
      #expect(
        try store.isChronologyReferenceExcluded(address, worldID: world.id, exclusions: exclusions))
    }
    let publicAddress = WorldReference(worldID: world.id, kind: .proposal, id: publicProposal.id)
    #expect(
      try !store.isChronologyReferenceExcluded(
        publicAddress, worldID: world.id, exclusions: exclusions))
  }

  private static func fixture() throws -> (WorkspaceStore, World, ChronologyLane, ChronologyLane) {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Chronology exclusions")
    let hidden = try store.createChronologyLane(worldID: world.id, name: "Hidden", kind: "branch")
    let publicLane = try store.createChronologyLane(
      worldID: world.id, name: "Public", kind: "branch")
    return (store, world, hidden, publicLane)
  }

  private func stage(_ store: WorkspaceStore, worldID: String, change: [String: Any]) throws
    -> Proposal
  {
    try #require(
      try store.stageProposal(
        worldID: worldID, conversationID: nil, messageID: nil,
        payload: ["changes": [change]]))
  }
}
