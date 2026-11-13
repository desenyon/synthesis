import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct WorkspaceTests {
  @Test func assistanceModePreservesWorkspaceAndEditorGuard() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.destination = .library
    let record = try store.createRecord(worldID: studio.worldID, title: "A page")
    studio.selectedRecord = record
    studio.editorSave = { false }
    studio.setMode(.manual)
    #expect(studio.destination == .library && studio.selectedRecord?.id == record.id)
    #expect(!studio.flushEditor())
    #expect(try store.preference("mode") == "manual")
    studio.setMode(.assisted)
    #expect(studio.destination == .library && !studio.flushEditor())
  }
  @Test func companionConversationSwitchKeepsBoardSaveProtection() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let chat = try store.createConversation(worldID: studio.worldID)
    studio.destination = .canvas
    var succeeds = true
    studio.editorSave = { succeeds }
    studio.openChat(chat, keepWorkspace: true)
    #expect(studio.destination == .canvas && studio.conversationID == chat.id)
    studio.newChat(keepWorkspace: true)
    #expect(studio.destination == .canvas && studio.editorSave != nil)
    succeeds = false
    studio.navigate(.library)
    #expect(studio.destination == .canvas)
    studio.openChat(chat, keepWorkspace: true)
    #expect(studio.conversationID == nil)
  }
  @Test func delayedViewportSaveCannotOverwriteReopenedBoard() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let first = BoardController(studio: studio)
    first.load()
    first.moveViewport(CGSize(width: 12, height: 8))
    #expect(first.save())  // Navigation flush cancels the delayed save.
    let second = BoardController(studio: studio)
    second.load()
    second.mutate { $0.cards.append(CanvasCard(text: "Newer edit")) }
    try await Task.sleep(for: .milliseconds(500))
    let reopened = BoardController(studio: studio)
    reopened.load()
    #expect(reopened.document.cards.first?.text == "Newer edit")
    #expect(reopened.viewport.x == 12 && reopened.viewport.y == 8)
  }
  @Test func boardUndoPreservesSourceRecordAndSavedLayout() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "Cartographer", kind: "entity")
    let board = BoardController(studio: studio)
    board.load()
    board.add(record)
    board.mutate {
      $0.cards[0].x = 211
      $0.cards[0].group = "group-a"
    }
    board.viewport = BoardViewport(x: 3, y: 4, zoom: 0.9)
    #expect(board.save())
    let reopened = BoardController(studio: studio)
    reopened.load()
    #expect(reopened.document.cards[0].x == 211 && reopened.document.cards[0].group == "group-a")
    #expect(reopened.viewport.zoom == 0.9)
    board.removeSelection()
    #expect(board.document.cards.isEmpty)
    board.step(back: true)
    #expect(board.document.cards.first?.recordID == record.id)
    #expect(try store.record(worldID: studio.worldID, id: record.id).body == "Cartographer")
  }
  @Test func pendingDraftSurvivesImmediateWorldSwitch() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let original = studio.worldID
    let other = try store.createWorld(name: "Other")
    studio.pendingComposer = (original, "Last keystrokes")
    studio.switchWorld(other.id)
    #expect(try store.preference("composer:\(original)") == "Last keystrokes")
    #expect(studio.draft.isEmpty)
    studio.switchWorld(original)
    #expect(studio.draft == "Last keystrokes")
  }
  @Test func malformedBoardIsPreservedAndDoesNotTrapNavigation() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    _ = try store.saveBoard(
      worldID: studio.worldID, name: "Damaged", kind: "canvas", content: "not-json")
    let board = BoardController(studio: studio)
    board.load()
    #expect(!board.loaded && board.failure != nil)
    #expect(board.save())  // No pending edits exist; allow leaving without overwriting.
    #expect(try store.boards(worldID: studio.worldID, kind: "canvas").first?.content == "not-json")
  }

}
