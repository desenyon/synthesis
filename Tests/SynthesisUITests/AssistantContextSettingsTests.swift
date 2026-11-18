import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct AssistantContextSettingsTests {
  @Test func contextControlsChangeTheActualPreviewAndKeepWorldExclusions() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    let selectedWorld = studio.worldID
    let other = try store.createWorld(name: "Other")
    let accepted = try store.createRecord(
      worldID: selectedWorld, title: "Public channel", body: "The harbour opens at dawn.")
    _ = try store.promote(
      worldID: selectedWorld, id: accepted.id, version: accepted.version,
      confirmation: accepted.id)
    let privateNote = try store.createRecord(
      worldID: selectedWorld, title: "Hidden crossing", body: "Keep the passage secret.")
    let period = try store.createChronologyLane(
      worldID: selectedWorld, name: "Lost years", kind: "period")
    try studio.reload()
    studio.updateContext {
      $0.recordIDs = [accepted.id, privateNote.id]
      $0.excludedRecordIDs = [privateNote.id]
      $0.excludedLaneIDs = [period.id]
    }
    studio.openSettings(.world, query: "Assistant context")
    #expect(studio.destination == .settings && studio.settingsSection == .world)
    studio.setMode(.manual)
    let scope = studio.assistantContextBinding(\.scope)
    scope.wrappedValue = .attachments
    studio.assistantContextBinding(\.canonOnly).wrappedValue = true
    studio.assistantContextBinding(\.budget).wrappedValue = .focused
    studio.assistantContextBinding(\.includeSelection).wrappedValue = false

    let saved = try store.assistantContextOptions(worldID: selectedWorld)
    #expect(saved.scope == .attachments && saved.canonOnly && saved.budget == .focused)
    #expect(!saved.includeSelection)
    #expect(saved.recordIDs == [accepted.id, privateNote.id])
    #expect(saved.excludedRecordIDs == [privateNote.id] && saved.excludedLaneIDs == [period.id])
    #expect(saved.includeHistory)
    #expect(!studio.assistantContextHistoryBinding.wrappedValue)
    let preview = try studio.previewContext(prompt: "When does the harbour open?")
    #expect(preview.sources.map(\.id) == [accepted.id])
    #expect(preview.lore.contains("The harbour opens at dawn."))
    #expect(!preview.lore.contains("Keep the passage secret.") && !preview.includesHistory)

    studio.switchWorld(other.id)
    scope.wrappedValue = .attachments
    #expect(studio.contextOptions == AssistantContextOptions())
    #expect(try store.assistantContextOptions(worldID: other.id) == AssistantContextOptions())
    studio.switchWorld(selectedWorld)
    #expect(studio.contextOptions == saved && studio.mode == .manual)
    #expect(await transport.requests.isEmpty)
  }

  @Test func contextSettingsAreSearchableAsAWorldPolicy() {
    let expected: Set<SettingsItem> = [
      .assistantScope, .assistantBudget, .assistantAcceptedOnly, .assistantSelection,
      .assistantHistory,
    ]
    let matches = SettingsItem.matching("assistant context", section: .assistant)
    #expect(Set(matches) == expected)
    #expect(matches.allSatisfy { $0.section == .world })
  }
}
