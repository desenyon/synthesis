import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct UniversalPaletteTests {
  @Test func paletteFindsAndOpensMapsBoardsScenesSettingsAndTools() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let map = try store.createAtlasMap(worldID: studio.worldID, name: "Eastern archipelago")
    let board = try store.saveBoard(
      worldID: studio.worldID, name: "Voyage planning", kind: "canvas",
      content: CanvasBoardContent.empty)
    let scene = try store.createRecord(
      worldID: studio.worldID, title: "The ferryman's bargain", body: "A quiet negotiation.",
      kind: "lore", category: "Scenes")
    try studio.reload()
    func items(_ query: String) -> [CommandPalette.Item] {
      CommandPalette.results(studio: studio, query: query, indexed: [])
    }
    let mapItem = try #require(items("archipelago").first { $0.id == "board-\(map.id)" })
    let before = studio.destination
    studio.editorSave = { false }
    mapItem.run()
    #expect(studio.destination == before && studio.mapBoardID == nil)
    studio.editorSave = nil
    mapItem.run()
    #expect(studio.destination == .atlas && studio.mapBoardID == map.id)
    try #require(items("Voyage planning").first { $0.id == "board-\(board.id)" }).run()
    #expect(studio.destination == .canvas && studio.canvasBoardID == board.id)
    let sceneItem = try #require(items("scenes").first { $0.id == "record-\(scene.id)" })
    #expect(sceneItem.section == "Scenes")
    sceneItem.run()
    #expect(studio.selectedRecord?.id == scene.id)
    try #require(items("spelling").first { $0.id == "setting-spelling" }).run()
    #expect(studio.destination == .settings && studio.settingsSection == .writing)
    #expect(SettingsItem.matching(studio.settingsQuery, section: .writing) == [.spelling])
    try #require(items("power systems").first { $0.id == "category-Power systems" }).run()
    #expect(studio.destination == .library && studio.libraryCategory == "Power systems")
    #expect(studio.mode == .manual && !studio.busy)
  }

  @Test func paletteActivityOpensFreshObjectsAndExcludesForeignOrArchivedData() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(worldID: studio.worldID, title: "The tide treaty")
    let event = try store.addEvent(
      worldID: studio.worldID, title: "Treaty signed", date: "Year 60", source: record.id)
    let map = try store.createAtlasMap(worldID: studio.worldID, name: "Treaty shores")
    let foreign = try store.createWorld(name: "Other universe")
    let secret = try store.createRecord(worldID: foreign.id, title: "The hidden treaty")
    let foreignActivity = try store.recentWorldActivity(worldID: foreign.id)
    try studio.reload()
    let activity = try store.recentWorldActivity(worldID: studio.worldID)
    let results = CommandPalette.results(
      studio: studio, query: "treaty", indexed: [secret, record],
      activity: activity + foreignActivity)
    #expect(!results.contains { $0.id.contains(secret.id) })
    let eventItem = try #require(results.first { $0.id == "activity-event:\(event.id)" })
    eventItem.run()
    #expect(studio.destination == .timeline && studio.effectiveInspection == .event(event.id))
    let recordItem = try #require(results.first { $0.id == "record-\(record.id)" })
    _ = try store.saveRecord(
      worldID: studio.worldID, id: record.id, version: record.version,
      title: "The revised tide treaty", body: "Revised terms", rtf: nil)
    recordItem.run()
    #expect(studio.selectedRecord?.body == "Revised terms")
    let mapItem = try #require(results.first { $0.id == "board-\(map.id)" })
    try store.setBoardArchived(worldID: studio.worldID, id: map.id, archived: true)
    mapItem.run()
    #expect(studio.error != nil && studio.selectedRecord?.id == record.id)
    studio.switchWorld(foreign.id)
    eventItem.run()
    recordItem.run()
    #expect(studio.worldID == foreign.id && studio.selectedRecord == nil)
  }

  @Test func keyboardSelectionStaysBoundedAndCommandsRemainAheadOfCapture() throws {
    #expect(PaletteSelection.moved(0, by: -1, count: 0) == 0)
    #expect(PaletteSelection.moved(0, by: 1, count: 3) == 1)
    #expect(PaletteSelection.moved(2, by: 1, count: 3) == 2)
    #expect(PaletteSelection.moved(20, by: -1, count: 2) == 1)
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let items = CommandPalette.results(studio: studio, query: "  light appearance  ", indexed: [])
    #expect(items.first?.title == "Use light appearance")
    #expect(Set(items.map(\.id)).count == items.count)
    #expect(
      CommandPalette.results(studio: studio, query: "knowledge graph", indexed: []).first?.title
        == "Graph")
  }
}
