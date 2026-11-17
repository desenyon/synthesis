import AppKit
import SwiftUI
import SynthesisCore

enum EditorPlacement { case main, beside }

extension Studio {
  /// The second pane is an address in this world, never an independent lore copy.
  func syncSplitWorkspace() throws {
    if splitWorldID != worldID {
      splitEditorSave = nil
      splitRecord = nil
      splitWorldID = worldID
      if let id = try store.preference("split-record:\(worldID)") {
        splitRecord = records.first { $0.id == id && $0.id != selectedRecord?.id }
      }
    } else if let record = splitRecord {
      splitRecord = records.first { $0.id == record.id }
      if splitRecord == nil { splitEditorSave = nil }
    }
    if let record = splitRecord { retainDocument(record) }
  }
  func setSplitRecord(_ record: LoreRecord?) throws {
    try store.setPreference("split-record:\(worldID)", value: record?.id ?? "")
    if splitRecord?.id != record?.id { splitEditorSave = nil }
    splitRecord = record
    splitWorldID = worldID
    if let record { retainDocument(record) }
  }
  func openBeside(_ record: LoreRecord) {
    withNavigation {
      guard record.worldID == worldID, flushEditor() else { return }
      perform {
        guard try !store.isArchived(worldID: worldID, recordID: record.id) else {
          throw SynthesisError.notFound
        }
        let fresh = try store.record(worldID: worldID, id: record.id)
        try setSplitRecord(fresh)
        if selectedRecord?.id == fresh.id {
          selectedRecord = nil
          editorSave = nil
        }
        activeEditorPlacement = .beside
        workspaceInspector = false
        if selectedRecord != nil { inspector = false }
        splitInspector = false
        sheet = nil
      }
    }
  }
  func closeSplitWorkspace() {
    withNavigation {
      guard flushEditor() else { return }
      perform {
        try setSplitRecord(nil)
        activeEditorPlacement = .main
      }
    }
  }
  /// Move a profile to the main pane; if two records are open, exchange their addresses.
  func swapSplitWorkspace() {
    withNavigation {
      guard let beside = splitRecord, flushEditor() else { return }
      perform {
        let previous = selectedRecord
        let fresh = try store.record(worldID: worldID, id: beside.id)
        guard try !store.isArchived(worldID: worldID, recordID: beside.id) else {
          throw SynthesisError.notFound
        }
        try setSplitRecord(previous)
        editorSave = nil
        selectedRecord = fresh
        activeEditorPlacement = .main
      }
    }
  }
  var agentWorkspaceName: String {
    let base =
      selectedRecord == nil
      ? (libraryCategory ?? destination.rawValue) : "Editor in \(destination.rawValue)"
    return splitRecord.map { "\(base), beside \($0.title)" } ?? base
  }
  public var hasVisibleDocument: Bool { selectedRecord != nil || splitRecord != nil }
  var focusedEditorPlacement: EditorPlacement {
    if let responder = NSApp?.keyWindow?.firstResponder as? NSView {
      if let id = splitRecord?.id, let scroll = documentEditors[id]?.scrollView,
        responder.isDescendant(of: scroll)
      {
        return .beside
      }
      if let id = selectedRecord?.id, let scroll = documentEditors[id]?.scrollView,
        responder.isDescendant(of: scroll)
      {
        return .main
      }
    }
    return activeEditorPlacement
  }
  public func toggleActiveInspector() {
    if focusMode {
      focusMode = false
      if focusedEditorPlacement == .beside && splitRecord != nil && splitInspector { return }
      if focusedEditorPlacement != .beside && selectedRecord != nil && inspector { return }
      if selectedRecord == nil && splitRecord == nil && workspaceInspector { return }
    }
    if focusedEditorPlacement == .beside && splitRecord != nil {
      splitInspector.toggle()
    } else if selectedRecord != nil {
      toggleInspector()
    } else {
      toggleWorkspaceInspector()
    }
  }
  var splitUsesSharedComposer: Bool {
    splitRecord != nil
      && (selectedRecord != nil || ![.chat, .settings, .worlds].contains(destination))
  }
  static func splitsHorizontally(available: Double) -> Bool { available >= 1040 }
  func primaryContentWidth(windowWidth: Double) -> Double {
    let sidebar = visibleSidebarWidth(windowWidth: windowWidth)
    let available = windowWidth - sidebar
    return splitRecord != nil && Self.splitsHorizontally(available: available)
      ? available - splitDisplayWidth(available: available) : available
  }
  func splitDisplayWidth(available: Double) -> Double {
    min(splitWidth, max(380, available - 620))
  }
}

