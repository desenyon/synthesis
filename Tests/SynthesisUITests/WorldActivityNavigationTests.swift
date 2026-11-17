import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct WorldActivityNavigationTests {
  @Test func historyOpensCurrentSourcesPreservesWritingAndNeverApprovesCanon() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let record = try store.createRecord(worldID: studio.worldID, title: "Original", kind: "lore")
    let saved = try store.saveRecord(
      worldID: studio.worldID, id: record.id, version: record.version, title: "Current",
      body: "Revised text", rtf: nil)
    try studio.reload()
    let old = try #require(
      try store.worldChangeHistory(worldID: studio.worldID).first { $0.title == "Original" })
    studio.sheet = .activity
    studio.editorSave = { false }
    studio.openChangeSource(old)
    #expect(studio.sheet == .activity && studio.selectedRecord == nil)
    studio.editorSave = nil
    studio.openChangeSource(old)
    #expect(studio.sheet == nil && studio.selectedRecord == saved)
    #expect(studio.mode == .manual && !studio.busy && studio.selectedRecord?.canonical == nil)
    studio.closeRecord()
    studio.archive(saved)
    let archived = try #require(
      try store.worldChangeHistory(worldID: studio.worldID).first { $0.objectID == record.id })
    studio.sheet = .activity
    studio.openChangeSource(archived)
    #expect(studio.sheet == .activity && studio.selectedRecord == nil)
    let other = try store.createWorld(name: "Other")
    studio.switchWorld(other.id)
    studio.sheet = .activity
    studio.openChangeSource(old)
    #expect(studio.sheet == .activity && studio.selectedRecord == nil)
  }

  @Test func historyConnectsMapsConversationsWorldSettingsAndThePalette() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let map = try store.createAtlasMap(worldID: studio.worldID, name: "Coast")
    let chat = try store.createConversation(worldID: studio.worldID, title: "Brainstorm")
    try studio.reload()
    let history = try store.worldChangeHistory(worldID: studio.worldID)
    let mapChange = try #require(history.first { $0.objectID == map.id })
    studio.openChangeSource(mapChange)
    #expect(studio.destination == .atlas && studio.mapBoardID == map.id)
    studio.openChangeSource(try #require(history.first { $0.objectID == chat.id }))
    #expect(studio.destination == .chat && studio.conversationID == chat.id && !studio.busy)
    studio.openChangeSource(try #require(history.first { $0.kind == .world }))
    #expect(studio.destination == .settings && studio.settingsSection == .world)
    let command = try #require(
      CommandPalette.results(studio: studio, query: "World activity history", indexed: []).first {
        $0.title == "World activity history"
      })
    command.run()
    #expect(studio.sheet == .activity)
  }
}
