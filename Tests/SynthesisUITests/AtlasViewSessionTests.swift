import AppKit
import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct AtlasViewSessionTests {
  private func fixture(_ path: String = ":memory:") throws -> (
    Studio, LoreRecord, Board, AtlasDocument
  ) {
    let studio = try Studio(store: WorkspaceStore(path: path))
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "Glass Sea", kind: "entity", category: "Places")
    let map = AtlasDocument(
      markers: [MapMarker(recordID: record.id, x: 0.4, y: 0.6)],
      regions: [MapRegion(recordID: record.id, points: [[0.2, 0.3], [0.6, 0.3], [0.5, 0.7]])])
    let board = try studio.store.saveAtlasMap(
      worldID: studio.worldID, name: "Coast",
      content: String(decoding: JSONEncoder().encode(map), as: UTF8.self))
    try studio.reload()
    return (studio, record, board, map)
  }
  private func framed(_ map: AtlasDocument) -> AtlasViewState {
    AtlasViewState(
      zoom: 2.5, centerX: 0.35, centerY: 0.6, showMarkers: false, showRegions: true,
      selectedRecordID: map.regions.first?.recordID, selectedRegionID: map.regions.first?.id)
  }

  @Test func eachMapAndUniverseRestoresItsOwnViewAcrossDiskRestartWithoutChangingLore() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("world.sqlite").path
    let (studio, record, board, map) = try fixture(path)
    studio.setMode(.manual)
    studio.openBoard(board.id, kind: "atlas")
    studio.atlasView.value = framed(map)
    let firstView = studio.atlasView.value
    let otherMap = try studio.store.createAtlasMap(worldID: studio.worldID, name: "Interior")
    studio.openBoard(otherMap.id, kind: "atlas")
    #expect(studio.atlasView.value == AtlasViewState())
    studio.atlasView.value.zoom = 1.5
    studio.atlasView.value.showRegions = false
    studio.openBoard(board.id, kind: "atlas")
    #expect(studio.atlasView.value == firstView)
    #expect(studio.atlasSelectedID == record.id)
    try studio.atlasView.persist()
    let foreignWorld = try studio.store.createWorld(name: "Elsewhere")
    let foreignMap = try studio.store.createAtlasMap(worldID: foreignWorld.id, name: "Coast")
    studio.switchWorld(foreignWorld.id)
    studio.openBoard(foreignMap.id, kind: "atlas")
    #expect(studio.atlasView.value == AtlasViewState() && studio.atlasSelectedID == nil)
    studio.switchWorld(record.worldID)
    studio.openBoard(board.id, kind: "atlas")
    #expect(studio.atlasView.value == firstView)
    let restarted = try Studio(store: WorkspaceStore(path: path))
    restarted.openBoard(board.id, kind: "atlas")
    #expect(restarted.atlasView.value == firstView && restarted.mode == .manual && !restarted.busy)
    #expect(try restarted.store.preference("atlas-last-map:\(record.worldID)") == board.id)
    #expect(
      try restarted.store.board(worldID: record.worldID, id: board.id, kind: "atlas") == board)
    #expect(try restarted.store.record(worldID: record.worldID, id: record.id) == record)
  }

  @Test func historyAndLayoutsRestoreVisitFramingAndSaveFailuresDoNotConsumeIt() throws {
    let (studio, record, board, map) = try fixture()
    studio.openBoard(board.id, kind: "atlas")
    studio.atlasView.value = framed(map)
    studio.atlasSelectedID = record.id
    let original = studio.navigationLocation
    let layout = try studio.saveLayout(name: "Coast survey")
    studio.openRecord(record)
    studio.editorSave = { false }
    let visits = studio.navigationBack
    studio.goBack()
    #expect(studio.selectedRecord?.id == record.id && studio.navigationBack == visits)
    studio.editorSave = nil
    studio.goBack()
    #expect(studio.navigationLocation == original && studio.atlasView.value == framed(map))
    studio.atlasView.value.zoom = 4
    studio.navigate(.timeline)
    studio.goBack()
    #expect(studio.atlasView.value.zoom == 4)
    #expect(studio.applyLayout(layout.id))
    #expect(studio.atlasView.value == framed(map))
    var old = original
    old.atlasView = nil
    let data = try JSONEncoder().encode(old)
    #expect(try JSONDecoder().decode(NavigationLocation.self, from: data).atlasView == nil)
    #expect(studio.restoreNavigation(old))
  }

  @Test func archivedOrRemovedSelectionsClearWithoutLosingTheMapAndFraming() throws {
    let (studio, record, board, map) = try fixture()
    studio.openBoard(board.id, kind: "atlas")
    studio.atlasView.value = framed(map)
    studio.atlasSelectedID = record.id
    let address = studio.navigationLocation
    studio.navigate(.library)
    try studio.store.archiveRecord(worldID: record.worldID, id: record.id)
    try studio.reload()
    #expect(studio.restoreNavigation(address))
    #expect(studio.mapBoardID == board.id && studio.atlasView.value.zoom == 2.5)
    #expect(
      studio.atlasView.value.selectedRecordID == nil
        && studio.atlasView.value.selectedRegionID == nil)
    #expect(studio.atlasSelectedID == nil)
    let empty = AtlasDocument()
    let sanitized = framed(map).reconciled(with: empty, recordIDs: [record.id])
    #expect(
      sanitized.selectedRegionID == nil && sanitized.selectedRecordID == nil
        && sanitized.zoom == 2.5)
    try studio.store.archiveAtlasMap(worldID: record.worldID, id: board.id)
    let before = studio.navigationLocation
    #expect(!studio.restoreNavigation(address))
    #expect(studio.navigationLocation == before)
  }

  @Test func corruptAndForeignViewPreferencesArePreservedAndCannotLeakSelection() throws {
    let (studio, record, board, map) = try fixture()
    let key = AtlasViewSession.key(worldID: studio.worldID, boardID: board.id)
    try studio.store.setPreference(key, value: "unreadable preference")
    studio.openBoard(board.id, kind: "atlas")
    #expect(studio.atlasView.recoveryNotice != nil && studio.atlasView.value == AtlasViewState())
    try studio.atlasView.persist()
    #expect(try studio.store.preference(key) == "unreadable preference")
    studio.atlasView.value = framed(map)
    try studio.atlasView.persist()
    #expect(try studio.store.preference("recovery:\(key)") == "unreadable preference")
    let foreign = try studio.store.createWorld(name: "Other")
    let foreignMap = try studio.store.createAtlasMap(worldID: foreign.id, name: "Coast")
    try studio.store.setPreference(
      AtlasViewSession.key(worldID: foreign.id, boardID: foreignMap.id),
      value: try #require(try studio.store.preference(key)))
    studio.switchWorld(foreign.id)
    studio.openBoard(foreignMap.id, kind: "atlas")
    #expect(studio.atlasView.value == AtlasViewState() && studio.atlasSelectedID == nil)
    #expect(throws: (any Error).self) {
      try studio.atlasView.activate(
        worldID: foreign.id, board: board, map: map, recordIDs: [record.id])
    }
    #expect(studio.atlasView.boardID == foreignMap.id)
  }

  @Test func imageRelativeFramingKeepsZoomAnchorsAndSurvivesPaneResize() {
    var view = AtlasViewState(zoom: 2, centerX: 0.4, centerY: 0.6)
    let base = CGSize(width: 800, height: 500)
    let anchor = CGPoint(x: 170, y: -70)
    let before = view.pan(imageSize: CGSize(width: 1600, height: 1000))
    let point = CGPoint(
      x: (anchor.x - before.width) / 1600 + 0.5, y: (anchor.y - before.height) / 1000 + 0.5)
    view.magnify(by: 1.25, anchor: anchor, baseImageSize: base)
    let after = view.pan(imageSize: CGSize(width: 2000, height: 1250))
    #expect(abs((point.x - 0.5) * 2000 + after.width - anchor.x) < 0.001)
    #expect(abs((point.y - 0.5) * 1250 + after.height - anchor.y) < 0.001)
    let half = view.pan(imageSize: CGSize(width: 1000, height: 625))
    #expect(
      abs(half.width * 2 - after.width) < 0.001 && abs(half.height * 2 - after.height) < 0.001)
    view.move(by: CGSize(width: 100, height: -50), imageSize: CGSize(width: 2000, height: 1250))
    #expect(
      abs(view.pan(imageSize: CGSize(width: 2000, height: 1250)).width - after.width - 100) < 0.001)
    let stable = view
    view.magnify(by: .nan, anchor: anchor, baseImageSize: base)
    view.move(by: CGSize(width: CGFloat.infinity, height: 0), imageSize: base)
    #expect(view == stable)
    view.showMarkers = false
    view.fit()
    #expect(view.zoom == 1 && view.centerX == 0.5 && view.centerY == 0.5 && !view.showMarkers)
  }

  @Test func remountingTheRealAtlasViewRestoresSelectionAndLayers() async throws {
    _ = NSApplication.shared
    let (studio, record, board, map) = try fixture()
    studio.sheet = nil
    studio.openBoard(board.id, kind: "atlas")
    var host: NSHostingView<AtlasScreen>? = NSHostingView(rootView: AtlasScreen(studio: studio))
    host?.frame = CGRect(x: 0, y: 0, width: 1000, height: 650)
    host?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(80))
    #expect(studio.editorSave != nil)
    studio.atlasView.value = framed(map)
    studio.atlasSelectedID = record.id
    studio.openRecord(record)
    host = nil
    studio.goBack()
    host = NSHostingView(rootView: AtlasScreen(studio: studio))
    host?.frame = CGRect(x: 0, y: 0, width: 700, height: 500)
    host?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(80))
    #expect(studio.editorSave != nil)
    #expect(studio.atlasView.value == framed(map) && studio.atlasSelectedID == record.id)
    #expect(studio.flushEditor())
    #expect(try studio.store.board(worldID: studio.worldID, id: board.id, kind: "atlas") == board)
    let other = try studio.store.createAtlasMap(worldID: studio.worldID, name: "Interior")
    studio.openBoard(other.id, kind: "atlas")
    host?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(80))
    #expect(studio.editorSave != nil && studio.atlasView.boardID == other.id)
    studio.openBoard(board.id, kind: "atlas")
    host?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(80))
    #expect(studio.editorSave != nil && studio.atlasView.value == framed(map))
  }
}
