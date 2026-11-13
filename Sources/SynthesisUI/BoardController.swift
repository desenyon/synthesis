import AppKit
import SwiftUI
import SynthesisCore

/// Owns one saved board: cards, board-local links, viewport, selection and bounded undo history.
/// Removing a card never removes its source record.
@MainActor final class BoardController: ObservableObject {
  let studio: Studio
  let worldID: String
  @Published var document = CanvasDocument()
  @Published var boardID: String?
  @Published var name = "Untitled board"
  @Published var selection: Set<String> = []
  @Published var relationships: [Relation] = []
  @Published var viewport = BoardViewport()
  @Published var loaded = false
  @Published var failure: String?
  @Published var past: [CanvasDocument] = []
  @Published var future: [CanvasDocument] = []
  private var saveTask: Task<Void, Never>?
  static let defaultCard = CGSize(width: 300, height: 170)
  init(studio: Studio) {
    self.studio = studio
    worldID = studio.worldID
  }
  func load() {
    guard !loaded else { return }
    do {
      let boards = try studio.store.boards(worldID: worldID, kind: "canvas")
      let savedPreference = try studio.store.preference("canvas-selected:\(worldID)")
      let preferred = studio.canvasBoardID ?? savedPreference
      if let board = boards.first(where: { $0.id == preferred }) ?? boards.first {
        boardID = board.id
        name = board.name
        document = try JSONDecoder().decode(CanvasDocument.self, from: Data(board.content.utf8))
        viewport = document.viewport ?? BoardViewport()
      }
      relationships = try studio.store.relations(worldID: worldID)
      loaded = true
    } catch { failure = error.localizedDescription }
  }
  @discardableResult func save() -> Bool {
    saveTask?.cancel()
    saveTask = nil
    guard loaded else { return true }
    do {
      document.viewport = viewport
      let data = try JSONEncoder().encode(document)
      let board = try studio.store.saveBoard(
        worldID: worldID, id: boardID, name: name, kind: "canvas",
        content: String(decoding: data, as: UTF8.self))
      boardID = board.id
      try studio.store.setPreference("canvas-selected:\(worldID)", value: board.id)
      failure = nil
      return true
    } catch {
      failure = error.localizedDescription
      return false
    }
  }
  func mutate(_ change: (inout CanvasDocument) -> Void) {
    guard loaded else { return }
    let before = document
    change(&document)
    guard before != document else { return }
    past.append(before)
    if past.count > 60 { past.removeFirst() }
    future = []
    save()
  }
  func step(back: Bool) {
    if back, let next = past.popLast() {
      future.append(document)
      document = next
    } else if !back, let next = future.popLast() {
      past.append(document)
      document = next
    } else {
      return
    }
    selection = selection.filter { id in document.cards.contains { $0.id == id } }
    save()
  }
  func rename(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, loaded else { return }
    let previous = name
    name = String(trimmed.prefix(120))
    if !save() { name = previous }
  }

  // MARK: Viewport

