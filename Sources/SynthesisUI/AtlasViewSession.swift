import Foundation
import SwiftUI
import SynthesisCore

/// Image-relative framing survives pane/window resizing. This is presentation, never map lore.
struct AtlasViewState: Codable, Equatable {
  var zoom = 1.0
  var centerX = 0.5
  var centerY = 0.5
  var showMarkers = true
  var showRegions = true
  var selectedRecordID: String?
  var selectedRegionID: String?

  func pan(imageSize: CGSize) -> CGSize {
    CGSize(width: (0.5 - centerX) * imageSize.width, height: (0.5 - centerY) * imageSize.height)
  }
  mutating func move(by delta: CGSize, imageSize: CGSize) {
    guard imageSize.width > 0, imageSize.height > 0, imageSize.width.isFinite,
      imageSize.height.isFinite, delta.width.isFinite, delta.height.isFinite
    else { return }
    centerX = min(5, max(-4, centerX - delta.width / imageSize.width))
    centerY = min(5, max(-4, centerY - delta.height / imageSize.height))
  }
  mutating func magnify(by factor: Double, anchor: CGPoint, baseImageSize: CGSize) {
    guard baseImageSize.width > 0, baseImageSize.height > 0, baseImageSize.width.isFinite,
      baseImageSize.height.isFinite, factor.isFinite, factor > 0,
      anchor.x.isFinite, anchor.y.isFinite
    else { return }
    let next = SpatialViewport.zoom(
      scale: zoom,
      pan: pan(
        imageSize: CGSize(width: baseImageSize.width * zoom, height: baseImageSize.height * zoom)),
      factor: factor, anchor: anchor, limits: 0.5...5)
    zoom = next.scale
    centerX = min(5, max(-4, 0.5 - next.pan.width / (baseImageSize.width * zoom)))
    centerY = min(5, max(-4, 0.5 - next.pan.height / (baseImageSize.height * zoom)))
  }
  mutating func fit() {
    zoom = 1
    centerX = 0.5
    centerY = 0.5
  }

  func reconciled(with map: AtlasDocument, recordIDs: Set<String>) -> Self {
    var value = self
    value.zoom = zoom.isFinite ? min(5, max(0.5, zoom)) : 1
    value.centerX = centerX.isFinite ? min(5, max(-4, centerX)) : 0.5
    value.centerY = centerY.isFinite ? min(5, max(-4, centerY)) : 0.5
    if let region = map.regions.first(where: { $0.id == value.selectedRegionID }),
      recordIDs.contains(region.recordID)
    {
      value.selectedRecordID = region.recordID
    } else {
      value.selectedRegionID = nil
    }
    let placed = Set(map.markers.map(\.recordID) + map.regions.map(\.recordID))
    if let selected = value.selectedRecordID,
      !placed.contains(selected) || !recordIDs.contains(selected)
    {
      value.selectedRecordID = nil
    }
    return value
  }
}

private struct SavedAtlasView: Codable {
  var version = 1
  let worldID: String
  let boardID: String
  let view: AtlasViewState
}

/// Retained by Studio while Atlas views mount/unmount. Persistence occurs at navigation/save
/// boundaries, never for each trackpad event. Each world/map has an independent local address.
@MainActor final class AtlasViewSession: ObservableObject {
  @Published var value = AtlasViewState()
  private(set) var worldID: String?
  private(set) var boardID: String?
  private var original = AtlasViewState()
  private var unreadable: String?
  private(set) var recoveryNotice: String?
  private let store: WorkspaceStore
  init(store: WorkspaceStore) { self.store = store }
  static func key(worldID: String, boardID: String) -> String { "atlas-view:\(worldID):\(boardID)" }
  func matches(worldID: String, boardID: String?) -> Bool {
    self.worldID == worldID && self.boardID == boardID && boardID != nil
  }
  func activate(
    worldID: String, board: Board, map: AtlasDocument, recordIDs: Set<String>,
    restoring: AtlasViewState? = nil
  ) throws {
    guard board.kind == "atlas",
      try store.board(worldID: worldID, id: board.id, kind: "atlas") == board
    else { throw SynthesisError.notFound }
    if !matches(worldID: worldID, boardID: board.id) {
      let raw = try store.preference(Self.key(worldID: worldID, boardID: board.id))
      try persist()
      self.worldID = worldID
      boardID = board.id
      value = AtlasViewState()
      unreadable = nil
      recoveryNotice = nil
      if let raw {
        if raw.utf8.count <= 16_384,
          let saved = try? JSONDecoder().decode(SavedAtlasView.self, from: Data(raw.utf8)),
          saved.version == 1, saved.worldID == worldID, saved.boardID == board.id
        {
          value = saved.view
        } else {
          unreadable = raw
          recoveryNotice = "The saved Atlas view could not be read. The map itself is unchanged."
        }
      }
      original = value
    }
    value = (restoring ?? value).reconciled(with: map, recordIDs: recordIDs)
  }
  func persist() throws {
    guard let worldID, let boardID else { return }
    // Archived map addresses remain available for Undo, but are never resurrected here.
    guard try store.boards(worldID: worldID, kind: "atlas").contains(where: { $0.id == boardID })
    else { return }
    let key = Self.key(worldID: worldID, boardID: boardID)
    let existing = try store.preference(key)
    if value != original || (unreadable == nil && existing == nil) {
      if let unreadable { try store.setPreference("recovery:\(key)", value: unreadable) }
      try store.setPreference(
        key,
        value: String(
          decoding: JSONEncoder().encode(
            SavedAtlasView(worldID: worldID, boardID: boardID, view: value)), as: UTF8.self))
      original = value
      unreadable = nil
      recoveryNotice = nil
    }
    if try store.preference("atlas-last-map:\(worldID)") != boardID {
      try store.setPreference("atlas-last-map:\(worldID)", value: boardID)
    }
  }
  func deactivate() throws {
    try persist()
    worldID = nil
    boardID = nil
    value = AtlasViewState()
    original = value
    unreadable = nil
    recoveryNotice = nil
  }
}

extension Studio {
  /// Used by history/layouts as well as view creation, so a restored address is visible to the
  /// agent immediately and never depends on a later SwiftUI appearance callback.
  func restoreAtlasView(boardID: String, view: AtlasViewState? = nil, selection: String? = nil)
    throws
  {
    let board = try store.board(worldID: worldID, id: boardID, kind: "atlas")
    let map = try JSONDecoder().decode(AtlasDocument.self, from: Data(board.content.utf8))
    try atlasView.activate(
      worldID: worldID, board: board, map: map, recordIDs: Set(records.map(\.id)), restoring: view)
    if view == nil, let selection {
      atlasView.value.selectedRecordID = selection
      if !map.regions.contains(where: {
        $0.id == atlasView.value.selectedRegionID && $0.recordID == selection
      }) {
        atlasView.value.selectedRegionID = nil
      }
      atlasView.value = atlasView.value.reconciled(with: map, recordIDs: Set(records.map(\.id)))
    }
    atlasSelectedID = atlasView.value.selectedRecordID
  }
}
