import SwiftUI
import SynthesisCore

/// Device-local addresses only. Writing and canon stay in revisioned world records.
struct OpenDocuments: Codable, Equatable {
  var version = 1
  var open: [String] = []
  var pinned: [String] = []
  var recent: [String] = []

  func validated(records: [LoreRecord]) throws -> OpenDocuments {
    guard version == 1 else {
      throw SynthesisError.invalid("This document session needs a newer Synthesis.")
    }
    let valid = Set(records.map(\.id))
    func unique(_ ids: [String]) -> [String] {
      var seen = Set<String>()
      return ids.filter { valid.contains($0) && seen.insert($0).inserted }
    }
    let opened = unique(open)
    return OpenDocuments(
      open: opened, pinned: unique(pinned).filter(opened.contains),
      recent: Array(unique(recent).prefix(50)))
  }
}

extension Studio {
  var openDocuments: [LoreRecord] {
    let ids =
      documentSession.pinned + documentSession.open.filter { !documentSession.pinned.contains($0) }
    let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    return ids.compactMap { byID[$0] }
  }
  var recentDocuments: [LoreRecord] {
    let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    return documentSession.recent.compactMap { byID[$0] }
  }
  public var canReopenDocument: Bool {
    recentDocuments.contains { !documentSession.open.contains($0.id) }
  }
  public func reopenDocument() {
    if let record = recentDocuments.first(where: { !documentSession.open.contains($0.id) }) {
      openRecord(record)
    }
  }
  public func cycleDocument(backward: Bool = false) {
    let documents = openDocuments
    guard !documents.isEmpty else { return }
    let current = documents.firstIndex { $0.id == selectedRecord?.id } ?? (backward ? 0 : -1)
    let next = (current + (backward ? -1 : 1) + documents.count) % documents.count
    openRecord(documents[next])
  }
  public func closeActiveDocument() {
    if let id = selectedRecord?.id { closeDocument(id) }
  }
  func editorHandle(for record: LoreRecord) -> EditorHandle {
    if let handle = documentEditors[record.id] { return handle }
    let handle = EditorHandle()
    documentEditors[record.id] = handle
    return handle
  }
  func syncDocumentSession() throws {
    if documentWorldID != worldID {
      let raw = try store.preference("open-documents:\(worldID)")
      do {
        let restored =
          try raw.map { try JSONDecoder().decode(OpenDocuments.self, from: Data($0.utf8)) }
          ?? OpenDocuments()
        documentSession = try restored.validated(records: records)
      } catch {
        // Preferences cannot prevent access to a world. Preserve unreadable data before
        // allowing later explicit tab operations to write a fresh session.
        if let raw { try store.setPreference("open-documents-backup:\(worldID)", value: raw) }
        documentSession = OpenDocuments()
        self.error =
          "The saved document tabs could not be read. A copy was preserved; your documents are unchanged."
      }
      documentWorldID = worldID
      documentEditors.removeAll()
    } else {
      let fresh = try documentSession.validated(records: records)
      if fresh != documentSession { try persistDocuments(fresh) }
      let live = Set(documentSession.open)
      documentEditors = documentEditors.filter { live.contains($0.key) }
    }
  }
  func retainDocument(_ record: LoreRecord) {
    guard record.worldID == worldID, records.contains(where: { $0.id == record.id }) else { return }
    perform {
      if documentWorldID != worldID { try syncDocumentSession() }
      var next = documentSession
      if !next.open.contains(record.id) { next.open.append(record.id) }
      next.recent.removeAll { $0 == record.id }
      next.recent.insert(record.id, at: 0)
      next.recent = Array(next.recent.prefix(50))
      try persistDocuments(next)
    }
  }
  private func persistDocuments(_ next: OpenDocuments) throws {
    let data = try JSONEncoder().encode(next)
    try store.setPreference(
      "open-documents:\(worldID)", value: String(decoding: data, as: UTF8.self))
    documentSession = next
  }
  func toggleDocumentPin(_ id: String) {
    guard documentSession.open.contains(id) else { return }
    perform {
      var next = documentSession
      if next.pinned.contains(id) {
        next.pinned.removeAll { $0 == id }
      } else {
        next.pinned.append(id)
      }
      try persistDocuments(next)
    }
  }
  func closeDocument(_ id: String) {
    guard documentSession.open.contains(id) else { return }
    let active = selectedRecord?.id == id
    guard !active || flushEditor() else { return }
    let old = openDocuments.map(\.id)
    let index = old.firstIndex(of: id) ?? 0
    withNavigation {
      perform {
        var next = documentSession
        next.open.removeAll { $0 == id }
        next.pinned.removeAll { $0 == id }
        next.recent.removeAll { $0 == id }
        next.recent.insert(id, at: 0)
        next.recent = Array(next.recent.prefix(50))
        try persistDocuments(next)
        documentEditors.removeValue(forKey: id)
        if active {
          editorSave = nil
          selectedRecord = nil
          let remaining = openDocuments
          if !remaining.isEmpty { openRecord(remaining[min(index, remaining.count - 1)]) }
        }
      }
    }
  }
  func closeOtherDocuments(keeping id: String) {
    guard documentSession.open.contains(id), flushEditor() else { return }
    perform {
      var next = documentSession
      next.open = next.open.filter { $0 == id || next.pinned.contains($0) }
      try persistDocuments(next)
      documentEditors = documentEditors.filter { next.open.contains($0.key) }
      if let record = records.first(where: { $0.id == id }) { openRecord(record) }
    }
  }
}