/// Both editors retain their identity when the available width changes. Narrow windows stack
/// the panes instead of overlaying one workspace or squeezing the writing to an unreadable width.
struct SplitWorkspace<Primary: View>: View {
  @ObservedObject var studio: Studio
  @ViewBuilder var primary: () -> Primary
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    GeometryReader { geo in
      let horizontal = Studio.splitsHorizontally(available: geo.size.width)
      let layout =
        horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
      layout {
        primary().frame(maxWidth: .infinity, maxHeight: .infinity)
          .overlay {
            if studio.destination != .canvas || studio.selectedRecord != nil {
              RecordDropSurface(studio: studio, title: "Open here", icon: "doc.text") { _ in .main }
                .padding(.top, Metric.bar).padding(8)
            }
          }
          .overlay(alignment: horizontal ? .trailing : .bottom) {
            if studio.splitRecord == nil && studio.recordDrag != nil {
              RecordDropSurface(studio: studio, title: "Open beside", icon: "sidebar.right") {
                _ in .beside
              }
              .frame(width: horizontal ? 220 : nil, height: horizontal ? nil : 128)
              .padding(.top, horizontal ? Metric.bar : 0).padding(8)
            }
          }
        if let record = studio.splitRecord {
          EditorScreen(studio: studio, record: record, placement: .beside)
            .id(record.id)
            .frame(width: horizontal ? studio.splitDisplayWidth(available: geo.size.width) : nil)
            .frame(height: horizontal ? nil : max(260, geo.size.height * 0.48))
            .background(studio.t.background)
            .overlay {
              RecordDropSurface(studio: studio, title: "Open in second pane", icon: "doc.text") {
                _ in .beside
              }.padding(.top, Metric.bar).padding(8)
            }
            .overlay(alignment: horizontal ? .leading : .top) {
              if horizontal {
                PanelResizeHandle(
                  studio: studio, panel: .split,
                  displayedWidth: studio.splitDisplayWidth(available: geo.size.width),
                  maximum: max(380, geo.size.width - 620))
              } else {
                studio.t.hairline.frame(height: 1)
              }
            }
            .transition(.opacity)
        }
      }.animation(reduceMotion ? nil : Motion.panelAnimation, value: studio.splitRecord?.id)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !studio.focusMode && studio.splitUsesSharedComposer && studio.mode == .assisted
        && !studio.companionExpanded
      {
        UnifiedComposer(studio: studio, companion: true, collapsed: true)
          .frame(maxWidth: 620).padding(.horizontal, 20).padding(.vertical, 12)
          .frame(maxWidth: .infinity).background(studio.t.background)
          .opacity(studio.recordDrag == nil ? 1 : 0)
          .allowsHitTesting(studio.recordDrag == nil)
          .accessibilityHidden(studio.recordDrag != nil)
      }
    }
  }
}

struct SplitRecordAction: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var body: some View {
    Button("Open beside workspace") { studio.openBeside(record) }
  }
}

struct SplitRecordPicker: View {
  @ObservedObject var studio: Studio
  @State private var query = ""
  @State private var found: [LoreRecord] = []
  @State private var failure: String?
  private func close() { studio.sheet = nil }
  var body: some View {
    SheetScaffold(
      title: studio.splitRecord == nil
        ? "Open beside your workspace" : "Replace the second document",
      subtitle: studio.world?.name ?? "This universe", t: studio.t, width: 560, close: close
    ) {
      SearchField(text: $query, placeholder: "Find a character, place or document", t: studio.t)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 4) {
          if let failure {
            Text(failure).font(.studio(.label)).foregroundStyle(studio.t.warning)
          } else if found.isEmpty {
            Text("No matching records in this universe.").font(.studio(.label))
              .foregroundStyle(studio.t.secondary).padding(.vertical, 20)
          }
          ForEach(found) { record in
            Button {
              studio.openBeside(record)
            } label: {
              HStack(spacing: 12) {
                StudioIcon(recordIcon(record), size: 17).foregroundStyle(studio.t.secondary)
                VStack(alignment: .leading, spacing: 3) {
                  Text(record.title).font(.studio(.control)).lineLimit(1)
                  Text(Vocabulary.displayCategory(record.category)).font(.studio(.caption))
                    .foregroundStyle(studio.t.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                StudioIcon("chevron.right", size: 12).foregroundStyle(studio.t.muted)
              }.padding(10).contentShape(Rectangle()).hoverFill(studio.t)
            }.buttonStyle(.plain).help(record.title)
          }
        }
      }.frame(height: 260)
      Text(
        "Both panes use the same saved lore. Moving a document here keeps the current workspace available."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      .fixedSize(horizontal: false, vertical: true)
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t))
    }
    .onAppear { search() }
    .onChange(of: query) { _, _ in search() }
    .onChange(of: studio.worldID) { _, _ in
      query = ""
      search()
    }
  }
  private func search() {
    do {
      found =
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? Array(studio.topLevelRecords.prefix(80))
        : Array(try studio.store.search(worldID: studio.worldID, query: query).prefix(80))
      failure = nil
    } catch { failure = error.localizedDescription }
  }
}
