import AppKit
import SwiftUI
import SynthesisCore

private struct CardSizeKey: PreferenceKey {
  static let defaultValue: [String: CGSize] = [:]
  static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
    value.merge(nextValue()) { $1 }
  }
}

/// Manually curated board. Cards reference real records; semantic relationships are read from
/// the world and drawn as connectors. The assistant is optional and docks beside the board.
struct CuratedCanvas: View {
  enum Tool { case select, pan, connect }
  enum Panel: String, Identifiable {
    case create, connection, library, rename
    var id: String { rawValue }
  }
  @ObservedObject var studio: Studio
  @StateObject private var board: BoardController
  @State private var tool = Tool.select
  @State private var panel: Panel?
  @State private var sizes: [String: CGSize] = [:]
  @State private var areaSize = CGSize(width: 1000, height: 700)
  @State private var dragIDs: Set<String> = []
  @State private var dragOffset = CGSize.zero
  @State private var marquee: CGRect?
  @State private var marqueeBase: Set<String> = []
  @State private var panAnchor: CGPoint?
  @State private var linkDrag: (source: String, point: CGPoint)?
  @State private var hoveredEdge: String?
  @State private var connectSource: String?
  @State private var connectTarget: String?
  @State private var editingRelation: Relation?
  @State private var editingLocal: Int?
  @State private var edgeLabel = ""
  @State private var formTitle = ""
  @State private var formBody = ""
  @State private var formCategory = "Characters"
  @State private var formKind = "entity"
  @State private var editingCardID: String?
  @State private var boardName = ""
  @State private var pickerQuery = ""
  @State private var companionStart: Double?
  @State private var didInitialFit = false
  @State private var focus = InputFocus()
  init(studio: Studio) {
    self.studio = studio
    _board = StateObject(wrappedValue: BoardController(studio: studio))
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
            boardArea
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
    .background(studio.t.background)
    .onAppear {
      board.load()
      if studio.captureHint == "canvas-selected" {
        board.selection = Set(board.document.cards.prefix(2).map(\.id))
      }
      studio.editorSave = { board.save() }
      studio.canvasUndo = { board.step(back: $0) }
      studio.canvasFit = { fit() }
      if let width = try? studio.store.preference("companion-width"), let value = Double(width) {
        studio.companionWidth = min(460, max(320, value))
      }
    }
    .onDisappear { if board.loaded { board.save() } }
    .onChange(of: studio.companionExpanded) { _, _ in
      // The board column changes width; reframe once the layout has settled.
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(220))
        fit()
      }
    }
    .sheet(item: $panel) { item in
      switch item {
      case .create: createForm
      case .connection: connectionForm
      case .library: libraryPicker
      case .rename: renameForm
      }
    }
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
          Text(board.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
          Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            .foregroundStyle(studio.t.muted)
        }.padding(.horizontal, 6).frame(height: 28).hoverFill(studio.t)
      }.padding(.leading, -4).help("Switch, rename or archive boards")
      saveStatus
    } trailing: {
      PlainMenu {
        addMenu
      } label: {
        Label("Add", systemImage: "plus").font(.system(size: 13, weight: .medium)).fixedSize()
          .padding(.horizontal, 10).frame(height: Metric.control)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(
            RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.hairline, lineWidth: 1))
      }.help("Add to this board")
      if studio.mode == .assisted {
        IconButton(
          icon: "sidebar.right",
          label: studio.companionExpanded ? "Hide companion" : "Open companion conversation",
          t: studio.t, active: studio.companionExpanded
        ) { withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded.toggle() } }
      }
    }
  }
  @ViewBuilder private var saveStatus: some View {
    if let failure = board.failure {
      Button {
        if board.loaded { board.save() } else { board.load() }
      } label: {
        Label(
          board.loaded ? "Not saved · Retry" : "Could not open · Retry",
          systemImage: "exclamationmark.triangle"
        ).font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.warning)
      }.buttonStyle(.plain).help(failure)
    } else {
      Text("Saved").font(.system(size: 12)).foregroundStyle(studio.t.muted).fixedSize()
        .help("This board is saved on this device")
    }
  }
  @ViewBuilder private var boardMenu: some View {
    let boards = (try? studio.store.boards(worldID: studio.worldID, kind: "canvas")) ?? []
    ForEach(boards) { item in
      Button {
        if board.save() { studio.canvasBoardID = item.id }
      } label: {
        if item.id == board.boardID {
          Label(item.name, systemImage: "checkmark")
        } else {
          Text(item.name)
        }
      }
    }
    if !boards.isEmpty { Divider() }
    Button("New board") { newBoard() }
    Button("Rename…") {
      boardName = board.name
      panel = .rename
    }.disabled(!board.loaded)
    Button("Archive board") { archiveBoard() }.disabled(board.boardID == nil)
    let archived =
      (try? studio.store.boards(worldID: studio.worldID, kind: "canvas", archived: true)) ?? []
    if !archived.isEmpty {
      Menu("Archived boards") {
        ForEach(archived) { item in
          Button("Restore “\(item.name)”") {
            studio.perform {
              try studio.store.setBoardArchived(
                worldID: studio.worldID, id: item.id, archived: false)
              if board.save() { studio.canvasBoardID = item.id }
            }
          }
        }
      }
    }
  }
  @ViewBuilder private var addMenu: some View {
    Button("Note") { prepareCreate("capture") }
    Button("Entity") { prepareCreate("entity") }
    Button("From library…") {
      pickerQuery = ""
      panel = .library
    }
    Button("Image…") { board.importImage() }
    Divider()
    Menu("Entity from a template") {
      ForEach(Vocabulary.categories, id: \.self) { type in
        Button(type) {
          prepareCreate("entity")
          formCategory = type
          formBody =
            type == "Power systems"
            ? "Source\n\nCosts\n\nRestrictions\n\nProgression"
            : "Description\n\nMotivations\n\nConnections"
        }
      }
    }
  }
  private func newBoard() {
    studio.perform {
      guard board.save() else { return }
      let existing = try studio.store.boards(worldID: studio.worldID, kind: "canvas").count
      let doc = String(decoding: try JSONEncoder().encode(CanvasDocument()), as: UTF8.self)
      studio.canvasBoardID = try studio.store.saveBoard(
        worldID: studio.worldID,
        name: existing == 0 ? "Untitled board" : "Untitled board \(existing + 1)",
        kind: "canvas", content: doc
      ).id
    }
  }
  private func archiveBoard() {
    guard let id = board.boardID, board.save() else { return }
    let name = board.name
    studio.perform {
      try studio.store.setBoardArchived(worldID: studio.worldID, id: id, archived: true)
      let remaining = try studio.store.boards(worldID: studio.worldID, kind: "canvas")
      if let next = remaining.first {
        studio.canvasBoardID = next.id
      } else {
        let doc = String(decoding: try JSONEncoder().encode(CanvasDocument()), as: UTF8.self)
        studio.canvasBoardID = try studio.store.saveBoard(
          worldID: studio.worldID, name: "Untitled board", kind: "canvas", content: doc
        ).id
      }
      studio.show("Archived board “\(name)”", icon: "archivebox", actionTitle: "Undo") {
        studio.perform {
          try studio.store.setBoardArchived(worldID: studio.worldID, id: id, archived: false)
          studio.canvasBoardID = id
        }
      }
    }
  }

  // MARK: Board

  private var boardArea: some View {
    GeometryReader { geo in
      let edges = board.edges
      let rects = cardRects(geo.size)
      ZStack {
        backdrop(edges: edges, rects: rects)
        CanvasInputSurface(
          onPan: { board.moveViewport($0) },
          onZoom: { factor, point in
            board.zoom(
              factor: factor,
              anchor: CGPoint(x: point.x - geo.size.width / 2, y: point.y - geo.size.height / 2))
          },
          onClick: {
            if tool == .connect {
              cancelConnection()
            } else {
              board.selection = []
            }
          },
          onDrag: { start, current, phase in emptyDrag(start, current, phase, rects: rects) },
          onKey: handleKey, focus: focus
        ).contextMenu {
          addMenu
          Divider()
          Button("Select all") { board.selectAll() }
          Button("Fit to content") { fit() }
        }
        ForEach(edges) { edge in edgeLabel(edge, rects: rects, lanes: edgeLanes(edges)) }
        ForEach(board.document.cards) { card in cardView(card, in: geo.size, edges: edges) }
        if let marquee {
          RoundedRectangle(cornerRadius: 3).fill(studio.t.accent.opacity(0.1))
            .overlay(
              RoundedRectangle(cornerRadius: 3).stroke(studio.t.accent.opacity(0.7), lineWidth: 1)
            )
            .frame(width: marquee.width, height: marquee.height)
            .position(x: marquee.midX, y: marquee.midY).allowsHitTesting(false)
        }
        if board.document.cards.isEmpty && board.loaded { emptyBoard }
        overlays(width: geo.size.width)
      }
      .coordinateSpace(name: "board").clipped()
      .onPreferenceChange(CardSizeKey.self) { value in
        sizes = value
        if !didInitialFit, board.loaded, board.document.viewport == nil, !value.isEmpty {
          didInitialFit = true
          fit()
        }
      }
      .onAppear { areaSize = geo.size }
      .onChange(of: geo.size) { _, size in areaSize = size }
    }
  }
  private func screenPoint(_ card: CanvasCard, _ size: CGSize) -> CGPoint {
    let moving = dragIDs.contains(card.id)
    return CGPoint(
      x: size.width / 2 + card.x * board.viewport.zoom + board.viewport.x
        + (moving ? dragOffset.width : 0),
      y: size.height / 2 + card.y * board.viewport.zoom + board.viewport.y
        + (moving ? dragOffset.height : 0))
  }
  private func cardRects(_ size: CGSize) -> [String: CGRect] {
    var rects: [String: CGRect] = [:]
    for card in board.document.cards {
      let center = screenPoint(card, size)
      let measured = sizes[card.id] ?? BoardController.defaultCard
      let width = measured.width * board.viewport.zoom
      let height = measured.height * board.viewport.zoom
      rects[card.id] = CGRect(
        x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
    return rects
  }
  private func edgeActive(_ edge: DisplayEdge) -> Bool {
    hoveredEdge == edge.id || board.selection.isEmpty || board.selection.contains(edge.source)
      || board.selection.contains(edge.target)
  }
  /// Grid, group frames and connectors. Drawn beneath the input surface and the cards.
  private func backdrop(edges: [DisplayEdge], rects: [String: CGRect]) -> some View {
    let lanes = edgeLanes(edges)
    let zoom = board.viewport.zoom
    let offset = CGPoint(x: board.viewport.x, y: board.viewport.y)
    return Canvas { context, size in
      let gap = 28.0 * zoom
      if gap >= 9 {
        let originX = (size.width / 2 + offset.x).truncatingRemainder(dividingBy: gap)
        let originY = (size.height / 2 + offset.y).truncatingRemainder(dividingBy: gap)
        var dots = Path()
        for x in stride(from: originX, to: size.width, by: gap) {
          for y in stride(from: originY, to: size.height, by: gap) {
            dots.addEllipse(in: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
          }
        }
        context.fill(dots, with: .color(studio.t.muted.opacity(studio.dark ? 0.2 : 0.28)))
      }
      for group in Set(board.document.cards.compactMap(\.group)) {
        let frame = board.document.cards.filter { $0.group == group }.reduce(CGRect.null) {
          $0.union(rects[$1.id] ?? .null)
        }.insetBy(dx: -16 * zoom, dy: -16 * zoom)
        guard !frame.isNull else { continue }
        let shape = Path(roundedRect: frame, cornerRadius: 16 * zoom)
        context.fill(shape, with: .color(studio.t.accent.opacity(0.05)))
        context.stroke(
          shape, with: .color(studio.t.accent.opacity(0.3)),
          style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
      }
      for edge in edges {
        guard let a = rects[edge.source], let b = rects[edge.target] else { continue }
        let geometry = EdgeGeometry.between(a, b, lane: (lanes[edge.id] ?? 0) * zoom)
        let active = edgeActive(edge)
        let color = studio.t.accent.opacity(active ? (hoveredEdge == edge.id ? 1 : 0.75) : 0.2)
        context.stroke(
          geometry.path, with: .color(color),
          style: StrokeStyle(
            lineWidth: hoveredEdge == edge.id ? 2 : 1.5, lineCap: .round,
            dash: edge.localIndex == nil ? [] : [5, 4]))
        context.fill(geometry.arrow, with: .color(color))
      }
      if let linkDrag, let from = rects[linkDrag.source] {
        var path = Path()
        path.move(to: CGPoint(x: from.midX, y: from.midY))
        path.addLine(to: linkDrag.point)
        context.stroke(
          path, with: .color(studio.t.accent),
          style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
        context.fill(
          Path(
            ellipseIn: CGRect(x: linkDrag.point.x - 4, y: linkDrag.point.y - 4, width: 8, height: 8)
          ),
          with: .color(studio.t.accent))
      }
    }.allowsHitTesting(false)
  }
  @ViewBuilder private func edgeLabel(
    _ edge: DisplayEdge, rects: [String: CGRect], lanes: [String: Double]
  ) -> some View {
    if let a = rects[edge.source], let b = rects[edge.target] {
      let mid = EdgeGeometry.between(a, b, lane: (lanes[edge.id] ?? 0) * board.viewport.zoom)
        .midpoint
      let active = edgeActive(edge)
      Button {
        inspect(edge)
      } label: {
        Text(edge.label).font(.system(size: 12, weight: .medium)).lineLimit(1)
          .foregroundStyle(active ? studio.t.accent : studio.t.muted)
          .padding(.horizontal, 8).frame(height: 22)
          .background(studio.t.background, in: Capsule())
          .overlay(
            Capsule().stroke(
              hoveredEdge == edge.id ? studio.t.accent.opacity(0.8) : studio.t.border,
              lineWidth: 1))
      }.buttonStyle(.plain).opacity(active ? 1 : 0.5)
        .help(
          edge.localIndex == nil
            ? "Relationship: \(edge.label). Click to edit."
            : "Board link: \(edge.label). Click to edit."
        )
        .onHover { hoveredEdge = $0 ? edge.id : (hoveredEdge == edge.id ? nil : hoveredEdge) }
        .position(mid)
    }
  }
  private func cardView(_ card: CanvasCard, in size: CGSize, edges: [DisplayEdge]) -> some View {
    let selected = board.selection.contains(card.id)
    return EntityCanvasCard(
      studio: studio, card: card, selected: selected,
      connecting: tool == .connect, connectOrigin: connectSource == card.id,
      linkTarget: linkDrag != nil && linkDrag?.source != card.id,
      open: { open(card) }, select: { select(card) },
      link: { phase, point in linkGesture(card, phase, point, size: size) }
    )
    .frame(width: 300)
    .background(
      GeometryReader { proxy in
        Color.clear.preference(key: CardSizeKey.self, value: [card.id: proxy.size])
      }
    )
    .scaleEffect(board.viewport.zoom)
    .position(screenPoint(card, size))
    .zIndex(dragIDs.contains(card.id) ? 2 : (selected ? 1 : 0))
    .allowsHitTesting(tool != .pan)
    .gesture(
      DragGesture(minimumDistance: 4, coordinateSpace: .named("board"))
        .onChanged { value in
          guard tool == .select else { return }
          if dragIDs.isEmpty {
            if !board.selection.contains(card.id) { board.selection = [card.id] }
            dragIDs = board.selection
            focus.take()
          }
          dragOffset = value.translation
        }
        .onEnded { value in
          guard !dragIDs.isEmpty else { return }
          let ids = dragIDs
          let delta = CGSize(
            width: value.translation.width / board.viewport.zoom,
            height: value.translation.height / board.viewport.zoom)
          // Commit and clear in one transaction so the card does not jump back for a frame.
          dragIDs = []
          dragOffset = .zero
          board.move(ids, by: delta)
        }
    )
    .contextMenu { cardMenu(card) }
  }
  @ViewBuilder private func cardMenu(_ card: CanvasCard) -> some View {
    Button(card.recordID == nil ? "Edit…" : "Open") { open(card) }
    Button("Connect to…") { beginConnection(card) }
    if studio.mode == .assisted, let id = card.recordID,
      let record = studio.records.first(where: { $0.id == id })
    {
      Button("Reference in conversation") {
        studio.reference(record)
        withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = true }
      }
    }
    Divider()
    Button(card.image == nil ? "Add artwork…" : "Replace artwork…") {
      board.importImage(cardID: card.id)
    }
    if card.image != nil {
      Button("Remove artwork") {
        board.mutate { doc in
          if let i = doc.cards.firstIndex(where: { $0.id == card.id }) { doc.cards[i].image = nil }
        }
      }
    }
    if card.group != nil {
      Button("Ungroup") {
        board.selection = [card.id]
        board.ungroup()
      }
    }
    Divider()
    Button(card.recordID == nil ? "Remove from board" : "Remove from board · keeps the record") {
      if !board.selection.contains(card.id) { board.selection = [card.id] }
      board.removeSelection()
    }
  }
  private var emptyBoard: some View {
    EmptyState(
      icon: Destination.canvas.icon, title: "An empty board",
      message:
        "Arrange characters, places and loose thoughts by hand. Relationships between entities appear as connectors.",
      t: studio.t
    ) {
      Button("Add from library") {
        pickerQuery = ""
        panel = .library
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(studio.records.isEmpty)
      Button("New entity") { prepareCreate("entity") }.buttonStyle(QuietButton(t: studio.t))
      Button("New note") { prepareCreate("capture") }.buttonStyle(QuietButton(t: studio.t))
    }.padding(.bottom, 80)
  }

  // MARK: Floating controls

  private func bottomInset(width: CGFloat) -> Double {
    if !composerVisible { return 64 }
    return width >= 1040 ? 104 : 150
  }
  private func overlays(width: CGFloat) -> some View {
    VStack(spacing: 10) {
      if tool == .connect {
        connectHint.transition(.opacity)
      } else if board.selection.count > 1 {
        selectionBar.transition(.opacity)
      }
      Spacer(minLength: 0)
      if composerVisible && width < 1040 {
        UnifiedComposer(studio: studio, collapsed: true).frame(maxWidth: 460)
      }
      ZStack(alignment: .bottom) {
        HStack(alignment: .bottom) {
          toolbar
          Spacer(minLength: 0)
          ZoomControls(
            zoom: board.viewport.zoom, t: studio.t,
            zoomOut: { board.zoom(factor: 1 / 1.2, anchor: .zero) },
            zoomIn: { board.zoom(factor: 1.2, anchor: .zero) }, fit: { fit() })
        }
        if composerVisible && width >= 1040 {
          UnifiedComposer(studio: studio, collapsed: true).frame(width: 440)
        }
      }
    }.padding(14).animation(.easeOut(duration: 0.14), value: board.selection.count > 1)
      .animation(.easeOut(duration: 0.14), value: tool == .connect)
  }
  private var toolbar: some View {
    HStack(spacing: 2) {
      IconButton(icon: "cursorarrow", label: "Select · V", t: studio.t, active: tool == .select) {
        setTool(.select)
      }
      IconButton(icon: "hand.raised", label: "Pan · H", t: studio.t, active: tool == .pan) {
        setTool(.pan)
      }
      IconButton(
        icon: "arrow.triangle.branch", label: "Connect two cards · C", t: studio.t,
        active: tool == .connect
      ) { setTool(.connect) }
      Rectangle().fill(studio.t.hairline).frame(width: 1, height: 16).padding(.horizontal, 3)
      IconButton(icon: "arrow.uturn.backward", label: "Undo · ⌘Z", t: studio.t) {
        board.step(back: true)
      }.disabled(board.past.isEmpty)
      IconButton(icon: "arrow.uturn.forward", label: "Redo · ⇧⌘Z", t: studio.t) {
        board.step(back: false)
      }.disabled(board.future.isEmpty)
      IconMenu(icon: "ellipsis", label: "Layout", t: studio.t) {
        Button("Tidy all cards into a grid") {
          board.autoLayout(sizes: sizes)
          fit()
        }.disabled(board.document.cards.count < 2)
        Button("Select all") { board.selectAll() }.disabled(board.document.cards.isEmpty)
      }
    }.padding(3).floatingPanel(studio.t)
  }
  private var selectionBar: some View {
    HStack(spacing: 2) {
      Text("\(board.selection.count) selected").font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(studio.t.secondary).padding(.horizontal, 8)
      Rectangle().fill(studio.t.hairline).frame(width: 1, height: 16).padding(.trailing, 3)
      if board.selectionIsGrouped {
        barButton("Ungroup", "rectangle.dashed") { board.ungroup() }
      } else {
        barButton("Group", "rectangle.dashed") { board.group() }
      }
      barButton("Row", "align.vertical.center") { board.arrange(row: true, sizes: sizes) }
      barButton("Column", "align.horizontal.center") { board.arrange(row: false, sizes: sizes) }
      if board.selection.count == 2 {
        barButton("Connect", "arrow.triangle.branch") {
          let ids = board.document.cards.filter { board.selection.contains($0.id) }.map(\.id)
          startConnection(from: ids[0], to: ids[1])
        }
      }
      barButton("Remove", "minus.circle") { board.removeSelection() }
    }.padding(3).floatingPanel(studio.t)
  }
  private func barButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      Label(title, systemImage: icon).font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(studio.t.text).padding(.horizontal, 8).frame(height: 28)
        .hoverFill(studio.t)
    }.buttonStyle(.plain)
  }
  private var connectHint: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.triangle.branch").foregroundStyle(studio.t.accent)
      Text(
        connectSource.flatMap { id in board.document.cards.first { $0.id == id } }.map {
          "From “\(title(of: $0))” — click the card it connects to"
        } ?? "Click the card a connection starts from"
      ).font(.system(size: 13))
      Button("Cancel") { cancelConnection() }.buttonStyle(.plain)
        .font(.system(size: 13, weight: .medium)).foregroundStyle(studio.t.accent)
    }.padding(.horizontal, 14).frame(height: 36).floatingPanel(studio.t)
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

  // MARK: Interaction

  private func fit() {
    board.fit(areaSize, sizes: sizes, bottomInset: bottomInset(width: areaSize.width))
  }
  private func setTool(_ value: Tool) {
    tool = value
    if value != .connect { connectSource = nil }
    focus.take()
  }
  private func emptyDrag(
    _ start: CGPoint, _ current: CGPoint, _ phase: CanvasInputSurface.Phase,
    rects: [String: CGRect]
  ) {
    if tool != .select {
      let last = panAnchor ?? start
      board.moveViewport(CGSize(width: current.x - last.x, height: current.y - last.y))
      panAnchor = phase == .ended ? nil : current
      return
    }
    if phase == .began {
      marqueeBase = NSEvent.modifierFlags.contains(.shift) ? board.selection : []
    }
    let rect = CGRect(
      x: min(start.x, current.x), y: min(start.y, current.y), width: abs(current.x - start.x),
      height: abs(current.y - start.y))
    board.selection = marqueeBase.union(rects.filter { $0.value.intersects(rect) }.keys)
    marquee = phase == .ended ? nil : rect
  }
  private func handleKey(_ event: NSEvent) -> Bool {
    let command = event.modifierFlags.contains(.command)
    switch event.keyCode {
    case 51, 117:
      guard !board.selection.isEmpty else { return false }
      board.removeSelection()
      return true
    case 53:
      if tool == .connect {
        cancelConnection()
      } else {
        board.selection = []
      }
      return true
    case 36:
      guard board.selection.count == 1,
        let card = board.document.cards.first(where: { board.selection.contains($0.id) })
      else { return false }
      open(card)
      return true
    case 123, 124, 125, 126:
      guard !board.selection.isEmpty else { return false }
      let step = event.modifierFlags.contains(.shift) ? 40.0 : 10.0
      let delta: CGSize =
        switch event.keyCode {
        case 123: CGSize(width: -step, height: 0)
        case 124: CGSize(width: step, height: 0)
        case 125: CGSize(width: 0, height: step)
        default: CGSize(width: 0, height: -step)
        }
      board.move(board.selection, by: delta)
      return true
    default: break
    }
    guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
    if command && key == "a" {
      board.selectAll()
      return true
    }
    guard !command else { return false }
    switch key {
    case "v": setTool(.select)
    case "h": setTool(.pan)
    case "c": setTool(.connect)
    case "1": fit()
    default: return false
    }
    return true
  }
  private func select(_ card: CanvasCard) {
    focus.take()
    if tool == .connect {
      beginConnection(card)
    } else if NSApp.currentEvent?.clickCount == 2 {
      open(card)
    } else if NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift) {
      if board.selection.contains(card.id) {
        board.selection.remove(card.id)
      } else {
        board.selection.insert(card.id)
      }
    } else {
      board.selection = [card.id]
    }
  }
  private func open(_ card: CanvasCard) {
    if let id = card.recordID {
      guard let record = studio.records.first(where: { $0.id == id }) else {
        studio.show("This card’s record is archived. Restore it from Library.", icon: "archivebox")
        return
      }
      if board.save() { studio.openRecord(record) }
    } else {
      editingCardID = card.id
      formTitle = card.text
      formKind = "card"
      panel = .create
    }
  }
  private func title(of card: CanvasCard) -> String {
    studio.records.first { $0.id == card.recordID }?.title ?? card.text
  }
  private func cancelConnection() {
    connectSource = nil
    connectTarget = nil
    tool = .select
  }
  private func beginConnection(_ card: CanvasCard) {
    if let source = connectSource, source != card.id {
      startConnection(from: source, to: card.id)
    } else {
      connectSource = card.id
      tool = .connect
    }
  }
  private func startConnection(from source: String, to target: String) {
    connectSource = source
    connectTarget = target
    editingRelation = nil
    editingLocal = nil
    edgeLabel = ""
    panel = .connection
  }
  private func linkGesture(
    _ card: CanvasCard, _ phase: CanvasInputSurface.Phase, _ point: CGPoint, size: CGSize
  ) {
    switch phase {
    case .began, .changed: linkDrag = (card.id, point)
    case .ended:
      linkDrag = nil
      let target = cardRects(size).first { $0.key != card.id && $0.value.contains(point) }?.key
      if let target {
        startConnection(from: card.id, to: target)
      } else if hypot(point.x - screenPoint(card, size).x, point.y - screenPoint(card, size).y)
        < 200,
        cardRects(size)[card.id]?.insetBy(dx: -18, dy: -18).contains(point) == true
      {
        // A click on the handle rather than a drag: fall back to pick-a-target mode.
        beginConnection(card)
      }
    }
  }
  private func inspect(_ edge: DisplayEdge) {
    connectSource = edge.source
    connectTarget = edge.target
    edgeLabel = edge.label
    editingRelation = board.relationships.first { $0.id == edge.id }
    editingLocal = edge.localIndex
    panel = .connection
  }
  private func prepareCreate(_ type: String) {
    editingCardID = nil
    formTitle = ""
    formBody = ""
    formKind = type
    panel = .create
  }

  // MARK: Sheets

  private func closePanel() { panel = nil }
  private var createForm: some View {
    let editing = editingCardID != nil
    return SheetScaffold(
      title: editing ? "Edit card" : (formKind == "entity" ? "New entity" : "New note"),
      subtitle: editing
        ? "This caption lives on the board only."
        : "Saved as a draft in your library and placed on this board.",
      t: studio.t, close: closePanel
    ) {
      FormField(
        label: editing ? "Caption" : "Title",
        placeholder: formKind == "entity" ? "Name" : "A short title", text: $formTitle, t: studio.t)
      if !editing && formKind == "entity" {
        VStack(alignment: .leading, spacing: 6) {
          Text("Type").font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
          HStack(spacing: 6) {
            ForEach(Vocabulary.categories, id: \.self) { type in
              FilterChip(title: type, selected: formCategory == type, t: studio.t) {
                formCategory = type
              }
            }
          }
        }
      }
      if !editing {
        VStack(alignment: .leading, spacing: 6) {
          Text("Notes").font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
          TextEditor(text: $formBody).font(.system(size: 14)).scrollContentBackground(.hidden)
            .padding(8).frame(height: 130)
            .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
            .overlay(
              RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.border, lineWidth: 1))
        }
      }
    } footer: {
      Spacer()
      Button("Cancel") { panel = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button(editing ? "Save" : "Create draft") {
        if let editingCardID {
          board.mutate { doc in
            if let index = doc.cards.firstIndex(where: { $0.id == editingCardID }) {
              doc.cards[index].text = formTitle
            }
          }
        } else {
          board.create(
            title: formTitle, body: formBody, kind: formKind == "entity" ? "entity" : "capture",
            category: formKind == "entity" ? formCategory : "Ideas")
        }
        if studio.error == nil { panel = nil }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
  private var renameForm: some View {
    SheetScaffold(title: "Rename board", t: studio.t, width: 380, close: closePanel) {
      FormField(placeholder: "Board name", text: $boardName, t: studio.t) {
        board.rename(boardName)
        panel = nil
      }
    } footer: {
      Spacer()
      Button("Cancel") { panel = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Rename") {
        board.rename(boardName)
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
            let placed = board.document.cards.contains { $0.recordID == record.id }
            Button {
              board.add(record)
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
                Image(systemName: placed ? "checkmark" : "plus").font(
                  .system(size: 12, weight: .medium)
                )
                .foregroundStyle(placed ? studio.t.positive : studio.t.secondary)
              }.padding(.horizontal, 8).frame(height: 44).hoverFill(studio.t)
            }.buttonStyle(.plain).help(placed ? "Already on this board" : "Add to board")
          }
          if matches.isEmpty {
            Text(studio.records.isEmpty ? "Your library is empty." : "No records match.")
              .font(.system(size: 13)).foregroundStyle(studio.t.secondary).padding(.vertical, 30)
          }
        }
      }.frame(height: 300)
    } footer: {
      Spacer()
      Button("Done") { panel = nil }.buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
  }
  private var sourceCard: CanvasCard? { board.document.cards.first { $0.id == connectSource } }
  private var targetCard: CanvasCard? { board.document.cards.first { $0.id == connectTarget } }
  private var realEntityPair: Bool {
    [sourceCard?.recordID, targetCard?.recordID].allSatisfy { id in
      studio.records.contains { $0.id == id && $0.kind == "entity" }
    }
  }
  private var connectionForm: some View {
    let editing = editingRelation != nil || editingLocal != nil
    let semantic = editingRelation != nil || (editingLocal == nil && realEntityPair)
    return RelationEditor(
      t: studio.t, title: editing ? "Edit connection" : "New connection",
      source: sourceCard.map(title(of:)) ?? "Source",
      target: targetCard.map(title(of:)) ?? "Target",
      label: $edgeLabel,
      note: semantic
        ? "A draft relationship between two entities. It appears in Graph and is not canon."
        : "A link on this board only. It does not establish a relationship in your lore.",
      suggestions: Array(Set(board.relationships.map(\.label))).sorted().prefix(6).map { $0 },
      removable: editing, save: saveEdge, remove: removeEdge,
      cancel: {
        panel = nil
        cancelConnection()
      })
  }
  private func saveEdge() {
    studio.perform {
      let label = edgeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
      if let editingRelation {
        try studio.store.updateRelation(
          worldID: studio.worldID, id: editingRelation.id, label: label)
      } else if let editingLocal {
        board.mutate { $0.edges[editingLocal].label = label }
      } else if realEntityPair, let source = sourceCard?.recordID, let target = targetCard?.recordID
      {
        _ = try studio.store.addRelation(
          worldID: studio.worldID, source: source, target: target, label: label)
      } else if let connectSource, let connectTarget {
        board.mutate {
          $0.edges.append(CanvasEdge(label: label, source: connectSource, target: connectTarget))
        }
      }
      board.refreshRelations()
      panel = nil
      cancelConnection()
    }
  }
  private func removeEdge() {
    studio.perform {
      if let relation = editingRelation {
        try studio.store.archiveRelation(worldID: studio.worldID, id: relation.id)
        studio.show("Removed “\(relation.label)”", icon: "minus.circle", actionTitle: "Undo") {
          studio.perform {
            try studio.store.restoreRelation(worldID: studio.worldID, id: relation.id)
            board.refreshRelations()
          }
        }
      } else if let editingLocal {
        board.mutate { $0.edges.remove(at: editingLocal) }
      }
      board.refreshRelations()
      panel = nil
      cancelConnection()
    }
  }
}

/// Label editor shared by Canvas and Graph for relationships and board links.
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
      Button("Cancel", action: cancel).buttonStyle(QuietButton(t: t, role: .ghost))
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

struct EntityCanvasCard: View {
  @ObservedObject var studio: Studio
  let card: CanvasCard
  var selected: Bool
  var connecting = false
  var connectOrigin = false
  var linkTarget = false
  var open: () -> Void
  var select: () -> Void
  var link: (CanvasInputSurface.Phase, CGPoint) -> Void
  @State private var hover = false
  private var record: LoreRecord? { studio.records.first { $0.id == card.recordID } }
  private var tint: Color { record.map { studio.t.category($0.category) } ?? studio.t.accent }
  private var title: String { record?.title ?? card.text }
  var body: some View {
    let t = studio.t
    VStack(alignment: .leading, spacing: 0) {
      if let image = ImageCache.image(base64: card.image) {
        Image(nsImage: image).resizable().scaledToFill().frame(width: 300, height: 104).clipped()
          .accessibilityLabel("Artwork for \(title)")
      }
      VStack(alignment: .leading, spacing: 9) {
        HStack(spacing: 6) {
          Image(systemName: record.map(recordIcon) ?? (card.image == nil ? "note.text" : "photo"))
            .font(.system(size: 11.5))
          Text(typeLabel).font(.system(size: 12, weight: .medium))
          Spacer()
          Button(action: open) {
            Image(systemName: record == nil ? "pencil" : "arrow.up.right")
              .font(.system(size: 11.5, weight: .medium)).foregroundStyle(t.secondary)
              .frame(width: 22, height: 22).hoverFill(t, radius: 5)
          }.buttonStyle(.plain).opacity(hover || selected ? 1 : 0)
            .help(record == nil ? "Edit caption" : "Open \(title)")
            .accessibilityLabel(record == nil ? "Edit caption" : "Open \(title)")
        }.foregroundStyle(tint)
        Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(t.text)
          .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        if let record, !record.body.isEmpty {
          Text(record.body).font(.system(size: 14)).lineSpacing(4).foregroundStyle(t.secondary)
            .lineLimit(5).fixedSize(horizontal: false, vertical: true)
        }
        if let record {
          HStack(spacing: 8) {
            StateBadge(state: record.state, t: t)
            if record.canonical != nil && record.state != "canon" {
              Text("Canon kept").font(.system(size: 12)).foregroundStyle(t.muted)
                .help("An accepted canon version exists; this draft has not replaced it")
            }
            if record.origin == "ai-proposed" {
              Text("AI-proposed").font(.system(size: 12)).foregroundStyle(t.muted)
            }
          }.padding(.top, 1)
        } else if card.recordID != nil {
          Text("Source archived").font(.system(size: 12)).foregroundStyle(t.muted)
        }
      }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(t.surface)
    .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
    .overlay(
      RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(
        outline, lineWidth: selected || connectOrigin || (connecting && hover) ? 1.6 : 1)
    )
    .shadow(color: t.shadow.opacity(hover ? 0.75 : 0.45), radius: hover ? 14 : 8, y: 4)
    .contentShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
    .onTapGesture(perform: select)
    .overlay(alignment: .trailing) { handle.offset(x: 9) }
    // The handle straddles the edge; widen the hover region so reaching for it keeps it shown.
    .padding(.trailing, 20)
    .contentShape(Rectangle())
    .onHover { hover = $0 }
    .padding(.trailing, -20)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(typeLabel): \(title)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var outline: Color {
    if selected || connectOrigin { return tint }
    if (connecting || linkTarget) && hover { return studio.t.accent }
    return studio.t.border.opacity(hover ? 1 : 0.75)
  }
  private var typeLabel: String {
    if let record {
      return record.category.isEmpty ? Vocabulary.kindLabel(record.kind) : record.category
    }
    return card.image == nil ? "Note" : "Image"
  }
  /// Drag from the handle to another card to connect; click it to pick a target instead.
  private var handle: some View {
    Circle().fill(studio.t.surface).frame(width: 18, height: 18)
      .overlay(Circle().stroke(tint, lineWidth: 1.5))
      .overlay(
        Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(tint)
      )
      .contentShape(Circle().inset(by: -6))
      .opacity((hover || selected) && !connecting ? 1 : 0)
      .gesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
          .onChanged { link(.changed, $0.location) }
          .onEnded { link(.ended, $0.location) }
      )
      .help("Drag to another card to connect").accessibilityLabel("Connect \(title)")
  }
}
