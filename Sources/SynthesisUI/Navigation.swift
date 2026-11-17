import SwiftUI
import SynthesisCore

/// An address in a universe, not a copy of its lore. Replay always resolves current records.
struct NavigationLocation: Codable, Equatable {
  var worldID: String
  var destination: Destination
  var recordID: String?
  var category: String?
  var conversationID: String?
  var boardID: String?
  var selectionID: String?
  var laneID: String?
}
struct NavigationEntry: Identifiable, Equatable {
  let id = UUID()
  var location: NavigationLocation
  var title: String
  var world: String
}

extension Studio {
  var navigationLocation: NavigationLocation {
    NavigationLocation(
      worldID: worldID, destination: destination, recordID: selectedRecord?.id,
      category: destination == .library ? libraryCategory : nil,
      conversationID: destination == .chat ? conversationID : nil,
      boardID: destination == .canvas
        ? (canvasBoardID ?? contextBoards.first(where: { $0.kind == "canvas" })?.id)
        : (destination == .atlas
          ? (mapBoardID ?? contextBoards.first(where: { $0.kind == "atlas" })?.id) : nil),
      selectionID: destination == .knowledge
        ? graphSelectedID
        : (destination == .atlas ? atlasSelectedID : nil),
      laneID: destination == .timeline ? timelineLaneID : nil)
  }
  var navigationEntry: NavigationEntry {
    var title = selectedRecord?.title ?? libraryCategory ?? destination.rawValue
    if selectedRecord == nil {
      if destination == .chat { title = conversationTitle }
      if let id = navigationLocation.boardID,
        let board = try? store.boards(
          worldID: worldID, kind: destination == .canvas ? "canvas" : "atlas"
        ).first(where: { $0.id == id })
      {
        title = board.name
      }
    }
    return NavigationEntry(
      location: navigationLocation, title: title, world: world?.name ?? "World")
  }
  /// Nested helpers form a single visit; a failed save or a repeated location forms none.
  func withNavigation(_ action: () -> Void) {
    let before = navigationEntry
    navigationDepth += 1
    defer {
      navigationDepth -= 1
      if navigationDepth == 0 && !replayingNavigation && before.location != navigationLocation {
        navigationBack.append(before)
        navigationBack = Array(navigationBack.suffix(100))
        navigationForward.removeAll()
      }
    }
    action()
  }
  public var canNavigateBack: Bool { !navigationBack.isEmpty }
  public var canNavigateForward: Bool { !navigationForward.isEmpty }
  public func goBack() { travel(backward: true, index: navigationBack.count - 1) }
  public func goForward() { travel(backward: false, index: navigationForward.count - 1) }
  func goBack(to index: Int) { travel(backward: true, index: index) }
  func goForward(to index: Int) { travel(backward: false, index: index) }

  private func travel(backward: Bool, index: Int) {
    let entries = backward ? navigationBack : navigationForward
    guard entries.indices.contains(index), flushEditor() else { return }
    let current = navigationEntry
    var cursor = index
    // Archived destinations may disappear since the visit. Skip them without resurrecting data.
    while cursor >= 0 {
      let target = entries[cursor]
      do {
        try validateNavigation(target.location)
      } catch SynthesisError.invalid, SynthesisError.notFound {
        cursor -= 1
        continue
      } catch {
        self.error = error.localizedDescription
        return
      }
      guard restoreNavigation(target.location) else { return }
      let crossed = [current] + entries[(cursor + 1)...].reversed()
      if backward {
        navigationBack = Array(entries[..<cursor])
        navigationForward = Array((navigationForward + crossed).suffix(100))
      } else {
        navigationForward = Array(entries[..<cursor])
        navigationBack = Array((navigationBack + crossed).suffix(100))
      }
      return
    }
    if backward { navigationBack.removeAll() } else { navigationForward.removeAll() }
    show("Those earlier locations are no longer available.", icon: "info.circle")
  }

