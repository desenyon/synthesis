import AppKit
import SwiftUI
import SynthesisCore

/// Canvas workspace: an Excalidraw board with Synthesis record cards and relationship arrows.
/// Free drawing, shapes, text, images and frames come from the engine; the bar, the sheets and
/// the optional companion conversation are native.
struct CuratedCanvas: View {
  enum Panel: String, Identifiable {
    case create, library, rename
    var id: String { rawValue }
  }
  @ObservedObject var studio: Studio
  @ObservedObject private var session: CanvasSession
  @State private var panel: Panel?
  @State private var formTitle = ""
  @State private var formBody = ""
  @State private var formCategory = "Characters"
  @State private var boardName = ""
  @State private var pickerQuery = ""
  @State private var edgeLabel = ""
  @State private var companionStart: Double?
  init(studio: Studio) {
    self.studio = studio
    session = studio.canvas()
  }
  private var assistantDocked: Bool { studio.mode == .assisted && studio.companionExpanded }
  private var composerVisible: Bool { studio.mode == .assisted && !studio.companionExpanded }

  var body: some View {
    GeometryReader { geo in
      // A narrow window has no room to dock: the companion takes the workspace instead.
      let takeover = assistantDocked && geo.size.width < 860
      HStack(spacing: 0) {
        if !takeover {
          VStack(spacing: 0) {
            bar
            board
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        if takeover {
          ConversationStudio(studio: studio, companion: true, docked: false)
        } else if assistantDocked {
          companionDivider
          ConversationStudio(studio: studio, companion: true)
            .frame(width: geo.size.width < 1000 ? 320 : studio.companionWidth)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
    }
    .onAppear {
      session.switchBoard(studio.canvasBoardID)
      studio.editorSave = nil
      studio.canvasUndo = { session.command($0 ? "undo" : "redo") }
      studio.canvasFit = { session.command("fit") }
      if let width = try? studio.store.preference("companion-width"), let value = Double(width) {
        studio.companionWidth = min(460, max(320, value))
      }
    }
    .onChange(of: studio.canvasBoardID) { _, id in if id != nil { session.switchBoard(id) } }
    .onChange(of: session.request) { _, request in
      guard let request else { return }
      session.request = nil
      switch request {
      case "library":
        pickerQuery = ""
        panel = .library
      case "entity": prepareCreate()
      case "image": session.addImage()
      case "export": session.exportImage()
      default: break
      }
    }
    .sheet(item: $panel) { item in
      switch item {
      case .create: createForm
      case .library: libraryPicker
      case .rename: renameForm
      }
    }
    .sheet(item: $session.connection) { connection in
      RelationEditor(
        t: studio.t, title: "Is this a relationship?", source: connection.source.title,
        target: connection.target.title, label: $edgeLabel,
        note:
          "Saving creates a draft relationship that also appears in Graph. Keeping it as an arrow changes nothing in your lore.",
        suggestions: relationSuggestions,
        save: { session.saveConnection(connection, label: edgeLabel) },
        cancel: { session.connection = nil }
      ).onAppear { edgeLabel = connection.label }
    }
  }
  private var relationSuggestions: [String] {
    Array(Set(((try? studio.store.relations(worldID: studio.worldID)) ?? []).map(\.label)))
      .sorted().prefix(6).map { $0 }
  }

  // MARK: Bar

  private var bar: some View {
    WorkspaceBar(studio: studio) {
      Image(systemName: Destination.canvas.icon).font(.system(size: 14))
        .foregroundStyle(studio.t.accent).accessibilityHidden(true)
      PlainMenu(flexible: true) {
        boardMenu
      } label: {
        HStack(spacing: 5) {
          Text(session.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
          Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            .foregroundStyle(studio.t.muted)
        }.padding(.horizontal, 6).frame(height: 28).hoverFill(studio.t)
      }.padding(.leading, -4).help("Switch, rename or archive boards")
      if let failure = session.failure {
        Label("Not saved", systemImage: "exclamationmark.triangle")
          .font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.warning).fixedSize()
          .help(failure)
      } else {
        Text("Saved").font(.system(size: 12)).foregroundStyle(studio.t.muted).fixedSize()
          .help("This board is saved on this device")
      }
    } trailing: {
      if studio.mode == .assisted, !session.selection.isEmpty {
        BarAction(
          title: session.selection.count == 1
            ? "Reference" : "Reference \(session.selection.count)",
          icon: "at", t: studio.t,
          help:
            "Mention the selected \(session.selection.count == 1 ? "card" : "cards") in the conversation"
        ) { withAnimation(.easeOut(duration: 0.18)) { studio.referenceCanvasSelection() } }
      }
      PlainMenu {
        Button("Entity…") { prepareCreate() }
        Button("From library…") {
          pickerQuery = ""
          panel = .library
        }
        Button("Image…") { session.addImage() }
        if let card = session.selection.first, session.selection.count == 1 {
          Divider()
          Button(
            session.selectionWithArt.contains(card)
              ? "Replace card artwork…" : "Artwork for selected card…"
          ) {
            session.chooseArtwork(for: card)
          }
          if session.selectionWithArt.contains(card) {
            Button("Remove card artwork") { session.setArtwork(nil, for: card) }
          }
        }
      } label: {
        Label("Add", systemImage: "plus").font(.system(size: 13, weight: .medium)).fixedSize()
          .padding(.horizontal, 10).frame(height: Metric.control)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(
            RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.hairline, lineWidth: 1))
      }.help("Add records or an image. Draw, write and connect with the tools on the canvas.")
      IconButton(icon: "viewfinder", label: "Fit everything in view", t: studio.t) {
        session.command("fit")
      }
      if studio.mode == .assisted {
        IconButton(
          icon: "sidebar.right",
          label: studio.companionExpanded ? "Hide companion" : "Open companion conversation",
          t: studio.t, active: studio.companionExpanded
        ) { withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded.toggle() } }
      }
    }
  }
  @ViewBuilder private var boardMenu: some View {
    let boards = (try? studio.store.boards(worldID: studio.worldID, kind: "canvas")) ?? []
    ForEach(boards) { item in
      Button {
        studio.canvasBoardID = item.id
        session.switchBoard(item.id)
      } label: {
        if item.id == session.boardID {
          Label(item.name, systemImage: "checkmark")
        } else {
          Text(item.name)
        }
      }
    }
    Divider()
    Button("New board") { newBoard() }
    Button("Rename…") {
      boardName = session.name
      panel = .rename
    }
    Button("Export as PNG…") { session.exportImage() }
    if session.hiddenCount > 0 {
      Button(
        "Show \(session.hiddenCount) hidden relationship\(session.hiddenCount == 1 ? "" : "s")"
      ) {
        session.showHiddenRelations()
      }
    }
    Button("Archive board") { archiveBoard() }.disabled(session.boardID == nil)
    let archived =
      (try? studio.store.boards(worldID: studio.worldID, kind: "canvas", archived: true)) ?? []
    if !archived.isEmpty {
      Menu("Archived boards") {
        ForEach(archived) { item in
          Button("Restore “\(item.name)”") {
            studio.perform {
              try studio.store.setBoardArchived(
                worldID: studio.worldID, id: item.id, archived: false)
              studio.canvasBoardID = item.id
              session.switchBoard(item.id)
            }
          }
        }
      }
    }
  }
  private func newBoard() {
    studio.perform {
      let existing = try studio.store.boards(worldID: studio.worldID, kind: "canvas").count
      let id = try studio.store.saveBoard(
        worldID: studio.worldID, name: "Untitled board \(existing + 1)", kind: "canvas",
        content: CanvasBoardContent.empty
      ).id
      studio.canvasBoardID = id
      session.switchBoard(id)
    }
  }
  private func archiveBoard() {
    guard let id = session.boardID else { return }
    let name = session.name
    Task {
      await session.flush()
      studio.perform {
        try studio.store.setBoardArchived(worldID: studio.worldID, id: id, archived: true)
        let remaining = try studio.store.boards(worldID: studio.worldID, kind: "canvas")
        let next =
          try remaining.first?.id
          ?? studio.store.saveBoard(
            worldID: studio.worldID, name: "Untitled board", kind: "canvas",
            content: CanvasBoardContent.empty
          ).id
        studio.canvasBoardID = next
        session.switchBoard(next)
        studio.show("Archived board “\(name)”", icon: "archivebox", actionTitle: "Undo") {
          studio.perform {
            try studio.store.setBoardArchived(worldID: studio.worldID, id: id, archived: false)
            studio.canvasBoardID = id
            session.switchBoard(id)
          }
        }
      }
    }
  }

  // MARK: Board

  private var board: some View {
    GeometryReader { geo in
      ZStack(alignment: .bottom) {
        // Transparent: the engine's web view is mounted beneath the workspace by the shell.
        Color.clear.background(
          GeometryReader { area in
            Color.clear.preference(key: CanvasFrameKey.self, value: area.frame(in: .named("shell")))
          })
        if !session.loaded && session.failure == nil {
          ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(studio.t.background)
        }
        if let failure = session.failure, !session.loaded {
          EmptyState(
            icon: "exclamationmark.triangle", title: "This board could not be opened",
            message: failure, t: studio.t
          ) { Button("New board") { newBoard() }.buttonStyle(QuietButton(t: studio.t)) }
          .frame(maxWidth: .infinity, maxHeight: .infinity).background(studio.t.background)
        }
        if composerVisible {
          UnifiedComposer(studio: studio, collapsed: true)
            .frame(width: min(440, geo.size.width - 40))
            // Clear of the engine's zoom and undo controls on narrower canvases.
            .padding(.bottom, geo.size.width < 1100 ? 64 : 12)
        }
      }
    }
  }
  /// A 9-point grab column with a hairline, so the divider is easy to hit and drag.
  private var companionDivider: some View {
    Color.clear.frame(width: 9).frame(maxHeight: .infinity)
      .overlay(Rectangle().fill(studio.t.hairline).frame(width: 1))
      .contentShape(Rectangle())
      .onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { value in
          if companionStart == nil { companionStart = studio.companionWidth }
          studio.companionWidth = max(
            320, min(460, (companionStart ?? 400) - value.translation.width))
        }.onEnded { _ in
          companionStart = nil
          studio.perform {
            try studio.store.setPreference("companion-width", value: String(studio.companionWidth))
          }
        }
      )
      .help("Drag to resize the companion").accessibilityLabel("Resize companion")
  }

  // MARK: Sheets

  private func closePanel() { panel = nil }
  private func prepareCreate() {
    formTitle = ""
    formBody = ""
    panel = .create
  }
  private var createForm: some View {
    SheetScaffold(
      title: "New entity", subtitle: "Saved as a draft in your library and placed on this board.",
      t: studio.t, close: closePanel
    ) {
      FormField(label: "Name", placeholder: "Name", text: $formTitle, t: studio.t)
      VStack(alignment: .leading, spacing: 6) {
        Text("Type").font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
        FlowLayout(spacing: 6) {
          ForEach(Vocabulary.categories, id: \.self) { type in
            FilterChip(title: type, selected: formCategory == type, t: studio.t) {
              formCategory = type
            }
          }
        }
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("Notes").font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
        TextEditor(text: $formBody).font(.system(size: 14)).scrollContentBackground(.hidden)
          .padding(8).frame(height: 120)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(
            RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.border, lineWidth: 1))
      }
    } footer: {
      Spacer()
      Button("Cancel", action: closePanel).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create draft") {
        studio.perform {
          let record = try studio.store.createRecord(
            worldID: studio.worldID, title: formTitle, body: formBody, kind: "entity",
            category: formCategory)
          try studio.reload()
          session.sync()
          session.add([record])
          panel = nil
        }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
  private var renameForm: some View {
    SheetScaffold(title: "Rename board", t: studio.t, width: 380, close: closePanel) {
      FormField(placeholder: "Board name", text: $boardName, t: studio.t) {
        session.rename(boardName)
        panel = nil
      }
    } footer: {
      Spacer()
      Button("Cancel", action: closePanel).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Rename") {
        session.rename(boardName)
        panel = nil
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(boardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
  private var libraryPicker: some View {
    let matches = studio.records.filter {
      pickerQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(pickerQuery)
        || $0.category.localizedCaseInsensitiveContains(pickerQuery)
    }
    return SheetScaffold(
      title: "Add from library", subtitle: "Cards stay linked to their records.", t: studio.t,
      close: closePanel
    ) {
      SearchField(text: $pickerQuery, placeholder: "Filter records", t: studio.t)
      ScrollView {
        VStack(spacing: 1) {
          ForEach(matches) { record in
            Button {
              session.add([record])
            } label: {
              HStack(spacing: 10) {
                CategoryTile(record: record, t: studio.t, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                  Text(record.title).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                  Text(
                    record.category.isEmpty ? Vocabulary.kindLabel(record.kind) : record.category
                  )
                  .font(.system(size: 11.5)).foregroundStyle(studio.t.muted)
                }
                Spacer()
                Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                  .foregroundStyle(studio.t.secondary)
              }.padding(.horizontal, 8).frame(height: 44).hoverFill(studio.t)
            }.buttonStyle(.plain).help("Add to board, or select it if it is already there")
          }
          if matches.isEmpty {
            Text(studio.records.isEmpty ? "Your library is empty." : "No records match.")
              .font(.system(size: 13)).foregroundStyle(studio.t.secondary).padding(.vertical, 30)
          }
        }
      }.frame(height: 300)
    } footer: {
      Spacer()
      Button("Done", action: closePanel).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
  }
}

/// Label editor shared by Canvas and Graph for relationships.
struct RelationEditor: View {
  let t: Theme
  let title: String
  let source: String
  let target: String
  @Binding var label: String
  let note: String
  var suggestions: [String] = []
  var removable = false
  var save: () -> Void
  var remove: () -> Void = {}
  var cancel: () -> Void
  var body: some View {
    SheetScaffold(title: title, t: t, close: cancel) {
      HStack(spacing: 8) {
        endpoint(source)
        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
          .foregroundStyle(t.muted)
        endpoint(target)
      }
      FormField(
        label: "How are they connected?", placeholder: "guided by, rules, born in…", text: $label,
        t: t, submit: { if valid { save() } })
      if !suggestions.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(suggestions, id: \.self) { value in
              FilterChip(title: value, selected: label == value, t: t) { label = value }
            }
          }
        }.scrollIndicators(.never)
      }
      Text(note).font(.system(size: 12.5)).foregroundStyle(t.muted).lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    } footer: {
      if removable {
        Button("Remove", action: remove).buttonStyle(QuietButton(t: t, role: .danger))
      }
      Spacer()
      Button(removable ? "Cancel" : "Keep as an arrow", action: cancel)
        .buttonStyle(QuietButton(t: t, role: .ghost))
      Button("Save", action: save).buttonStyle(QuietButton(t: t, primary: true))
        .keyboardShortcut(.defaultAction).disabled(!valid)
    }
  }
  private var valid: Bool { !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  private func endpoint(_ name: String) -> some View {
    Text(name).font(.system(size: 13, weight: .medium)).lineLimit(1)
      .padding(.horizontal, 10).frame(height: 28)
      .background(t.surface, in: RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(t.hairline, lineWidth: 1))
  }
}
