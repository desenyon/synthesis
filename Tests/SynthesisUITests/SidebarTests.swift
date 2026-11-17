import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct SidebarTests {
  @Test func utilityPreferencesSurviveRestartWithoutChangingWorldContent() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let worldID = studio.worldID
    let record = try store.createRecord(
      worldID: worldID, title: "An unchanged idea", body: "Keep me.")
    let chat = try store.createConversation(worldID: worldID, title: "A saved conversation")
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "user", body: "Hello", state: "complete")
    let expectedDark = !studio.dark
    studio.toggleTheme()
    studio.toggleSidebar()
    let reopened = try Studio(store: store)
    #expect(reopened.dark == expectedDark)
    #expect(reopened.collapsed)
    #expect(reopened.worldID == worldID)
    #expect(try store.record(worldID: worldID, id: record.id).body == "Keep me.")
    #expect(try store.messages(worldID: worldID, conversationID: chat.id).count == 1)
    reopened.toggleSidebar()
    #expect(try store.preference("sidebar") == "expanded")
  }

  @Test func sidebarDestinationsKeepTheUnsavedEditorGuard() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(worldID: studio.worldID, title: "Still editing")
    let chat = try store.createConversation(worldID: studio.worldID)
    studio.destination = .library
    studio.selectedRecord = record
    studio.editorSave = { false }
    for destination in Destination.allCases {
      studio.navigate(destination)
      #expect(studio.destination == .library && studio.selectedRecord?.id == record.id)
    }
    studio.openLens("Characters")
    studio.newChat()
    studio.openChat(chat)
    #expect(studio.selectedRecord?.id == record.id && studio.conversationID == nil)
    studio.editorSave = { true }
    studio.openChat(chat)
    #expect(studio.selectedRecord == nil && studio.conversationID == chat.id)
  }
}
