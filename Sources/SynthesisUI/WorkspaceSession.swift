import AppKit
import Combine
import SynthesisCore

/// Device-local presentation only. Lore, approval state and provider permissions are not snapshots.
struct WorkspaceSession: Codable {
  var version = 1
  var location: NavigationLocation
  var documents: OpenDocuments
  var recordTabs: [String: RecordPageTab]
  var editorPositions: [String: EditorPosition]
  var graph: GraphViewState
  var timeline: TimelineViewState
  var conversationID: String?
  var conversationAnchors: [String: String]
  var canvasID: String?
  var mapID: String?
  var graphSelection: String?
  var atlasSelection: String?
  var timelineLane: String?
  var libraryQuery: String
  var libraryCategory: String?
  var libraryFilter: LibraryFilter
  var libraryOrder: LibraryOrder
  var settingsSection: SettingsSection
  var settingsQuery: String
  var reviewSection: ReviewSection?
  var reviewFocus: String?
  var inspector: Bool
  var workspaceInspector: Bool
  var splitInspector: Bool
  var companion: Bool
  var preset: String
  var back: [NavigationEntry]
  var forward: [NavigationEntry]
}

struct GraphViewState: Codable, Equatable {
  var positions: [String: CGPoint] = [:]
  var signature = ""
  var landscape: Bool?
  var zoom = 1.0
  var pan = CGSize.zero
  var query = ""
  var framed = false
  var neighborhood: GraphNeighborhood?

  func reconciled(records: [LoreRecord]) -> Self {
    var value = self
    let ids = Set(records.filter { $0.kind == "entity" }.map(\.id))
    value.positions = positions.filter {
      ids.contains($0.key) && $0.value.x.isFinite && $0.value.y.isFinite
        && abs($0.value.x) < 10_000_000 && abs($0.value.y) < 10_000_000
    }
    value.zoom = zoom.isFinite ? min(2.2, max(0.1, zoom)) : 1
    value.pan =
      pan.width.isFinite && pan.height.isFinite
        && abs(pan.width) < 10_000_000 && abs(pan.height) < 10_000_000 ? pan : .zero
    if value.positions.isEmpty {
      value.framed = false
      value.signature = ""
    } else if Set(value.positions.keys) != ids {
      // A cancelled or older layout may contain valid positions for only part of this world.
      // Keep those positions while requesting a fresh layout for the current topology.
      value.signature = ""
    }
    value.query = String(query.prefix(2000))
    if let neighborhood, ids.contains(neighborhood.rootID) {
      value.neighborhood?.depth = min(max(1, neighborhood.depth), max(1, ids.count - 1))
    } else {
      value.neighborhood = nil
    }
    return value
  }
}

struct TimelineViewState: Codable, Equatable {
  static let unplacedEraID = "unplaced"

  var density = TimelineDensity.detailed
  var eraDateFilter: TimelineDateFilter?
  var foldedLanes: Set<String> = []
  var foldedEras: Set<String> = []
  var query = ""
}

struct EditorPosition: Codable, Equatable {
  var location: Int
  var length: Int
  var scrollY: Double
}

