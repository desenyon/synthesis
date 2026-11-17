import Foundation
import SynthesisCore

extension Studio {
  func configureAtlasContextCapture(_ state: String, board: String, conversation: String) {
    configureConnectedCapture("atlas-linked", board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    perform {
      guard let id = mapBoardID else { throw SynthesisError.notFound }
      let source = try store.board(worldID: worldID, id: id, kind: "atlas")
      let map = try JSONDecoder().decode(AtlasDocument.self, from: Data(source.content.utf8))
      guard let region = map.regions.first else { throw SynthesisError.notFound }
      let view = AtlasViewState(
        zoom: 1.75, centerX: 0.46, centerY: 0.49,
        showMarkers: state.hasSuffix("layers"), showRegions: !state.hasSuffix("layers"),
        selectedRecordID: region.recordID, selectedRegionID: region.id)
      try restoreAtlasView(boardID: id, view: view)
    }
    captureHint = state
  }

  /// Runs on the real mounted Atlas. No key events, activation, or provider requests.
  public func auditAtlasContextCapture(_ state: String) async throws -> [String] {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      let id = mapBoardID, let selected = atlasView.value.selectedRecordID,
      editorSave != nil
    else { throw SynthesisError.invalid("Atlas context capture did not mount a map.") }
    let source = try store.board(worldID: worldID, id: id, kind: "atlas")
    let record = try store.record(worldID: worldID, id: selected)
    var expected = atlasView.value
    if state.hasSuffix("return") || state.hasSuffix("layers") {
      openRecord(record)
      try await Task.sleep(for: .milliseconds(200))
      guard selectedRecord?.id == record.id else { throw SynthesisError.notFound }
      goBack()
    } else if state.hasSuffix("tools") {
      navigate(.timeline)
      try await Task.sleep(for: .milliseconds(200))
      navigate(.chat)
      try await Task.sleep(for: .milliseconds(200))
      goBack()
      try await Task.sleep(for: .milliseconds(200))
      goBack()
    } else if state.hasSuffix("map-switch") {
      guard
        let other = try store.boards(worldID: worldID, kind: "atlas").first(where: {
          $0.id != id
        })
      else { throw SynthesisError.notFound }
      openBoard(other.id, kind: "atlas")
      try await Task.sleep(for: .milliseconds(200))
      openBoard(id, kind: "atlas")
    } else if state.hasSuffix("split") {
      openBeside(record)
    } else if state.hasSuffix("fit") {
      atlasView.value.fit()
      expected.fit()
    }
    try await Task.sleep(for: .milliseconds(250))
    guard error == nil, destination == .atlas, selectedRecord == nil, mapBoardID == id,
      atlasView.value == expected, atlasSelectedID == record.id, editorSave != nil,
      flushEditor(), !busy,
      try store.board(worldID: worldID, id: id, kind: "atlas") == source,
      try store.record(worldID: worldID, id: record.id) == record
    else {
      throw SynthesisError.invalid(
        "Atlas restoration failed (\(state)): view=\(atlasView.value == expected), map=\(mapBoardID == id), selection=\(atlasSelectedID == record.id), save=\(editorSave != nil), error=\(error ?? "none")."
      )
    }
    return [
      "PASS \(state): framing/layers/region/source restored on the mounted Atlas",
      "PASS \(state): save boundary preserved map and lore; no generation active",
    ]
  }
}
