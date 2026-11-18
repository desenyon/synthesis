import AppKit
import SwiftUI
import SynthesisCore

/// Canvas workspace: an Excalidraw board with Synthesis record cards and relationship arrows.
/// Free drawing, shapes, text, images and frames come from the engine; the bar, the sheets and
/// the optional companion conversation are native.
struct CuratedCanvas: View {
  enum Panel: String, Identifiable {
    case create, library, rename, artwork
    var id: String { rawValue }
  }
  @ObservedObject var studio: Studio
  @ObservedObject private var session: CanvasSession
  @State private var panel: Panel?
  @State private var formTitle = ""
  @State private var formKind = "entity"
  @State private var formBody = ""
  @State private var formCategory = "Characters"
  @State private var boardName = ""
  @State private var pickerQuery = ""
  @State private var showReferencePicker = false
  @State private var placingReference = false
  init(studio: Studio) {
    self.studio = studio
    session = studio.canvas()
  }
  private var assistantDocked: Bool {
    !studio.focusMode && studio.mode == .assisted && studio.companionExpanded
  }
  private var composerVisible: Bool {
    !studio.focusMode && studio.mode == .assisted && !studio.companionExpanded
      && !studio.splitUsesSharedComposer
  }

  var body: some View {
    GeometryReader { geo in
      // A narrow window has no room to dock: the companion takes the workspace instead.
      let takeover = assistantDocked && geo.size.width < 860
      let companionWidth =
        assistantDocked && !takeover ? studio.companionDisplayWidth(available: geo.size.width) : 0
      let dividerWidth = companionWidth > 0 ? PanelResizeHandle.width : 0
      let boardWidth = max(1, geo.size.width - companionWidth - dividerWidth)
      HStack(spacing: 0) {
        if !takeover {
          VStack(spacing: 0) {
            bar(tight: boardWidth < 750)
            board
          }.frame(width: boardWidth).frame(maxHeight: .infinity)
        }
        if takeover {
          ConversationStudio(studio: studio, companion: true, docked: false)
        } else if assistantDocked {
          PanelResizeHandle(
            studio: studio, panel: .companion,
            displayedWidth: companionWidth,
            maximum: max(320, geo.size.width - 520))
          ConversationStudio(studio: studio, companion: true)
            .frame(width: companionWidth)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
    }
    .onAppear {
      if studio.captureHint == "sheet-artwork" { panel = .artwork }
      showReferencePicker = CanvasReferencePicker.captureStates.contains(studio.captureHint)
      session.switchBoard(studio.canvasBoardID)
      studio.editorSave = nil
      studio.canvasUndo = { session.command($0 ? "undo" : "redo") }
      studio.canvasFit = { session.command("fit") }
    }
    .onChange(of: studio.captureNonce) { _, _ in
      if studio.captureHint == "sheet-artwork" { panel = .artwork }
    }
    .onChange(of: studio.mode) { _, _ in session.updateFitInsets() }
    .onChange(of: studio.focusMode) { _, _ in session.updateFitInsets() }
    .onChange(of: studio.companionExpanded) { _, _ in session.updateFitInsets() }
    .onChange(of: studio.splitRecord?.id) { _, _ in session.updateFitInsets() }
    .onPreferenceChange(CanvasComposerHeightKey.self) {
      session.updateFitInsets(composerHeight: $0)
    }
    .onChange(of: studio.canvasBoardID) { _, id in if id != nil { session.switchBoard(id) } }
    .onChange(of: session.request) { _, request in
      guard let request else { return }
      session.request = nil
      switch request {
      case "library":
        pickerQuery = ""
        panel = .library
      case "entity":
        formKind = "entity"
        prepareCreate()
      case "note":
        formKind = "capture"
        prepareCreate()
      case "image": session.addImage()
      case "illustration": panel = .artwork
      case "export": session.exportImage()
      case "reference":
        if studio.mode == .assisted { studio.referenceCanvasSelection() }
      case "artwork":
        if let id = session.selection.first { session.chooseArtwork(for: id) }
      default: break
      }
    }
    .studioSheet(item: $panel) { item in
      switch item {
      case .create: createForm
      case .library: libraryPicker
      case .rename: renameForm
      case .artwork:
        ArtworkPicker(
          t: studio.t, studio: studio,
          select: { data in
            if let id = session.selection.first, session.selection.count == 1 {
              session.setArtwork(data.base64EncodedString(), for: id)
            } else {
              session.addImage(data.base64EncodedString())
            }
            panel = nil
          }, close: closePanel)
      }
    }
    .studioSheet(item: $session.connection) { connection in
      RelationEditor(
        t: studio.t, title: "Is this a relationship?", source: connection.source.title,
        target: connection.target.title, label: connection.label,
        records: studio.records.filter { $0.worldID == connection.source.worldID },
        note:
          "Saving creates a draft relationship that also appears in Graph. Keeping it as an arrow changes nothing in your lore.",
        suggestions: relationSuggestions,
        save: { label, attributes in
          session.saveConnection(connection, label: label, attributes: attributes)
        },
        cancel: { session.connection = nil }
      )
    }
    .studioSheet(item: $session.editingRelation) { target in
      let relation = target.relation
      RelationEditor(
        t: studio.t, title: "World relationship",
        source: studio.records.first {
          $0.worldID == target.worldID && $0.id == relation.sourceID
        }?.title ?? "Unavailable",
        target: studio.records.first {
          $0.worldID == target.worldID && $0.id == relation.targetID
        }?.title ?? "Unavailable",
        label: relation.label, attributes: relation.attributes,
        records: studio.records.filter { $0.worldID == target.worldID },
        note: relation.state == "canon"
          ? "This relationship is accepted canon."
          : "This draft relationship is shared by Graph and Canvas.",
        suggestions: relationSuggestions, editable: relation.state != "canon", removable: true,
        hide: {
          guard target.worldID == studio.worldID, session.editingRelation?.id == target.id else {
            return
          }
          session.hideRelationship(relation.id)
          session.editingRelation = nil
        },
        save: { label, attributes in
          if studio.saveRelationshipEdit(target, label: label, attributes: attributes) {
            session.sync()
            session.editingRelation = nil
          }
        },
        remove: {
          if studio.archiveRelationship(target) {
            session.sync()
            session.editingRelation = nil
          }
        }, cancel: { session.editingRelation = nil }
      )
    }
  }
  private var relationSuggestions: [String] {
    Array(Set(((try? studio.store.relations(worldID: studio.worldID)) ?? []).map(\.label)))
      .sorted().prefix(6).map { $0 }
  }

  // MARK: Bar

  private func bar(tight: Bool) -> some View {
    WorkspaceBar(studio: studio) {
      if let reference = session.boardReference {
        SpatialReferenceHandle(
          studio: studio, reference: reference, title: session.name, icon: "link", label: "Board")
      } else {
        StudioIcon(Destination.canvas.icon, size: 14)
          .foregroundStyle(studio.t.accent).accessibilityHidden(true)
      }
      PlainMenu(flexible: true) {
        boardMenu
      } label: {
        HStack(spacing: 5) {
          Text(session.name).font(.studio(size: 15, weight: .semibold)).lineLimit(1)
          StudioIcon("chevron.down", size: 9)
            .foregroundStyle(studio.t.muted)
        }.padding(.horizontal, 6).frame(height: 28).hoverFill(studio.t)
      }.padding(.leading, -4).layoutPriority(1).help("Switch, rename or archive boards")
      if let failure = session.failure {
        StudioLabel("Not saved", icon: "exclamationmark.triangle")
          .font(.studio(.captionStrong)).foregroundStyle(studio.t.warning).fixedSize()
          .help(failure)
      } else if !tight {
        Text("Saved").font(.studio(.caption)).foregroundStyle(studio.t.muted).fixedSize()
          .help("This board is saved on this device")
      }
    } trailing: {
      if let reference = session.selectedImageReference {
        SpatialReferenceHandle(
          studio: studio, reference: reference, title: "Image · \(session.name)",
          icon: "photo", label: "Image")
      }
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
        Button("Reference from world…") { showReferencePicker.toggle() }
          .disabled(session.dropSessionID == nil)
        Button("Image…") { session.addImage() }
        Button("Sample illustrations…") { panel = .artwork }
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
        Group {
          if tight {
            StudioIcon("plus", size: 14).accessibilityLabel("Add to board")
          } else {
            StudioLabel("Add", icon: "plus")
          }
        }.font(.studio(.label)).fixedSize()
          .padding(.horizontal, 10).frame(height: Metric.control)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(
            RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.hairline, lineWidth: 1))
      }.help("Add records, images or world references to the canvas.")
      if !tight {
        IconButton(icon: "viewfinder", label: "Fit everything in view", t: studio.t) {
          session.command("fit")
        }
      }
      if studio.mode == .assisted {
        IconButton(
          icon: "sidebar.right",
          label: studio.companionExpanded ? "Hide companion" : "Open companion conversation",
          t: studio.t, active: studio.companionExpanded
        ) { withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded.toggle() } }
      }
    }.background(studio.t.background)
  }
  @ViewBuilder private var boardMenu: some View {
    let boards = (try? studio.store.boards(worldID: studio.worldID, kind: "canvas")) ?? []
    ForEach(boards) { item in
      Button {
        studio.openBoard(item.id, kind: "canvas")
      } label: {
        if item.id == session.boardID {
          StudioLabel(item.name, icon: "checkmark")
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
    Button("Fit everything in view") { session.command("fit") }
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
      MenuSection("Archived boards") {
        ForEach(archived) { item in
          Button("Restore “\(item.name)”") {
            studio.perform {
              try studio.store.setBoardArchived(
                worldID: studio.worldID, id: item.id, archived: false)
              studio.openBoard(item.id, kind: "canvas")
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
      studio.openBoard(id, kind: "canvas")
    }
  }
  private func archiveBoard() {
    guard let board = session.boardReference, let generation = session.dropSessionID,
      studio.canvasBoardID == nil || studio.canvasBoardID == board.id
    else { return }
    let name = session.name
    Task {
      guard await session.flush(), studio.destination == .canvas,
        session.boardReference == board, session.dropSessionID == generation,
        studio.canvasBoardID == nil || studio.canvasBoardID == board.id
      else { return }
      studio.perform {
        let next = try studio.store.archiveCanvasBoard(
          worldID: board.worldID, id: board.id, blankContent: CanvasBoardContent.empty
        )
        studio.canvasBoardID = next
        session.switchBoard(next)
        studio.show("Archived board “\(name)”", icon: "archivebox", actionTitle: "Undo") {
          studio.perform {
            try studio.store.setBoardArchived(worldID: board.worldID, id: board.id, archived: false)
            if studio.worldID == board.worldID, studio.destination == .canvas,
              studio.canvasBoardID == next
            {
              studio.canvasBoardID = board.id
              session.switchBoard(board.id)
            }
          }
        }
      }
    }
  }

  // MARK: Board

  private var board: some View {
    GeometryReader { geo in
      let acceptingDrop = studio.canReceiveWorkspaceReference && session.dropSessionID != nil
      ZStack(alignment: .bottom) {
        // Transparent: the engine's web view is mounted beneath the workspace by the shell.
        Color.clear
          .contentShape(Rectangle())
          .workspaceReferenceDrop(
            studio: studio, enabled: acceptingDrop,
            target: { point in
              guard let boardID = session.boardID, let sessionID = session.dropSessionID else {
                return nil
              }
              return { source in
                guard studio.destination == .canvas, studio.selectedRecord == nil,
                  studio.flushEditor()
                else { return false }
                try await session.drop(source, at: point, boardID: boardID, sessionID: sessionID)
                studio.show("Placed \(source.title) on the canvas")
                return true
              }
            }
          )
          // Only drag gestures should hit this region. Drawing and the composer keep their input.
          .allowsHitTesting(acceptingDrop)
          .background(
            GeometryReader { area in
              Color.clear.preference(
                key: CanvasFrameKey.self, value: area.frame(in: .named("shell")))
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
            .background(
              GeometryReader { area in
                Color.clear.preference(key: CanvasComposerHeightKey.self, value: area.size.height)
              }
            )
            // Clear of the engine's zoom and undo controls on narrower canvases.
            .padding(.bottom, 76)
        }
      }
      .overlay(alignment: .topLeading) {
        if showReferencePicker {
          let dragging = studio.recordDrag != nil || studio.workspaceReferenceDrag != nil
          CanvasReferencePicker(
            studio: studio,
            initialCategory: referenceCaptureCategory,
            initialQuery: studio.captureHint == "canvas-reference-empty" ? "No matching name" : "",
            place: placeReference,
            close: { showReferencePicker = false }
          )
          .frame(
            width: min(320, max(0, geo.size.width - 32)),
            height: min(370, max(0, geo.size.height - 32))
          )
          .padding(16)
          .disabled(placingReference)
          .opacity(dragging ? 0 : 1)
          .allowsHitTesting(!dragging)
          .accessibilityHidden(dragging)
        }
      }
    }
  }

  private var referenceCaptureCategory: CanvasReferencePicker.Category {
    switch studio.captureHint {
    case "canvas-reference-proposals": .proposals
    case "manual-canvas-reference-atlas": .atlas
    default: .events
    }
  }

  /// Keyboard activation goes through the same guarded placement as the native drop surface.
  private func placeReference(_ reference: WorldReference) {
    guard !placingReference, let board = session.boardReference,
      let sessionID = session.dropSessionID
    else { return }
    let bounds = session.webView.bounds
    let point = CGPoint(x: bounds.midX, y: bounds.midY)
    let location = studio.navigationLocation
    placingReference = true
    Task {
      defer { placingReference = false }
      guard studio.navigationLocation == location, studio.flushEditor() else { return }
      do {
        let source = try studio.store.resolveReference(reference, worldID: board.worldID)
        try await session.drop(source, at: point, boardID: board.id, sessionID: sessionID)
        guard studio.navigationLocation == location else { return }
        showReferencePicker = false
        studio.show("Placed \(source.title) on the canvas")
      } catch {
        if studio.navigationLocation == location {
          studio.show(error.localizedDescription, icon: "exclamationmark.triangle")
        }
      }
    }
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
      title: formKind == "capture" ? "Capture an idea" : "New entity",
      subtitle: "Saved in your library and placed on this board.",
      t: studio.t, close: closePanel
    ) {
      FormField(label: "Name", placeholder: "Name", text: $formTitle, t: studio.t)
      if formKind == "entity" {
        VStack(alignment: .leading, spacing: 6) {
          Text("Type").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
          FlowLayout(spacing: 6) {
            ForEach(Vocabulary.categories, id: \.self) { type in
              FilterChip(title: type, selected: formCategory == type, t: studio.t) {
                formCategory = type
              }
            }
          }
        }
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("Notes").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
        TextEditor(text: $formBody).font(.studio(size: 14)).scrollContentBackground(.hidden)
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
            worldID: studio.worldID, title: formTitle, body: formBody, kind: formKind,
            category: formKind == "entity" ? formCategory : "")
          try studio.reload()
          session.sync()
          session.add([record])
          panel = nil
        }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(
          formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && formBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                  Text(record.title).font(.studio(size: 13.5, weight: .medium)).lineLimit(1)
                  Text(
                    record.category.isEmpty
                      ? Vocabulary.kindLabel(record.kind)
                      : Vocabulary.displayCategory(record.category)
                  )
                  .font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
                }
                Spacer()
                StudioIcon("plus", size: 12)
                  .foregroundStyle(studio.t.secondary)
              }.padding(.horizontal, 8).frame(height: 44).hoverFill(studio.t)
            }.buttonStyle(.plain).help("Add to board, or select it if it is already there")
          }
          if matches.isEmpty {
            Text(studio.records.isEmpty ? "Your library is empty." : "No records match.")
              .font(.studio(size: 13)).foregroundStyle(studio.t.secondary).padding(.vertical, 30)
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

/// Edits a frozen relationship snapshot shared by Graph and Canvas.
struct RelationEditor: View {
  let t: Theme
  let title: String
  let source: String
  let target: String
  @State private var label: String
  @State private var attributes: RelationshipAttributes
  let records: [LoreRecord]
  let note: String
  let suggestions: [String]
  let editable: Bool
  let removable: Bool
  let hide: (() -> Void)?
  let save: (String, RelationshipAttributes) -> Void
  let remove: () -> Void
  let cancel: () -> Void

  init(
    t: Theme, title: String, source: String, target: String, label: String,
    attributes: RelationshipAttributes = .init(), records: [LoreRecord], note: String,
    suggestions: [String] = [], editable: Bool = true, removable: Bool = false,
    hide: (() -> Void)? = nil, save: @escaping (String, RelationshipAttributes) -> Void,
    remove: @escaping () -> Void = {}, cancel: @escaping () -> Void
  ) {
    self.t = t
    self.title = title
    self.source = source
    self.target = target
    _label = State(initialValue: label)
    _attributes = State(initialValue: attributes)
    self.records = records
    self.note = note
    self.suggestions = suggestions
    self.editable = editable
    self.removable = removable
    self.hide = hide
    self.save = save
    self.remove = remove
    self.cancel = cancel
  }

  var body: some View {
    SheetScaffold(title: title, t: t, close: cancel) {
      HStack(spacing: 8) {
        endpoint(source)
        StudioIcon("arrow.right", size: 11)
          .foregroundStyle(t.muted)
        endpoint(target)
      }
      FormField(
        label: "How are they connected?", placeholder: "guided by, rules, born in…", text: $label,
        t: t, submit: submit
      ).disabled(!editable)
      if editable && !suggestions.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(suggestions, id: \.self) { value in
              FilterChip(title: value, selected: label == value, t: t) { label = value }
            }
          }
        }.scrollIndicators(.never)
      }
      RelationshipAttributesFields(
        attributes: $attributes, records: records, t: t, editable: editable)
      Text(note).font(.studio(size: 12.5)).foregroundStyle(t.muted).lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    } footer: {
      if let hide { Button("Hide on board", action: hide).buttonStyle(QuietButton(t: t)) }
      if removable && editable {
        Button("Remove", action: remove).buttonStyle(QuietButton(t: t, role: .danger))
      }
      Spacer()
      Button(editable ? (removable ? "Cancel" : "Keep as an arrow") : "Close", action: cancel)
        .buttonStyle(QuietButton(t: t, role: .ghost))
      if editable {
        Button("Save", action: submit).buttonStyle(QuietButton(t: t, primary: true))
          .keyboardShortcut(.defaultAction).disabled(!valid)
      }
    }
  }
  private var valid: Bool {
    editable && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && label.count <= 80 && relationshipDatesFit(attributes)
  }
  private func submit() { if valid { save(label, attributes) } }
  private func endpoint(_ name: String) -> some View {
    Text(name).font(.studio(.label)).lineLimit(1)
      .padding(.horizontal, 10).frame(height: 28)
      .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.smallRadius))
      .overlay(RoundedRectangle(cornerRadius: Metric.smallRadius).stroke(t.hairline, lineWidth: 1))
  }
}

private struct CanvasComposerHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 76
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// The same local address can be dragged or copied by activating the control with the keyboard.
struct SpatialReferenceHandle: View {
  @ObservedObject var studio: Studio
  let reference: WorldReference
  let title: String
  let icon: String
  let label: String

  var body: some View {
    IconButton(icon: icon, label: "Copy \(label.lowercased()) reference", t: studio.t) {
      studio.perform {
        let source = try studio.store.resolveReference(reference, worldID: studio.worldID)
        let clipboard = NSPasteboard.general
        clipboard.clearContents()
        guard clipboard.setString(source.markdown, forType: .string) else {
          throw SynthesisError.invalid("The reference could not be copied.")
        }
        studio.show("\(label) reference copied", icon: "link")
      }
    }
    .help("Drag the \(label.lowercased()) reference, or click to copy it")
    .workspaceReferenceDraggable(reference, title: title, icon: icon, studio: studio)
  }
}
