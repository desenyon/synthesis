import SynthesisCore
import Testing

struct CanvasReferenceCatalogTests {
  @Test func findsLiteralQueriesAcrossPagesWithoutReturningForeignOrArchivedEvents() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Own world")
    let other = try store.createWorld(name: "Other world")
    let source = try store.createRecord(worldID: world.id, title: "Crossing log")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign log")
    for index in 0...40 {
      _ = try store.addEvent(
        worldID: world.id, title: "Crossing \(index)", date: "Year 8",
        source: source.id, order: index)
    }
    let latest = try store.addEvent(
      worldID: world.id, title: "Crossing_100%", date: "Year 9", source: source.id, order: 41)
    let hidden = try store.addEvent(
      worldID: world.id, title: "Crossing_100%", date: "Year 9", source: source.id, order: 42)
    try store.setEventArchived(worldID: world.id, id: hidden.id, archived: true)
    _ = try store.addEvent(
      worldID: other.id, title: "Crossing_100%", date: "Year 9", source: foreign.id, order: 0)

    let first = try store.canvasReferenceChoices(worldID: world.id, kind: .event, query: "")
    let second = try store.canvasReferenceChoices(
      worldID: world.id, kind: .event, query: "", page: 1)
    #expect(first.choices.count == 40 && first.hasNextPage)
    #expect(second.choices.count == 2 && !second.hasNextPage)
    #expect(second.choices.last?.reference.id == latest.id)

    let filtered = try store.canvasReferenceChoices(
      worldID: world.id, kind: .event, query: "crossing_100%")
    #expect(filtered.choices.map(\.reference.id) == [latest.id])
    try store.archiveRecord(worldID: world.id, id: source.id)
    #expect(
      try store.canvasReferenceChoices(worldID: world.id, kind: .event, query: "").choices.isEmpty)
    #expect(throws: SynthesisError.self) {
      _ = try store.resolveReference(
        WorldReference(worldID: world.id, kind: .event, id: latest.id), worldID: world.id)
    }
  }

  @Test func returnsActualAtlasImagesAndProposalAddressesWithoutChangingCanon() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "World")
    let atlas = try store.saveBoard(
      worldID: world.id, name: "Crossing map", kind: "atlas", content: #"{"image":"AA=="}"#)
    let other = try store.saveBoard(
      worldID: world.id, name: "Old map", kind: "atlas", content: #"{"image":"AA=="}"#)
    try store.setBoardArchived(worldID: world.id, id: other.id, archived: true)
    _ = try store.saveBoard(worldID: world.id, name: "No image", kind: "atlas", content: "{}")
    _ = try store.saveBoard(worldID: world.id, name: "Malformed", kind: "atlas", content: "{")
    _ = try store.saveBoard(
      worldID: world.id, name: "Canvas", kind: "canvas", content: #"{"image":"AA=="}"#)
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "A new coastal faction",
          "changes": [["action": "create_record", "title": "The Shoreward Watch"]],
        ]))
    let images = try store.canvasReferenceChoices(worldID: world.id, kind: .atlasImage, query: "")
    let proposals = try store.canvasReferenceChoices(
      worldID: world.id, kind: .proposal, query: "Coastal")
    #expect(images.choices.map(\.reference.id) == [atlas.id])
    #expect(proposals.choices.map(\.reference.id) == [proposal.id])
    let address = try #require(proposals.choices.first?.reference)
    #expect(try store.resolveReference(address, worldID: world.id).title == proposal.summary)
    #expect(try store.proposal(worldID: world.id, id: proposal.id) == proposal)
    #expect(try store.records(worldID: world.id).isEmpty)
  }
}
