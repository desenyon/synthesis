import AppKit
import SwiftFlow
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

struct BoardViewport: Codable, Equatable {
  var x = 0.0
  var y = 0.0
  var zoom = 1.0
}
@MainActor final class BoardController: ObservableObject {
  let studio: Studio
  let worldID: String
  @Published var document = CanvasDocument()
  @Published var boardID: String?
  @Published var name = "Creative board"
  @Published var selection: Set<String> = []
  @Published var relationships: [Relation] = []
  @Published var viewport = BoardViewport()
  @Published var loaded = false
  @Published var failure: String?
  @Published var past: [CanvasDocument] = []
  @Published var future: [CanvasDocument] = []
  private var saveTask: Task<Void, Never>?
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
    past.append(document)
    if past.count > 60 { past.removeFirst() }
    future = []
    change(&document)
    save()
  }
  func step(back: Bool) {
    if back, let next = past.popLast() {
      future.append(document)
      document = next
    } else if !back, let next = future.popLast() {
      past.append(document)
      document = next
    }
    save()
  }
  func moveViewport(_ delta: CGSize) {
    viewport.x += delta.width
    viewport.y += delta.height
    scheduleSave()
  }
  func zoom(_ delta: Double) {
    viewport.zoom = min(1.8, max(0.35, viewport.zoom + delta))
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
  func fit(_ size: CGSize) {
    guard !document.cards.isEmpty else {
      viewport = BoardViewport()
      return
    }
    let left = document.cards.map(\.x).min()! - 160
    let right = document.cards.map(\.x).max()! + 160
    let top = document.cards.map(\.y).min()! - 145
    let bottom = document.cards.map(\.y).max()! + 145
    let scale = min(
      1,
      max(
        0.35,
        min((size.width - 100) / max(1, right - left), (size.height - 170) / max(1, bottom - top))))
    withAnimation(.easeOut(duration: 0.2)) {
      viewport = BoardViewport(
        x: -(left + right) / 2 * scale, y: -(top + bottom) / 2 * scale - 25, zoom: scale)
    }
    scheduleSave()
  }
  func add(_ record: LoreRecord) {
    if let card = document.cards.first(where: { $0.recordID == record.id }) {
      selection = [card.id]
      return
    }
    let i = document.cards.count
    var card = CanvasCard(text: record.title, recordID: record.id)
    card.x = Double(i % 2) * 380 - 190
    card.y = Double(i / 2) * 320 - 120
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
  func removeSelection() {
    let ids = selection
    mutate { doc in
      doc.cards.removeAll { ids.contains($0.id) }
      doc.edges.removeAll { ids.contains($0.source) || ids.contains($0.target) }
    }
    selection = []
  }
  func group() {
    let id = UUID().uuidString
    mutate { doc in
      for i in doc.cards.indices where selection.contains(doc.cards[i].id) {
        doc.cards[i].group = id
      }
    }
  }
  func align() {
    let cards = document.cards.filter { selection.contains($0.id) }.sorted { $0.x < $1.x }
    guard let first = cards.first else { return }
    mutate { doc in
      for (i, card) in cards.enumerated() {
        if let index = doc.cards.firstIndex(where: { $0.id == card.id }) {
          doc.cards[index].x = first.x + Double(i) * 340
          doc.cards[index].y = first.y
        }
      }
    }
  }
  func importImage(cardID: String? = nil) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    studio.perform {
      let data = try Data(contentsOf: url)
      guard data.count < 4_000_000, NSImage(data: data) != nil else {
        throw SynthesisError.invalid("Choose an image smaller than 4 MB.")
      }
      if let cardID {
        mutate { doc in
          if let i = doc.cards.firstIndex(where: { $0.id == cardID }) {
            doc.cards[i].image = data.base64EncodedString()
          }
        }
      } else {
        var card = CanvasCard(
          text: url.deletingPathExtension().lastPathComponent, image: data.base64EncodedString())
        card.width = 300
        mutate { $0.cards.append(card) }
        selection = [card.id]
      }
    }
  }
  func refreshRelations() {
    studio.perform { relationships = try studio.store.relations(worldID: worldID) }
  }
  func autoLayout() {
    let nodes = document.cards.map { card in
      Node(
        id: card.id, position: XYPosition(x: card.x, y: card.y), data: card.id,
        width: 300, height: 320)
    }
    var edges = document.edges.enumerated().map { index, edge in
      FlowEdge<EmptyEdgeData>(id: "local-\(index)", source: edge.source, target: edge.target)
    }
    for relation in relationships {
      if let source = document.cards.first(where: { $0.recordID == relation.sourceID }),
        let target = document.cards.first(where: { $0.recordID == relation.targetID })
      {
        edges.append(FlowEdge(id: relation.id, source: source.id, target: target.id))
      }
    }
    let arranged = GraphEngine.arranged(
      nodes, edges: edges, cardSize: CGSize(width: 300, height: 320))
    let positions = Dictionary(uniqueKeysWithValues: arranged.map { ($0.id, $0.position) })
    mutate { doc in
      for i in doc.cards.indices {
        if let position = positions[doc.cards[i].id] {
          doc.cards[i].x = position.x + 150
          doc.cards[i].y = position.y + 160
        }
      }
    }
  }
}
