import AppKit
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct RecordDragTests {
  private func fixture() throws -> (Studio, LoreRecord, LoreRecord) {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let first = try store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "Private world text", kind: "entity",
      category: "Characters")
    let second = try store.createRecord(
      worldID: studio.worldID, title: "Glass Sea", kind: "entity", category: "Places")
    try studio.reload()
    return (studio, first, second)
  }
  private func data(_ provider: NSItemProvider) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: RecordDragAddress.type.identifier) {
        value, error in
        if let value {
          continuation.resume(returning: value)
        } else {
          continuation.resume(throwing: error ?? SynthesisError.notFound)
        }
      }
    }
  }
  private func deliver(_ record: LoreRecord, to target: RecordDropTarget, studio: Studio)
    async throws -> Bool
  {
    let provider = studio.beginRecordDrag(record, monitor: false)
    let drag = try #require(studio.recordDrag)
    let location = studio.navigationLocation
    return await studio.receiveRecordDrop(
      try data(provider), target: target, location: location, dragID: drag.id)
  }

  @Test func providerCarriesOnlyBoundedLocalAddresses() async throws {
    let (studio, record, _) = try fixture()
    let provider = studio.beginRecordDrag(record, monitor: false)
    #expect(provider.registeredTypeIdentifiers == [RecordDragAddress.type.identifier])
    let payload = try await data(provider)
    let address = try RecordDragAddress.decode(payload)
    #expect(address.worldID == record.worldID && address.recordID == record.id)
    #expect(!String(decoding: payload, as: UTF8.self).contains("Private world text"))
    for invalid in [Data(), Data("{}".utf8), Data(repeating: 65, count: 2049)] {
      #expect(throws: (any Error).self) { try RecordDragAddress.decode(invalid) }
    }
    var future = address
    future.version = 2
    #expect(throws: (any Error).self) { try RecordDragAddress.decode(JSONEncoder().encode(future)) }
    #expect(throws: (any Error).self) {
      try RecordDragAddress.decode(
        JSONEncoder().encode(RecordDragAddress(worldID: "", recordID: "")))
    }
  }

  @Test func searchAndFavoriteSourcesResolveFreshLoreInEitherPane() async throws {
    let (studio, record, second) = try fixture()
    studio.setMode(.manual)
    studio.setFavorite(record, enabled: true)
    studio.navigate(.atlas)
    studio.palette = true
    let item = try #require(
      CommandPalette.results(studio: studio, query: "Mira", indexed: [record])
        .first(where: { $0.record?.id == record.id }))
    let source = try #require(item.record)
    _ = try studio.store.saveRecord(
      worldID: record.worldID, id: record.id, version: record.version,
      title: "Mira Vale", body: "The current lore", rtf: nil)
    #expect(try await deliver(source, to: .beside, studio: studio))
    #expect(
      studio.splitRecord?.title == "Mira Vale" && studio.splitRecord?.body == "The current lore")
    #expect(studio.destination == .atlas && studio.selectedRecord == nil && !studio.palette)
    #expect(studio.mode == .manual && !studio.busy && studio.splitRecord?.canonical == nil)
    #expect(try await deliver(second, to: .main, studio: studio))
    #expect(studio.selectedRecord?.id == second.id && studio.splitRecord?.id == record.id)
    #expect(try await deliver(record, to: .main, studio: studio))
    #expect(studio.selectedRecord?.id == record.id && studio.splitRecord == nil)
    #expect(studio.openDocuments.filter { $0.id == record.id }.count == 1)
    #expect(studio.isFavorite(record.id))
  }

  @Test func editorFailuresAndCancellationNeverDiscardWork() async throws {
    let (studio, first, second) = try fixture()
    studio.openRecord(first)
    studio.editorSave = { false }
    #expect(try await !deliver(second, to: .beside, studio: studio))
    #expect(studio.selectedRecord?.id == first.id && studio.splitRecord == nil)
    studio.editorSave = nil
    studio.openBeside(second)
    studio.splitEditorSave = { false }
    studio.palette = true
    #expect(try await !deliver(second, to: .main, studio: studio))
    #expect(studio.selectedRecord?.id == first.id && studio.splitRecord?.id == second.id)
    #expect(studio.recordDrag == nil && studio.palette)
    let provider = studio.beginRecordDrag(first, monitor: false)
    let drag = try #require(studio.recordDrag)
    let location = studio.navigationLocation
    studio.endRecordDrag()
    #expect(
      await !studio.receiveRecordDrop(
        try data(provider), target: .main, location: location, dragID: drag.id))
    #expect(studio.palette)
  }

  @Test func lateForeignArchivedOrMalformedDropsAreRejected() async throws {
    let (studio, first, second) = try fixture()
    let other = try studio.store.createWorld(name: "Other")
    let provider = studio.beginRecordDrag(first, monitor: false)
    let drag = try #require(studio.recordDrag)
    let location = studio.navigationLocation
    let payload = try await data(provider)
    studio.switchWorld(other.id)
    #expect(
      await !studio.receiveRecordDrop(payload, target: .main, location: location, dragID: drag.id))
    #expect(studio.selectedRecord == nil && studio.splitRecord == nil)
    #expect(studio.beginRecordDrag(first, monitor: false).registeredTypeIdentifiers.isEmpty)
    studio.switchWorld(first.worldID)
    _ = studio.beginRecordDrag(first, monitor: false)
    let current = try #require(studio.recordDrag)
    let before = studio.navigationLocation
    studio.navigate(.atlas)
    #expect(
      await !studio.receiveRecordDrop(
        payload, target: .beside, location: before, dragID: current.id))
    _ = studio.beginRecordDrag(second, monitor: false)
    let wrong = try #require(studio.recordDrag)
    #expect(
      await !studio.receiveRecordDrop(
        payload, target: .main, location: studio.navigationLocation, dragID: wrong.id))
    _ = studio.beginRecordDrag(first, monitor: false)
    let archived = try #require(studio.recordDrag)
    studio.archive(first)
    #expect(
      await !studio.receiveRecordDrop(
        payload, target: .main, location: studio.navigationLocation, dragID: archived.id))
    #expect(studio.selectedRecord == nil && studio.splitRecord == nil)
    #expect(studio.beginRecordDrag(first, monitor: false).registeredTypeIdentifiers.isEmpty)
    _ = studio.beginRecordDrag(second, monitor: false)
    let malformed = try #require(studio.recordDrag)
    #expect(
      await !studio.receiveRecordDrop(
        Data(), target: .beside, location: studio.navigationLocation, dragID: malformed.id))
  }

  @Test func oldDeliveryCannotCancelANewGestureAndUnloadedCanvasCannotPretendToSave() async throws {
    let (studio, first, second) = try fixture()
    let provider = studio.beginRecordDrag(first, monitor: false)
    let old = try #require(studio.recordDrag)
    let before = studio.navigationLocation
    _ = studio.beginRecordDrag(second, monitor: false)
    let current = try #require(studio.recordDrag)
    #expect(
      await !studio.receiveRecordDrop(
        try data(provider), target: .main, location: before, dragID: old.id))
    #expect(studio.recordDrag?.id == current.id)
    studio.navigate(.canvas)
    #expect(
      try await !deliver(
        second, to: .canvas(boardID: "missing", sessionID: "old", point: .zero), studio: studio))
    #expect(studio.toast?.message == "Open a canvas before placing a record.")
    #expect(studio.selectedRecord == nil && studio.recordDrag == nil)
    #expect(try studio.store.record(worldID: second.worldID, id: second.id) == second)
  }
}
