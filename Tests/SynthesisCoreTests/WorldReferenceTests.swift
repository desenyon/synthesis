import Foundation
import Testing

@testable import SynthesisCore

struct WorldReferenceTests {
  static func fixture() throws -> (WorkspaceStore, String, [WorldReference]) {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Reference world")
    let record = try store.createRecord(
      worldID: world.id, title: "Mira [the navigator]", body: "Only this world knows her route.",
      kind: "entity", category: "Characters")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "The first crossing", date: "Year 60",
      source: record.id, order: nil, laneID: nil)
    let artwork = try store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: RecordArtworkTests.png, expectedID: nil)
    let atlas = try store.saveBoard(
      worldID: world.id, name: "Glass Sea", kind: "atlas",
      content:
        "{\"image\":\"\(RecordArtworkTests.png.base64EncodedString())\",\"markers\":[],\"regions\":[]}"
    )
    let canvas = try store.saveBoard(
      worldID: world.id, name: "References", kind: "canvas",
      content:
        """
        {"format":"excalidraw","scene":{"elements":[{"id":"illustration-1","type":"image","fileId":"file-1","isDeleted":false}],"files":{"file-1":{"dataURL":"data:image/png;base64,\(RecordArtworkTests.png.base64EncodedString())"}}}}
        """)
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "A possible harbor",
          "changes": [["action": "create_record", "title": "Harbor", "body": "A suggestion"]],
        ]))
    return (
      store, world.id,
      [
        .init(worldID: world.id, kind: .record, id: record.id),
        .init(worldID: world.id, kind: .event, id: event.id),
        .init(worldID: world.id, kind: .artwork, id: artwork.id),
        .init(worldID: world.id, kind: .board, id: canvas.id),
        .init(worldID: world.id, kind: .atlasImage, id: atlas.id),
        .init(worldID: world.id, kind: .canvasImage, id: "illustration-1", containerID: canvas.id),
        .init(worldID: world.id, kind: .proposal, id: proposal.id),
      ]
    )
  }

  @Test func everyReferenceResolvesActualSourcesAndNeverChangesLore() throws {
    let (store, world, references) = try Self.fixture()
    let before = try store.records(worldID: world)
    let proposals = try store.proposals(worldID: world)
    for reference in references {
      let source = try store.resolveReference(reference, worldID: world)
      #expect(!source.title.isEmpty && source.reference == reference)
      #expect(try WorldReference(url: reference.url) == reference)
      #expect(try WorldReference.decode(JSONEncoder().encode(reference)) == reference)
      #expect(WorkspaceStore.worldReferences(in: source.markdown) == [reference])
    }
    let proposed = try store.resolveReference(references.last!, worldID: world)
    #expect(proposed.state == "proposal" && proposed.excerpt.contains("not established lore"))
    #expect(try store.records(worldID: world) == before)
    #expect(try store.proposals(worldID: world) == proposals)
    #expect(before.allSatisfy { $0.canonical == nil })
  }

  @Test func foreignArchivedAndMissingSourcesFailClosed() throws {
    let (store, world, references) = try Self.fixture()
    let other = try store.createWorld(name: "Foreign")
    for reference in references {
      #expect(throws: (any Error).self) { try store.resolveReference(reference, worldID: other.id) }
      let forged = WorldReference(
        worldID: other.id, kind: reference.kind, id: reference.id,
        containerID: reference.containerID)
      #expect(throws: (any Error).self) { try store.resolveReference(forged, worldID: other.id) }
    }
    try store.archiveRecord(worldID: world, id: references[0].id)
    for reference in references.prefix(3) {
      #expect(throws: (any Error).self) { try store.resolveReference(reference, worldID: world) }
    }
    try store.setBoardArchived(worldID: world, id: references[3].id, archived: true)
    #expect(throws: (any Error).self) { try store.resolveReference(references[3], worldID: world) }
    #expect(throws: (any Error).self) { try store.resolveReference(references[5], worldID: world) }
    try store.setBoardArchived(worldID: world, id: references[4].id, archived: true)
    #expect(throws: (any Error).self) { try store.resolveReference(references[4], worldID: world) }
  }

  @Test func savedReferencesSurviveArchiveRemappingAndResolveNewTitles() throws {
    let (store, world, references) = try Self.fixture()
    let body = try references.map { try store.resolveReference($0, worldID: world).markdown }
      .joined(separator: "\n")
    _ = try store.createRecord(worldID: world, title: "Reference collection", body: body)
    let original = try store.record(worldID: world, id: references[0].id)
    _ = try store.saveRecord(
      worldID: world, id: original.id, version: original.version,
      title: "Mira Vale", body: original.body, rtf: nil)
    #expect(try store.resolveReference(references[0], worldID: world).title == "Mira Vale")
    let copy = try store.importWorldArchive(store.exportWorldArchive(worldID: world))
    let collection = try #require(
      try store.records(worldID: copy.id).first { $0.title == "Reference collection" })
    let copied = WorkspaceStore.worldReferences(in: collection.body)
    #expect(copied.count == references.count)
    for reference in copied {
      #expect(reference.worldID == copy.id)
      #expect(try store.resolveReference(reference, worldID: copy.id).reference == reference)
    }
  }

  @Test func malformedAddressesNeverBecomeURLsOrUnboundedPayloads() throws {
    for data in [Data(), Data("{}".utf8), Data(repeating: 65, count: 4097)] {
      #expect(throws: (any Error).self) { try WorldReference.decode(data) }
    }
    for text in [
      "https://example.com/reference/record/a?world=b",
      "synthesis://reference/record/a?world=b&world=c",
      "synthesis://reference/record/a?world=b&container=c",
      "synthesis://reference/canvasImage/a?world=b",
      "synthesis://reference/record/a?world=b&execute=1",
      "synthesis://reference/record/a?world=b#script",
    ] {
      #expect(throws: (any Error).self) { try WorldReference(url: URL(string: text)!) }
    }
    var future = WorldReference(worldID: "world", kind: .record, id: "record")
    future.version = 9
    #expect(throws: (any Error).self) { try WorldReference.decode(JSONEncoder().encode(future)) }
  }
}
