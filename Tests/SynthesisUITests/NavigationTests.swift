import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct NavigationTests {
  @Test func connectedRecordTrailIsReversibleAndFailedSavesNeverConsumeHistory() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let mira = try store.createRecord(worldID: studio.worldID, title: "Mira Vale", kind: "entity")
    let order = try store.createRecord(
      worldID: studio.worldID, title: "Tidekeepers", kind: "entity")
    let sea = try store.createRecord(worldID: studio.worldID, title: "Glass Sea", kind: "entity")
    try studio.reload()
    studio.openLens("Characters")
    studio.openRecord(mira)
    studio.openRecord(order)
    studio.openRecord(sea)
    #expect(studio.navigationBack.suffix(2).map(\.title) == ["Mira Vale", "Tidekeepers"])
    let visits = studio.navigationBack
    studio.editorSave = { false }
    studio.goBack()
    studio.openRecord(mira)
    #expect(studio.selectedRecord?.id == sea.id && studio.navigationBack == visits)
    studio.editorSave = nil
    studio.goBack()
    #expect(studio.selectedRecord?.id == order.id)
    studio.goBack()
    #expect(studio.selectedRecord?.id == mira.id)
    studio.goForward()
    #expect(studio.selectedRecord?.id == order.id)
    studio.goForward()
    #expect(studio.selectedRecord?.id == sea.id && !studio.canNavigateForward)
    studio.goBack()
    studio.navigate(.atlas)
    #expect(!studio.canNavigateForward)
    studio.goBack()
    #expect(studio.selectedRecord?.id == order.id && studio.libraryCategory == "Characters")
    #expect(studio.draft.isEmpty)
  }

  @Test func historyResolvesFreshLoreSkipsArchivedRecordsAndRejectsForeignSources() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let a = try store.createRecord(worldID: studio.worldID, title: "A")
    let b = try store.createRecord(worldID: studio.worldID, title: "B")
    let c = try store.createRecord(worldID: studio.worldID, title: "C")
    try studio.reload()
    studio.navigate(.library)
    studio.openRecord(a)
    studio.openRecord(b)
    studio.openRecord(c)
    _ = try store.saveRecord(
      worldID: studio.worldID, id: a.id, version: a.version, title: "Revised A",
      body: "Current text", rtf: nil)
    try store.archiveRecord(worldID: studio.worldID, id: b.id)
    studio.goBack()
    #expect(studio.selectedRecord?.id == a.id)
    #expect(studio.selectedRecord?.body == "Current text")
    studio.goForward()
    #expect(studio.selectedRecord?.id == c.id)
    studio.openRecord(a)  // citation still carries the old snapshot
    #expect(studio.selectedRecord?.title == "Revised A")
    let other = try store.createWorld(name: "Elsewhere")
    let foreign = try store.createRecord(worldID: other.id, title: "Private record")
    let before = studio.navigationBack
    studio.openRecord(foreign)
    studio.openRecord(b)
    #expect(studio.selectedRecord?.id == a.id && studio.navigationBack == before)
    studio.switchWorld(other.id)
    studio.openRecord(foreign)
    studio.goBack()
    studio.goBack()
    #expect(studio.worldID == a.worldID && studio.selectedRecord?.id == a.id)
    #expect(!studio.records.contains { $0.id == foreign.id })
  }

  @Test func boardsChatsAndSelectionShareHistoryWithoutEnablingAI() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let a = try store.createAtlasMap(worldID: studio.worldID, name: "Coast")
    let b = try store.createAtlasMap(worldID: studio.worldID, name: "Interior")
    let board = try store.saveBoard(
      worldID: studio.worldID, name: "Research", kind: "canvas", content: CanvasBoardContent.empty)
    let record = try store.createRecord(worldID: studio.worldID, title: "Mira", kind: "entity")
    let chat = try store.createConversation(worldID: studio.worldID, title: "A discussion")
    try studio.reload()
    studio.openBoard(a.id, kind: "atlas")
    studio.openBoard(b.id, kind: "atlas")
    studio.goBack()
    #expect(studio.destination == .atlas && studio.mapBoardID == a.id)
    studio.goForward()
    studio.openBoard(board.id, kind: "canvas")
    studio.goBack()
    #expect(studio.mapBoardID == b.id && studio.destination == .atlas)
    let count = studio.navigationBack.count
    studio.showRelationships(for: record)
    #expect(studio.navigationBack.count == count + 1)
    studio.openRecord(record)
    studio.goBack()
    #expect(studio.destination == .knowledge && studio.graphSelectedID == record.id)
    studio.openChat(chat)
    studio.newChat()
    studio.goBack()
    #expect(studio.conversationID == chat.id)
    #expect(studio.mode == .manual && !studio.busy)
    let other = try store.createWorld(name: "Other")
    let foreign = try store.createAtlasMap(worldID: other.id, name: "Private map")
    let current = studio.navigationLocation
    studio.openBoard(foreign.id, kind: "atlas")
    #expect(studio.navigationLocation == current)
  }

  @Test func repeatedVisitsAreDeduplicatedAndHistoryIsBounded() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.navigate(.library)
    let count = studio.navigationBack.count
    studio.navigate(.library)
    #expect(studio.navigationBack.count == count)
    for _ in 0..<70 {
      studio.navigate(.timeline)
      studio.navigate(.knowledge)
    }
    #expect(studio.navigationBack.count == 100)
    let address = studio.navigationLocation
    #expect(
      try JSONDecoder().decode(NavigationLocation.self, from: JSONEncoder().encode(address))
        == address)
  }
}