  func moveViewport(_ delta: CGSize) {
    viewport.x += delta.width
    viewport.y += delta.height
    scheduleSave()
  }
  /// Additive zoom step around the centre of the board. Kept for toolbar buttons.
  func zoom(_ delta: Double) {
    zoom(factor: (viewport.zoom + delta) / viewport.zoom, anchor: .zero)
  }
  /// Multiplicative zoom keeping the world point under `anchor` (relative to the board centre) fixed.
  func zoom(factor: Double, anchor: CGPoint) {
    let next = min(2, max(0.25, viewport.zoom * factor))
    let ratio = next / viewport.zoom
    viewport.x = anchor.x - (anchor.x - viewport.x) * ratio
    viewport.y = anchor.y - (anchor.y - viewport.y) * ratio
    viewport.zoom = next
    scheduleSave()
  }
  func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { @MainActor in
      do {
        try await Task.sleep(for: .milliseconds(350))
        save()
      } catch {}
    }
  }
  /// World-space bounds of every card, using measured sizes where available.
  func bounds(sizes: [String: CGSize] = [:]) -> CGRect {
    document.cards.reduce(CGRect.null) { result, card in
      let size = sizes[card.id] ?? Self.defaultCard
      return result.union(
        CGRect(
          x: card.x - size.width / 2, y: card.y - size.height / 2, width: size.width,
          height: size.height))
    }
  }
  /// Frames all content in the area left free by floating controls.
  func fit(_ size: CGSize, sizes: [String: CGSize] = [:], bottomInset: Double = 150) {
    guard !document.cards.isEmpty else {
      viewport = BoardViewport()
      return
    }
    let content = bounds(sizes: sizes)
    let available = CGSize(
      width: max(120, size.width - 96), height: max(120, size.height - bottomInset - 56))
    let scale = min(
      1, max(0.25, min(available.width / content.width, available.height / content.height)))
    withAnimation(.easeOut(duration: 0.2)) {
      viewport = BoardViewport(
        x: -content.midX * scale, y: -content.midY * scale - (bottomInset - 28) / 2, zoom: scale)
    }
    scheduleSave()
  }

  // MARK: Cards

  /// A free spot near the centre of what the creator is currently looking at.
  private func openPosition() -> CGPoint {
    var point = CGPoint(x: -viewport.x / viewport.zoom, y: -viewport.y / viewport.zoom)
    var attempts = 0
    while attempts < 40,
      document.cards.contains(where: { abs($0.x - point.x) < 320 && abs($0.y - point.y) < 200 })
    {
      attempts += 1
      point.x += 340
      if attempts % 3 == 0 {
        point.x -= 340 * 3
        point.y += 220
      }
    }
    return point
  }
  func add(_ record: LoreRecord, at position: CGPoint? = nil) {
    if let card = document.cards.first(where: { $0.recordID == record.id }) {
      selection = [card.id]
      return
    }
    let point = position ?? openPosition()
    var card = CanvasCard(text: record.title, recordID: record.id)
    card.x = point.x
    card.y = point.y
    card.width = 300
    mutate { $0.cards.append(card) }
    selection = [card.id]
  }
  func create(title: String, body: String, kind: String, category: String) {
    studio.perform {
      let record = try studio.store.createRecord(
        worldID: worldID, title: title, body: body, kind: kind, category: category)
      try studio.reload()
      add(record)
    }
  }
  func move(_ ids: Set<String>, by delta: CGSize) {
    guard delta != .zero else { return }
    mutate { doc in
      for i in doc.cards.indices where ids.contains(doc.cards[i].id) {
        doc.cards[i].x += delta.width
        doc.cards[i].y += delta.height
      }
    }
  }
  func selectAll() { selection = Set(document.cards.map(\.id)) }
  func removeSelection() {
    let ids = selection
    guard !ids.isEmpty else { return }
    mutate { doc in
      doc.cards.removeAll { ids.contains($0.id) }
      doc.edges.removeAll { ids.contains($0.source) || ids.contains($0.target) }
    }
    selection = []
  }
  func group() {
    guard selection.count > 1 else { return }
    let id = UUID().uuidString
    mutate { doc in
      for i in doc.cards.indices where selection.contains(doc.cards[i].id) {
        doc.cards[i].group = id
      }
    }
  }
  func ungroup() {
    let groups = Set(document.cards.filter { selection.contains($0.id) }.compactMap(\.group))
    guard !groups.isEmpty else { return }
    mutate { doc in
      for i in doc.cards.indices where doc.cards[i].group.map(groups.contains) == true {
        doc.cards[i].group = nil
      }
    }
  }
  var selectionIsGrouped: Bool {
    document.cards.contains { selection.contains($0.id) && $0.group != nil }
  }
  /// Places the selection in one row, left to right in its current order.
  func align() { arrange(row: true, sizes: [:]) }
  func arrange(row: Bool, sizes: [String: CGSize]) {
    let cards = document.cards.filter { selection.contains($0.id) }.sorted {
      row ? $0.x < $1.x : $0.y < $1.y
    }
    guard cards.count > 1, let first = cards.first else { return }
    mutate { doc in
      var cursor = row ? first.x : first.y
      for (i, card) in cards.enumerated() {
        guard let index = doc.cards.firstIndex(where: { $0.id == card.id }) else { continue }
        let size = sizes[card.id] ?? Self.defaultCard
        if i > 0 {
          let previous = sizes[cards[i - 1].id] ?? Self.defaultCard
          cursor +=
            row ? (previous.width + size.width) / 2 + 40 : (previous.height + size.height) / 2 + 32
        }
        doc.cards[index].x = row ? cursor : first.x
        doc.cards[index].y = row ? first.y : cursor
      }
    }
  }
  /// Lays every card out on an even grid sized to the tallest card.
  func autoLayout(sizes: [String: CGSize] = [:]) {
    let count = document.cards.count
    guard count > 0 else { return }
    let columns = max(1, Int(Double(count).squareRoot().rounded(.up)))
    let rowHeight =
      (document.cards.map { sizes[$0.id]?.height ?? Self.defaultCard.height }.max() ?? 170) + 60
    mutate { doc in
      for i in doc.cards.indices {
        doc.cards[i].x = (Double(i % columns) - Double(columns - 1) / 2) * 380
        doc.cards[i].y = (Double(i / columns) - Double((count - 1) / columns) / 2) * rowHeight
      }
    }
  }
  func importImage(cardID: String? = nil) {
    studio.perform {
      guard let encoded = try pickImage(limit: 4_000_000) else { return }
      if let cardID {
        mutate { doc in
          if let i = doc.cards.firstIndex(where: { $0.id == cardID }) {
            doc.cards[i].image = encoded
          }
        }
      } else {
        let point = openPosition()
        var card = CanvasCard(text: "Image", image: encoded)
        card.width = 300
        card.x = point.x
        card.y = point.y
        mutate { $0.cards.append(card) }
        selection = [card.id]
      }
    }
  }
  func refreshRelations() {
    studio.perform { relationships = try studio.store.relations(worldID: worldID) }
  }
  /// Semantic relationships between records on this board, followed by board-only links.
  var edges: [DisplayEdge] {
    var result = relationships.compactMap { relation -> DisplayEdge? in
      guard let a = document.cards.first(where: { $0.recordID == relation.sourceID }),
        let b = document.cards.first(where: { $0.recordID == relation.targetID })
      else { return nil }
      return DisplayEdge(id: relation.id, source: a.id, target: b.id, label: relation.label)
    }
    result += document.edges.enumerated().compactMap { offset, edge in
      guard document.cards.contains(where: { $0.id == edge.source }),
        document.cards.contains(where: { $0.id == edge.target })
      else { return nil }
      return DisplayEdge(
        id: "local-\(offset)", source: edge.source, target: edge.target,
        label: edge.label ?? "linked", localIndex: offset)
    }
    return result
  }
}