  func validateNavigation(_ address: NavigationLocation) throws {
    guard try store.worlds().contains(where: { $0.id == address.worldID }) else {
      throw SynthesisError.invalid("This universe is no longer available.")
    }
    for id in [address.recordID, address.selectionID].compactMap({ $0 }) {
      _ = try store.record(worldID: address.worldID, id: id)
      guard try !store.isArchived(worldID: address.worldID, recordID: id) else {
        throw SynthesisError.invalid("This record is no longer available in that universe.")
      }
    }
    if let id = address.conversationID {
      guard try store.conversations(worldID: address.worldID).contains(where: { $0.id == id })
      else {
        throw SynthesisError.invalid("This conversation is no longer available.")
      }
    }
    if let id = address.boardID {
      guard [.canvas, .atlas].contains(address.destination),
        try store.boards(
          worldID: address.worldID, kind: address.destination == .canvas ? "canvas" : "atlas"
        ).contains(where: { $0.id == id })
      else { throw SynthesisError.invalid("This board is no longer available.") }
    }
    if let id = address.laneID {
      guard try store.chronologyLanes(worldID: address.worldID).contains(where: { $0.id == id })
      else {
        throw SynthesisError.invalid("This history branch is no longer available.")
      }
    }
  }
  /// Shared by history and saved arrangements. Does not restore text, canon, or assistance mode.
  @discardableResult func restoreNavigation(_ address: NavigationLocation) -> Bool {
    guard flushEditor() else { return false }
    do {
      try validateNavigation(address)
      let fresh = try address.recordID.map { try store.record(worldID: address.worldID, id: $0) }
      replayingNavigation = true
      defer { replayingNavigation = false }
      if address.worldID != worldID {
        switchWorld(address.worldID)
        guard worldID == address.worldID else { return false }
      }
      if address.destination == .chat && conversationID != address.conversationID { stop() }
      editorSave = nil
      selectedRecord = fresh
      destination = address.destination
      libraryCategory = address.category
      if address.destination == .chat {
        conversationID = address.conversationID
        try reloadMessages()
      }
      if address.destination == .canvas {
        canvasBoardID = address.boardID
        canvasSession?.switchBoard(address.boardID)
      }
      if address.destination == .atlas {
        mapBoardID = address.boardID
        atlasSelectedID = address.selectionID
      }
      if address.destination == .knowledge { graphSelectedID = address.selectionID }
      if address.destination == .timeline { timelineLaneID = address.laneID }
      if address.destination != .canvas {
        canvasUndo = nil
        canvasFit = nil
      }
      pendingEventSourceID = nil
      inspectionTarget = nil
      mobileNavigation = false
      try store.setPreference("destination", value: destination.rawValue)
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }

  func openBoard(_ id: String, kind: String) {
    withNavigation {
      guard ["canvas", "atlas"].contains(kind), flushEditor() else { return }
      perform {
        guard try store.boards(worldID: worldID, kind: kind).contains(where: { $0.id == id }) else {
          throw SynthesisError.invalid("This board is no longer available in this universe.")
        }
        navigate(kind == "canvas" ? .canvas : .atlas)
        if kind == "canvas" {
          canvasBoardID = id
          canvasSession?.switchBoard(id)
        } else {
          mapBoardID = id
          atlasSelectedID = nil
        }
      }
    }
  }
}

struct NavigationButtons: View {
  @ObservedObject var studio: Studio
  var body: some View {
    HStack(spacing: 0) {
      IconButton(icon: "chevron.left", label: "Back · ⌘[", t: studio.t, size: 26) {
        studio.goBack()
      }.disabled(!studio.canNavigateBack).contextMenu {
        ForEach(studio.navigationBack.indices.reversed(), id: \.self) { index in
          Button(label(studio.navigationBack[index])) { studio.goBack(to: index) }
        }
      }
      IconButton(icon: "chevron.right", label: "Forward · ⌘]", t: studio.t, size: 26) {
        studio.goForward()
      }.disabled(!studio.canNavigateForward).contextMenu {
        ForEach(studio.navigationForward.indices.reversed(), id: \.self) { index in
          Button(label(studio.navigationForward[index])) { studio.goForward(to: index) }
        }
      }
    }.accessibilityElement(children: .contain).accessibilityLabel("Navigation history")
  }
  private func label(_ entry: NavigationEntry) -> String {
    entry.location.worldID == studio.worldID ? entry.title : "\(entry.world) / \(entry.title)"
  }
}

/// The last two records in this visit's trail, with a menu for the complete history.
struct RecordTrail: View {
  @ObservedObject var studio: Studio
  let origin: String
  @Environment(\.barCompact) private var compact
  private var ancestors: [Int] {
    var trail: [Int] = []
    for index in studio.navigationBack.indices.reversed() {
      let entry = studio.navigationBack[index]
      guard entry.location.worldID == studio.worldID, entry.location.recordID != nil else { break }
      trail.insert(index, at: 0)
      if trail.count == 2 { break }
    }
    return trail
  }
  var body: some View {
    HStack(spacing: 6) {
      if !compact {
        Button(origin) { studio.closeRecord() }.buttonStyle(.plain)
          .font(.studio(.label)).foregroundStyle(studio.t.secondary).lineLimit(1)
          .frame(maxWidth: 100).help("Return to \(origin)")
        ForEach(ancestors, id: \.self) { index in
          StudioIcon("chevron.right", size: 9).foregroundStyle(studio.t.muted)
          Button(studio.navigationBack[index].title) { studio.goBack(to: index) }
            .buttonStyle(.plain).font(.studio(.label)).foregroundStyle(studio.t.secondary)
            .lineLimit(1).frame(maxWidth: 112).help(studio.navigationBack[index].title)
        }
        StudioIcon("chevron.right", size: 9).foregroundStyle(studio.t.muted)
      }
    }
  }
}
