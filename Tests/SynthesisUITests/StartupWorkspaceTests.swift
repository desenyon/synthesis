import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct StartupWorkspaceTests {
  @Test func everyHomeChoiceSurvivesDiskRestartWithoutChangingLoreOrMode() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("startup.sqlite").path
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: path), transport: transport)
    let world = studio.worldID
    let record = try studio.store.createRecord(worldID: world, title: "Keep this world")
    for mode in [WorkspaceMode.assisted, .manual] {
      studio.setMode(mode)
      for choice in StartupWorkspace.allCases {
        studio.navigate(.timeline)
        studio.updatePreferences { $0.launchWorkspace = choice.rawValue }
        #expect(studio.destination == .timeline)
        let reopened = try Studio(store: WorkspaceStore(path: path), transport: transport)
        let requested = Destination(rawValue: choice.rawValue) ?? .timeline
        let expected: Destination = mode == .manual && requested == .chat ? .library : requested
        #expect(reopened.destination == expected && reopened.mode == mode)
        #expect(reopened.preferences.launchWorkspace == choice.rawValue)
        #expect(reopened.worldID == world && reopened.records == [record])
        #expect(!reopened.busy && reopened.sheet == nil)
      }
    }
    #expect(await transport.requests.isEmpty)
  }

  @Test func lastWorkspaceFollowsDirectChatRoutesAndRespectsFailedSaves() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let chat = try studio.store.createConversation(worldID: studio.worldID)
    func remembered(_ destination: Destination) throws {
      #expect(try Studio(store: studio.store).destination == destination)
    }
    studio.navigate(.atlas)
    studio.newChat(keepWorkspace: true)
    try remembered(.atlas)
    studio.newChat()
    try remembered(.chat)
    studio.navigate(.knowledge)
    studio.openChat(chat)
    try remembered(.chat)
    studio.goBack()
    try remembered(.knowledge)
    studio.goForward()
    try remembered(.chat)
    studio.navigate(.canvas)
    studio.openChat(chat, keepWorkspace: true)
    try remembered(.canvas)
    studio.editorSave = { false }
    studio.newChat()
    studio.openChat(chat)
    studio.navigate(.atlas)
    try remembered(.canvas)
  }

  @Test func startupUsesSelectedWorldAndLocalChoiceNeverEntersPortableWorld() async throws {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    let first = studio.worldID
    let record = try studio.store.createRecord(worldID: first, title: "First-world source")
    let second = try studio.store.createWorld(name: "Second world")
    studio.updatePreferences { $0.launchWorkspace = StartupWorkspace.atlas.rawValue }
    studio.switchWorld(second.id)
    let reopened = try Studio(store: studio.store, transport: transport)
    #expect(reopened.worldID == second.id && reopened.destination == .atlas)
    #expect(reopened.records.isEmpty && reopened.contextBoards.isEmpty)
    #expect(try studio.store.record(worldID: first, id: record.id) == record)
    let archive = String(
      decoding: try studio.store.exportWorldArchive(worldID: first), as: UTF8.self)
    #expect(!archive.contains("launchWorkspace") && !archive.contains("studio-preferences"))
    #expect(await transport.requests.isEmpty)
  }

  @Test func invalidOrAbsentPreferenceFallsBackWithoutLosingOtherPreferences() throws {
    let store = try WorkspaceStore(path: ":memory:")
    #expect(try Studio(store: store).destination == .chat)
    try store.setPreference("mode", value: "manual")
    #expect(try Studio(store: store).destination == .canvas)
    try store.setPreference("destination", value: "future-workspace")
    try store.setPreference(
      "studio-preferences", value: #"{"launchWorkspace":"future-home","bodySize":20}"#)
    let fallback = try Studio(store: store)
    #expect(fallback.destination == .canvas && fallback.preferences.bodySize == 20)
    #expect(fallback.preferences.launchWorkspace == "remember")
    try store.setPreference("destination", value: "Atlas")
    #expect(try Studio(store: store).destination == .atlas)
  }
}
