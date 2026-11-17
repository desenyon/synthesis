import Foundation
import Testing

@testable import SynthesisCore

struct AtlasMapTests {
  @Test func importingForeignMapMetadataRollsBackAndInvalidMarkersAreRejected() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Coast")
    let other = try store.createWorld(name: "Other")
    let foreign = try store.createRecord(worldID: other.id, title: "Private place", kind: "entity")
    let place = try store.createRecord(worldID: world.id, title: "Harbour", kind: "entity")
    _ = try store.saveBoard(
      worldID: world.id, name: "Imported map", kind: "atlas",
      content: "{\"markers\":[],\"placeID\":\"\(foreign.id)\"}")
    let before = try store.worlds().count
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    }
    #expect(try store.worlds().count == before)
    for x in ["true", "1.5", "-0.1"] {
      #expect(throws: (any Error).self) {
        try store.saveAtlasMap(
          worldID: world.id, name: "Invalid coordinate",
          content:
            "{\"markers\":[{\"id\":\"pin\",\"recordID\":\"\(place.id)\",\"x\":\(x),\"y\":0.5}]}")
      }
    }
  }

  @Test func hierarchyAndPlaceLinksRemainWorldScopedAndPortable() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Coast")
    let other = try store.createWorld(name: "Elsewhere")
    let place = try store.createRecord(worldID: world.id, title: "Harbour", kind: "entity")
    let root = try store.createAtlasMap(worldID: world.id, name: "Coast")
    let child = try store.createAtlasMap(
      worldID: world.id, name: "Harbour", placeID: place.id, parentMapID: root.id)
    #expect(try store.mapsForRecord(worldID: world.id, recordID: place.id).map(\.id) == [child.id])
    #expect(throws: (any Error).self) {
      try store.createAtlasMap(worldID: other.id, name: "Foreign", parentMapID: root.id)
    }
    #expect(throws: (any Error).self) {
      try store.createAtlasMap(worldID: other.id, name: "Foreign", placeID: place.id)
    }
    #expect(throws: (any Error).self) {
      try store.saveAtlasMap(
        worldID: world.id, id: root.id, name: root.name,
        content: "{\"markers\":[],\"parentMapID\":\"\(child.id)\"}", expected: root)
    }
    #expect(throws: (any Error).self) { try store.archiveAtlasMap(worldID: world.id, id: root.id) }
    let copied = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let maps = try store.boards(worldID: copied.id, kind: "atlas")
    let copiedChild = try #require(maps.first { $0.name == "Harbour" })
    let links = try AtlasLinks(content: copiedChild.content)
    #expect(links.parentMapID == maps.first { $0.name == "Coast" }?.id)
    #expect(links.placeID != place.id)
    #expect(try store.record(worldID: copied.id, id: #require(links.placeID)).title == "Harbour")
    try store.archiveAtlasMap(worldID: world.id, id: child.id)
    try store.setBoardArchived(worldID: world.id, id: child.id, archived: false)
    #expect(try store.mapsForRecord(worldID: world.id, recordID: place.id).count == 1)
  }
  @Test func markerChangesRejectStaleUndoAndPreserveOtherMaps() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Coast")
    let place = try store.createRecord(worldID: world.id, title: "Harbour", kind: "entity")
    let first = try store.saveAtlasMap(
      worldID: world.id, name: "Northern coast", content: #"{"image":"sample","markers":[]}"#)
    let second = try store.createAtlasMap(worldID: world.id, name: "Southern coast")
    let marked = try store.placeMapMarker(
      worldID: world.id, boardID: first.id, recordID: place.id, x: 0.2, y: 0.3)
    let moved = try store.placeMapMarker(
      worldID: world.id, boardID: first.id, recordID: place.id, x: 0.5, y: 0.7)
    #expect(throws: (any Error).self) {
      try store.saveAtlasMap(
        worldID: world.id, id: first.id, name: first.name, content: first.content, expected: marked)
    }
    #expect(
      try store.board(worldID: world.id, id: first.id, kind: "atlas").content == moved.content)
    #expect(
      try store.board(worldID: world.id, id: second.id, kind: "atlas").content == second.content)
    #expect(moved.name == "Northern coast")
    _ = try store.saveAtlasMap(
      worldID: world.id, id: first.id, name: first.name, content: first.content, expected: moved)
    #expect(try store.mapsForRecord(worldID: world.id, recordID: place.id).isEmpty)
  }
  @Test func agentMapCreationRequiresReviewAndDoesNotInventArtwork() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Coast")
    let place = try store.createRecord(worldID: world.id, title: "Harbour", kind: "entity")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [["action": "create_map", "title": "Local harbour", "source": place.id]]
        ]))
    #expect(try store.boards(worldID: world.id, kind: "atlas").isEmpty)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
        accept: true, confirmation: "")
    }
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
      accept: true, confirmation: proposal.id)
    let map = try #require(try store.boards(worldID: world.id, kind: "atlas").first)
    #expect(try AtlasLinks(content: map.content).placeID == place.id)
    #expect(!map.content.contains("image"))
    #expect(
      try store.workspaceContext(worldID: world.id, boardID: map.id).contains("Local harbour"))
    #expect(throws: (any Error).self) {
      try store.placeMapMarker(
        worldID: world.id, boardID: map.id, recordID: place.id, x: 0.5, y: 0.5)
    }
  }
}
