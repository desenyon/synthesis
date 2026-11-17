import Foundation
import Testing

@testable import SynthesisCore

struct DashboardDataTests {
  @Test func activityReflectsRealChangesExcludesArchivesAndStaysWorldScoped() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Working world")
    let other = try store.createWorld(name: "Private world")
    _ = try store.createRecord(worldID: other.id, title: "Hidden")
    let mira = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let sea = try store.createRecord(worldID: world.id, title: "Sea", kind: "entity")
    let section = try store.createRecordSection(
      worldID: world.id, parentID: mira.id, title: "Notes")
    let relation = try store.addRelation(
      worldID: world.id, source: mira.id, target: sea.id, label: "crosses")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Crossing", date: "Year 60", source: mira.id,
      order: 60, laneID: nil)
    let board = try store.saveBoard(worldID: world.id, name: "Coast", kind: "canvas", content: "{}")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "A possibility",
          "changes": [["action": "create_record", "title": "New idea"]],
        ]))
    var activity = try store.recentWorldActivity(worldID: world.id)
    #expect(activity.allSatisfy { $0.worldID == world.id && $0.title != "Hidden" })
    #expect(
      Set(activity.map(\.kind)).isSuperset(of: [.record, .relationship, .event, .board, .proposal]))
    #expect(activity.contains { $0.objectID == relation.id && $0.title == "Mira → Sea" })
    #expect(activity.contains { $0.objectID == board.id && $0.boardKind == "canvas" })
    _ = try store.promote(worldID: world.id, id: sea.id, version: sea.version, confirmation: sea.id)
    activity = try store.recentWorldActivity(worldID: world.id)
    #expect(activity.contains { $0.objectID == sea.id && $0.detail == "Canon accepted" })
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
      accept: false, confirmation: proposal.id)
    #expect(
      try store.recentWorldActivity(worldID: world.id).contains {
        $0.objectID == proposal.id && $0.detail == "Proposal dismissed"
      })
    try store.archiveRecord(worldID: world.id, id: mira.id)
    activity = try store.recentWorldActivity(worldID: world.id)
    for id in [mira.id, section.record.id, relation.id, event.id] {
      #expect(!activity.contains { $0.objectID == id })
    }
    #expect(try store.recentWorldActivity(worldID: world.id, limit: 1).count == 1)
    #expect(try store.recentWorldActivity(worldID: world.id, limit: -1).isEmpty)
    #expect(throws: SynthesisError.self) { try store.recentWorldActivity(worldID: "missing") }
  }

  @Test func projectOutlinesArePortableRevisionedEntitiesWithLinkedSections() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let path = url.appendingPathComponent("world.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "World")
    let project = try store.createProject(worldID: world.id, title: "First crossing")
    _ = try store.createRecordSection(
      worldID: world.id, parentID: project.id, title: "Act one", body: "Unfinished scene")
    let restarted = try WorkspaceStore(path: path)
    #expect(try restarted.record(worldID: world.id, id: project.id).isProject)
    #expect(project.state == "draft" && project.canonical == nil)
    let copy = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let copiedRecords = try store.records(worldID: copy.id)
    let imported = try #require(copiedRecords.first { $0.isProject })
    #expect(imported.id != project.id)
    #expect(
      try store.recordSections(worldID: copy.id, parentID: imported.id).first?.record.body
        == "Unfinished scene")
  }
}