extension Studio {
  func observeWorkspaceSession() {
    sessionReady = true
    sessionObservation = objectWillChange.sink { [weak self] in
      self?.queueWorkspaceSessionSave()
    }
  }
  func queueWorkspaceSessionSave() {
    guard sessionReady, !restoringSession else { return }
    sessionSaveTask?.cancel()
    sessionSaveTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
      guard let self, !Task.isCancelled else { return }
      _ = self.persistWorkspaceSession()
    }
  }
  func workspaceSession() -> WorkspaceSession {
    var positions = editorPositions
    for (id, handle) in documentEditors {
      if let position = handle.position { positions[id] = position }
    }
    let ids = Set(documentSession.open)
    return WorkspaceSession(
      location: navigationLocation, documents: documentSession,
      recordTabs: recordTabs.filter { ids.contains($0.key) },
      editorPositions: positions.filter { ids.contains($0.key) },
      graph: graphView, timeline: timelineView, conversationID: conversationID,
      conversationAnchors: conversationScrollAnchors,
      canvasID: canvasBoardID ?? canvasSession?.boardID, mapID: mapBoardID,
      graphSelection: graphSelectedID, atlasSelection: atlasSelectedID,
      timelineLane: timelineLaneID, libraryQuery: libraryQuery, libraryCategory: libraryCategory,
      libraryFilter: libraryFilter, libraryOrder: libraryOrder,
      settingsSection: settingsSection, settingsQuery: settingsQuery,
      reviewSection: reviewSection, reviewFocus: reviewFocusID, inspector: inspector,
      workspaceInspector: workspaceInspector, splitInspector: splitInspector,
      companion: companionExpanded, preset: preset,
      back: Array(navigationBack.suffix(100)), forward: Array(navigationForward.suffix(100)))
  }
  /// Atomically saves addresses and the newest shared draft. Never invokes a model or rewrites lore.
  @discardableResult public func persistWorkspaceSession(force: Bool = false) -> Bool {
    guard sessionReady, !restoringSession, force || navigationDepth == 0 else { return true }
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let json = String(decoding: try encoder.encode(workspaceSession()), as: UTF8.self)
      let text =
        pendingComposer.flatMap {
          $0.world == worldID && $0.base == draft ? $0.text : nil
        } ?? draft
      let key = worldID + "\n" + json + "\n" + text
      guard key != lastSessionSave else { return true }
      try store.setPreferences([
        "workspace-session:\(worldID)": json, "composer:\(worldID)": text,
        "destination": destination.rawValue, "world": worldID,
      ])
      lastSessionSave = key
      sessionSaveFailure = nil
      return true
    } catch {
      let message = "Your workspace session could not be saved. " + error.localizedDescription
      if sessionSaveFailure != message {
        sessionSaveFailure = message
        self.error = message
      }
      return false
    }
  }
  /// Used by both native close paths. A failed editor or session save keeps the window open.
  public func saveSessionForClose() -> Bool {
    guard flushEditor() else { return false }
    return persistWorkspaceSession()
  }

  func restoreWorkspaceSession(restoreLocation: Bool, restoreHistory: Bool = true) throws {
    restoringSession = true
    defer { restoringSession = false }
    sessionSaveTask?.cancel()
    lastSessionSave = nil
    graphView = GraphViewState()
    timelineView = TimelineViewState()
    timelineView.density =
      (try store.preference("timeline-density"))
      .flatMap(TimelineDensity.init(rawValue:)) ?? .detailed
    editorPositions = [:]
    recordTabs = [:]
    conversationScrollAnchors = [:]
    guard let raw = try store.preference("workspace-session:\(worldID)") else { return }
    let session: WorkspaceSession
    do {
      guard raw.utf8.count <= 16_000_000 else { throw SynthesisError.invalid("Session too large.") }
      session = try JSONDecoder().decode(WorkspaceSession.self, from: Data(raw.utf8))
      guard session.version == 1, session.location.worldID == worldID else {
        throw SynthesisError.invalid("Unsupported or mismatched session.")
      }
      _ = try session.documents.validated(records: records)
    } catch {
      try store.setPreference("workspace-session-backup:\(worldID)", value: raw)
      self.error =
        "The saved workspace could not be restored. A copy was preserved; your lore is unchanged."
      return
    }
    let live = Set(records.map(\.id))
    let entities = Set(records.filter { $0.kind == "entity" }.map(\.id))
    documentSession = try session.documents.validated(records: records)
    recordTabs = session.recordTabs.filter { live.contains($0.key) }
    editorPositions = session.editorPositions.filter { live.contains($0.key) }
    graphView = session.graph.reconciled(records: records)
    timelineView = session.timeline
    let lanes = Set(contextLanes.map(\.id))
    timelineView.foldedLanes.formIntersection(lanes)
    timelineView.foldedEras.formIntersection(lanes.union([TimelineViewState.unplacedEraID]))
    timelineView.query = String(timelineView.query.prefix(2000))
    conversationID = session.conversationID.flatMap { id in
      conversations.contains { $0.id == id } ? id : nil
    }
    let chatIDs = Set(conversations.map(\.id))
    conversationScrollAnchors = session.conversationAnchors.filter { chatIDs.contains($0.key) }
    canvasBoardID = validSessionBoard(session.canvasID, kind: "canvas")
    mapBoardID = validSessionBoard(session.mapID, kind: "atlas")
    graphSelectedID = session.graphSelection.flatMap { entities.contains($0) ? $0 : nil }
    atlasSelectedID = session.atlasSelection.flatMap { live.contains($0) ? $0 : nil }
    timelineLaneID = session.timelineLane.flatMap { lanes.contains($0) ? $0 : nil }
    libraryQuery = String(session.libraryQuery.prefix(2000))
    libraryCategory = session.libraryCategory
    libraryEntityTypeID = nil
    libraryFilter = session.libraryFilter
    libraryOrder = session.libraryOrder
    settingsSection = session.settingsSection
    settingsQuery = String(session.settingsQuery.prefix(2000))
    reviewSection = session.reviewSection
    reviewFocusID = pendingProposals.first { $0.id == session.reviewFocus }?.id
    inspector = session.inspector
    workspaceInspector = session.workspaceInspector
    splitInspector = session.splitInspector
    companionExpanded = mode == .assisted && session.companion
    if ["Create", "Develop", "Critique", "Simulate", "Canonize"].contains(session.preset) {
      preset = session.preset
    }
    if restoreHistory {
      navigationBack = session.back.suffix(100).filter {
        (try? validateNavigation($0.location)) != nil
      }
      navigationForward = session.forward.suffix(100).filter {
        (try? validateNavigation($0.location)) != nil
      }
    }
    if restoreLocation {
      var address = session.location
      address.recordID = address.recordID.flatMap { live.contains($0) ? $0 : nil }
      address.splitRecordID = address.splitRecordID.flatMap {
        live.contains($0) && $0 != address.recordID ? $0 : nil
      }
      address.selectionID = address.selectionID.flatMap { live.contains($0) ? $0 : nil }
      address.conversationID = conversationID
      if address.destination == .canvas { address.boardID = canvasBoardID }
      if address.destination == .atlas { address.boardID = mapBoardID }
      address.laneID = timelineLaneID
      if mode == .manual && address.destination == .chat { address.destination = .library }
      guard restoreNavigation(address) else { return }
    } else {
      // An explicit startup home wins. Keep its other documents in the restored tab strip.
      selectedRecord = nil
      splitRecord = nil
      splitEditorSave = nil
    }
    recordTabs = session.recordTabs.filter { live.contains($0.key) }
    try reloadMessages()
  }
  private func validSessionBoard(_ id: String?, kind: String) -> String? {
    id.flatMap { id in contextBoards.contains { $0.id == id && $0.kind == kind } ? id : nil }
  }
}