struct DocumentHistoryMenu: View {
  @ObservedObject var studio: Studio
  var body: some View {
    IconMenu(icon: "clock.arrow.circlepath", label: "Open and recent documents", t: studio.t) {
      if !studio.openDocuments.isEmpty {
        MenuSection("Open documents") {
          ForEach(studio.openDocuments) { record in
            Button(record.title) { studio.openRecord(record) }
          }
        }
      }
      let closed = studio.recentDocuments.filter { !studio.documentSession.open.contains($0.id) }
      if !closed.isEmpty {
        MenuSection("Recently closed") {
          ForEach(closed.prefix(15)) { record in
            Button(record.title) { studio.openRecord(record) }
          }
        }
      }
      Button("Reopen closed document · ⇧⌘T") { studio.reopenDocument() }
        .disabled(!studio.canReopenDocument)
      Button("Find a document…") { studio.palette = true }
    }
  }
}

struct DocumentTabBar: View {
  @ObservedObject var studio: Studio
  var body: some View {
    HStack(spacing: 4) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 4) {
            ForEach(studio.openDocuments) { record in tab(record).id(record.id) }
          }.padding(.horizontal, 12)
        }
        .onAppear { if let id = studio.selectedRecord?.id { proxy.scrollTo(id) } }
        .onChange(of: studio.selectedRecord?.id) { _, id in
          if let id { proxy.scrollTo(id) }
        }
      }
      DocumentHistoryMenu(studio: studio).padding(.trailing, 10)
    }.frame(height: 40).background(studio.t.background)
      .overlay(alignment: .bottom) { Rectangle().fill(studio.t.hairline).frame(height: 1) }
      .accessibilityElement(children: .contain).accessibilityLabel("Open documents")
  }
  private func tab(_ record: LoreRecord) -> some View {
    let active = studio.selectedRecord?.id == record.id
    let pinned = studio.documentSession.pinned.contains(record.id)
    return HStack(spacing: 2) {
      Button {
        studio.openRecord(record)
      } label: {
        HStack(spacing: 6) {
          StudioIcon(pinned ? "pin" : recordIcon(record), size: 13).foregroundStyle(
            studio.t.secondary)
          Text(record.title).font(.studio(.captionStrong)).lineLimit(1)
        }.frame(minWidth: 60, maxWidth: 170, alignment: .leading)
          .padding(.leading, 10).padding(.trailing, pinned ? 10 : 2).frame(height: 30)
          .contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
      if !pinned {
        IconButton(icon: "xmark", label: "Close \(record.title)", t: studio.t, size: 22) {
          studio.closeDocument(record.id)
        }.padding(.trailing, 4)
      }
    }.background(
      active ? studio.t.secondarySurface : Color.clear, in: RoundedRectangle(cornerRadius: 7)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 7).stroke(active ? studio.t.hairline : .clear, lineWidth: 1)
    )
    .hoverFill(studio.t, radius: 7).help(record.title + (pinned ? " · Pinned" : ""))
    .contextMenu {
      Button(pinned ? "Unpin document" : "Pin document") { studio.toggleDocumentPin(record.id) }
      Button("Close document") { studio.closeDocument(record.id) }
      Button("Close other unpinned documents") { studio.closeOtherDocuments(keeping: record.id) }
    }
  }
}
