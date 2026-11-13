import AppKit
import SwiftUI
import SynthesisCore

struct CuratedCanvas: View {
  @ObservedObject var studio: Studio
  @StateObject private var board: BoardController
  @State private var tool = "Select"
  @State private var createSheet = false
  @State private var title = ""
  @State private var bodyText = ""
  @State private var category = "Characters"
  @State private var kind = "entity"
  @State private var connectSource: String?
  @State private var connectTarget: String?
  @State private var connectionSheet = false
  @State private var edgeLabel = ""
  @State private var editingRelation: Relation?
  @State private var editingLocal: Int?
  @State private var archivedRelation: String?
  @State private var dragID: String?
  @State private var drag = CGSize.zero
  @State private var viewportSize = CGSize(width: 1000, height: 700)
  @State private var companionStart: Double?
  @State private var showLibrary = false
  @State private var previousCompanion = false
  @State private var editingCardID: String?
  init(studio: Studio) {
    self.studio = studio
    _board = StateObject(wrappedValue: BoardController(studio: studio))
  }
  var body: some View {
    GeometryReader { geo in
      HStack(spacing: 0) {
        canvas.frame(maxWidth: .infinity, maxHeight: .infinity)
        if studio.mode == .assisted && studio.companionExpanded {
          Rectangle().fill(studio.t.border).frame(width: 5).overlay {
            Capsule().fill(studio.t.secondary).frame(width: 2, height: 28)
          }.onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(
              DragGesture().onChanged { value in
                if companionStart == nil { companionStart = studio.companionWidth }
                studio.companionWidth = max(
                  320, min(460, (companionStart ?? 400) - value.translation.width))
              }.onEnded { _ in
                companionStart = nil
                studio.perform {
                  try studio.store.setPreference(
                    "companion-width", value: String(studio.companionWidth))
                }
              })
          ConversationStudio(studio: studio, companion: true).frame(
            width: min(studio.companionWidth, max(300, geo.size.width * 0.48))
          )
          .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
    }.onAppear {
      board.load()
      studio.editorSave = { board.save() }
      if let width = try? studio.store.preference("companion-width"), let value = Double(width) {
        studio.companionWidth = min(460, max(320, value))
      }
    }.onDisappear { if board.loaded { board.save() } }
      .sheet(isPresented: $createSheet) { createForm }
      .sheet(isPresented: $connectionSheet) { connectionForm }
      .sheet(isPresented: $showLibrary) { libraryPicker }
  }
  private var canvas: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: "square.on.square").foregroundStyle(studio.t.accent)
        Menu {
          ForEach((try? studio.store.boards(worldID: studio.worldID, kind: "canvas")) ?? []) {
            item in
            Button(item.name) { if board.save() { studio.canvasBoardID = item.id } }
          }
          Button("New board") {
            studio.perform {
              guard board.save() else { return }
              let doc = String(decoding: try JSONEncoder().encode(CanvasDocument()), as: UTF8.self)
              studio.canvasBoardID = try studio.store.saveBoard(
                worldID: studio.worldID, name: "Untitled board", kind: "canvas", content: doc
              ).id
            }
          }
        } label: {
          Text(board.name).font(.system(size: 15, weight: .medium))
        }
        .menuStyle(.borderlessButton).fixedSize()
        Text("Canvas").font(.system(size: 13)).foregroundStyle(studio.t.secondary)
        Spacer()
        if let failure = board.failure {
          Button("Save failed · Retry") { board.save() }.foregroundStyle(.orange).help(failure)
        } else {
          Text("Saved locally").font(.system(size: 12)).foregroundStyle(studio.t.muted)
        }
        if studio.mode == .assisted && !studio.companionExpanded {
          IconButton(
            icon: "bubble.left.and.bubble.right", label: "Open companion chat", t: studio.t
          ) { withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = true } }
        }
      }.padding(.horizontal, 24).frame(height: 56)
      GeometryReader { geo in
        ZStack(alignment: .bottom) {
          boardSpace(size: geo.size).padding(
            .bottom, studio.mode == .assisted && !studio.companionExpanded ? 98 : 20)
          VStack(spacing: 12) {
            Spacer()
            if studio.mode == .assisted && !studio.companionExpanded {
              UnifiedComposer(studio: studio, collapsed: true).frame(maxWidth: 500).padding(
                .horizontal, 20)
            }
            toolbar.padding(.horizontal, 16).padding(.bottom, 14)
          }
        }.onAppear {
          viewportSize = geo.size
          if board.document.viewport == nil && !board.document.cards.isEmpty { board.fit(geo.size) }
        }.onChange(of: geo.size) { _, size in
          viewportSize = size
          if previousCompanion != studio.companionExpanded {
            previousCompanion = studio.companionExpanded
            board.fit(size)
          }
        }
      }
    }.background(studio.t.background)
  }
  private func boardSpace(size: CGSize) -> some View {
    GeometryReader { area in
      ZStack {
        Canvas { context, canvasSize in
          let gap = 32.0 * board.viewport.zoom
          for x in stride(
            from: board.viewport.x.truncatingRemainder(dividingBy: gap), to: canvasSize.width,
            by: gap)
          {
            for y in stride(
              from: board.viewport.y.truncatingRemainder(dividingBy: gap), to: canvasSize.height,
              by: gap)
            {
              context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                with: .color(studio.t.muted.opacity(0.12)))
            }
          }
          for group in Set(board.document.cards.compactMap(\.group)) {
            let members = board.document.cards.filter { $0.group == group }
            let rect = members.reduce(CGRect.null) { result, card in
              let p = point(card, area.size)
              return result.union(
                CGRect(
                  x: p.x - 170 * board.viewport.zoom, y: p.y - 150 * board.viewport.zoom,
                  width: 340 * board.viewport.zoom, height: 300 * board.viewport.zoom))
            }
            context.fill(
              Path(roundedRect: rect, cornerRadius: 18), with: .color(studio.t.accent.opacity(0.05))
            )
            context.stroke(
              Path(roundedRect: rect, cornerRadius: 18),
              with: .color(studio.t.accent.opacity(0.22)), lineWidth: 1)
          }
          for edge in visualEdges {
            guard let a = board.document.cards.first(where: { $0.id == edge.source }),
              let b = board.document.cards.first(where: { $0.id == edge.target })
            else { continue }
            let start = point(a, area.size)
            let end = point(b, area.size)
            let active =
              board.selection.isEmpty || board.selection.contains(a.id)
              || board.selection.contains(b.id)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
              path, with: .color(studio.t.accent.opacity(active ? 0.65 : 0.15)),
              lineWidth: active ? 1.8 : 1)
            let angle = atan2(end.y - start.y, end.x - start.x)
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            var arrow = Path()
            arrow.move(
              to: CGPoint(x: mid.x - cos(angle - 0.5) * 10, y: mid.y - sin(angle - 0.5) * 10))
            arrow.addLine(to: mid)
            arrow.addLine(
              to: CGPoint(x: mid.x - cos(angle + 0.5) * 10, y: mid.y - sin(angle + 0.5) * 10))
            context.stroke(
              arrow, with: .color(studio.t.accent.opacity(active ? 0.8 : 0.2)), lineWidth: 1.8)
          }
        }.allowsHitTesting(false)
        CanvasInputSurface(
          onPan: board.moveViewport, onZoom: board.zoom, onClick: { board.selection = [] })
        ForEach(visualEdges) { edge in
          if let a = board.document.cards.first(where: { $0.id == edge.source }),
            let b = board.document.cards.first(where: { $0.id == edge.target })
          {
            let start = point(a, area.size)
            let end = point(b, area.size)
            Button {
              inspect(edge)
            } label: {
              Text(edge.label).font(.system(size: 12, weight: .medium)).foregroundStyle(
                studio.t.accent
              ).padding(.horizontal, 9).padding(.vertical, 5)
                .background(studio.t.background, in: Capsule()).overlay(
                  Capsule().stroke(studio.t.border, lineWidth: 0.7))
            }.buttonStyle(.plain).help("Inspect relationship: \(edge.label)")
              .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 18)
          }
        }
        ForEach(board.document.cards) { card in
          EntityCanvasCard(
            studio: studio, card: card, selected: board.selection.contains(card.id),
            related: isRelated(card), open: { open(card) }, select: { select(card) },
            connect: { beginConnection(card) }
          )
          .frame(width: 300).scaleEffect(board.viewport.zoom).position(point(card, area.size))
          .offset(dragID == card.id ? drag : .zero)
          .gesture(
            DragGesture(minimumDistance: 6).onChanged { value in
              dragID = card.id
              drag = value.translation
            }.onEnded { value in
              let ids = board.selection.contains(card.id) ? board.selection : [card.id]
              if tool == "Pan" {
                board.moveViewport(value.translation)
              } else {
                board.mutate { doc in
                  for i in doc.cards.indices where ids.contains(doc.cards[i].id) {
                    doc.cards[i].x += value.translation.width / board.viewport.zoom
                    doc.cards[i].y += value.translation.height / board.viewport.zoom
                  }
                }
              }
              drag = .zero
              dragID = nil
            }
          )
          .contextMenu {
            Button("Open content") { open(card) }
            Button("Select with other nodes") { board.selection.insert(card.id) }
            Button("Connect to…") { beginConnection(card) }
            Button("Add artwork…") { board.importImage(cardID: card.id) }
            Button("Reference in conversation") {
              studio.draft += " [\(card.text)](synthesis://record/\(card.recordID ?? ""))"
              studio.persistComposer()
              if studio.mode == .assisted { studio.companionExpanded = true }
            }
            Divider()
            Button("Remove from board (keep source)") {
              board.selection = [card.id]
              board.removeSelection()
            }
          }
        }
        if board.document.cards.isEmpty && board.loaded {
          VStack(spacing: 18) {
            Image(systemName: "square.on.square").font(.system(size: 32, weight: .light))
              .foregroundStyle(studio.t.accent)
            Text("A canvas for your connections").font(.system(size: 26, weight: .medium))
            Text("Bring in your lore, or begin with a loose thought.").font(.system(size: 15))
              .foregroundStyle(studio.t.secondary)
            HStack(spacing: 12) {
              Button("Create an entity") { prepareCreate("entity") }.buttonStyle(
                QuietButton(t: studio.t, primary: true))
              Button("Add from library") { showLibrary = true }.buttonStyle(
                QuietButton(t: studio.t))
            }
          }.padding(24)
        }
        if let source = connectSource, !connectionSheet {
          VStack {
            Text(
              "Connect \(board.document.cards.first { $0.id == source }?.text ?? "node") · choose another node"
            )
            Button("Cancel connection") {
              connectSource = nil
              tool = "Select"
            }
          }.font(.system(size: 13)).padding(14).background(
            studio.t.surface, in: RoundedRectangle(cornerRadius: 10)
          ).frame(maxHeight: .infinity, alignment: .top).padding(.top, 12)
        }
      }.clipped().contextMenu {
        Button("Add note") { prepareCreate("capture") }
        Button("Add entity") { prepareCreate("entity") }
        Button("Add from library") { showLibrary = true }
        Button("Fit to content") { board.fit(area.size) }
      }
    }
  }
  private var toolbar: some View {
    HStack(spacing: 12) {
      HStack(spacing: 2) {
        control("cursorarrow", "Select nodes · ⌘ click for multiple") {
          tool = "Select"
          connectSource = nil
        }
        control("hand.draw", "Pan · drag empty canvas or scroll") {
          tool = "Pan"
          connectSource = nil
        }
        Menu {
          Button("Note") { prepareCreate("capture") }
          Button("Entity") { prepareCreate("entity") }
          Button("Image…") { board.importImage() }
          Button("From library…") { showLibrary = true }
          Menu("Start from a template") {
            ForEach(["Characters", "Power systems", "Places", "Factions"], id: \.self) { type in
              Button(type) {
                prepareCreate("entity")
                category = type
                bodyText =
                  type == "Power systems"
                  ? "Source\n\nCosts\n\nRestrictions\n\nProgression\n\nTechniques"
                  : "Description\n\nMotivations\n\nConnections"
              }
            }
          }
        } label: {
          Image(systemName: "plus").frame(width: 32, height: 32)
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Add to canvas")
        control("point.3.connected.trianglepath.dotted", "Connect selected entities") {
          tool = "Connect"
          if board.selection.count == 2 {
            let ids = Array(board.selection)
            connectSource = ids[0]
            connectTarget = ids[1]
            editingRelation = nil
            editingLocal = nil
            edgeLabel = ""
            connectionSheet = true
          } else {
            connectSource = board.selection.first
          }
        }
        Divider().frame(height: 20)
        control("arrow.uturn.backward", "Undo board change") { board.step(back: true) }.disabled(
          board.past.isEmpty)
        control("arrow.uturn.forward", "Redo board change") { board.step(back: false) }.disabled(
          board.future.isEmpty)
        Menu {
          Button("Group selection") { board.group() }.disabled(board.selection.count < 2)
          Button("Align and distribute") { board.align() }.disabled(board.selection.count < 2)
          Button("Clear selection") { board.selection = [] }
          Button("Remove selection from board") { board.removeSelection() }.disabled(
            board.selection.isEmpty)
          Divider()
          Button("Arrange nodes") {
            board.autoLayout()
            board.fit(viewportSize)
          }
          if let archivedRelation {
            Button("Restore removed relationship") {
              studio.perform {
                try studio.store.restoreRelation(worldID: studio.worldID, id: archivedRelation)
                self.archivedRelation = nil
                board.refreshRelations()
              }
            }
          }
        } label: {
          Image(systemName: "ellipsis").frame(width: 30, height: 32)
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(
          "Selection and layout tools")
      }.padding(4).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 10))
      Spacer(minLength: 0)
      HStack(spacing: 2) {
        control("minus", "Zoom out") { board.zoom(-0.1) }
        Text("\(Int(board.viewport.zoom*100))%").font(.system(size: 13)).monospacedDigit().frame(
          width: 42)
        control("plus", "Zoom in") { board.zoom(0.1) }
        control("arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", "Fit to content") {
          board.fit(viewportSize)
        }
      }.padding(4).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 10))
    }
  }
  private func control(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
    IconButton(icon: icon, label: title, t: studio.t, action: action)
      .background(
        (icon == "cursorarrow" && tool == "Select") || (icon == "hand.draw" && tool == "Pan")
          || (icon == "point.3.connected.trianglepath.dotted" && tool == "Connect")
          ? studio.t.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 7))
  }
  private func point(_ card: CanvasCard, _ size: CGSize) -> CGPoint {
    CGPoint(
      x: size.width / 2 + card.x * board.viewport.zoom + board.viewport.x,
      y: size.height / 2 + card.y * board.viewport.zoom + board.viewport.y)
  }
  private func isRelated(_ card: CanvasCard) -> Bool {
    board.selection.isEmpty || board.selection.contains(card.id)
      || visualEdges.contains {
        ($0.source == card.id && board.selection.contains($0.target))
          || ($0.target == card.id && board.selection.contains($0.source))
      }
  }
  private func select(_ card: CanvasCard) {
    if connectSource != nil || tool == "Connect" {
      beginConnection(card)
    } else if NSEvent.modifierFlags.contains(.command) {
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
    if let id = card.recordID, let record = studio.records.first(where: { $0.id == id }),
      board.save()
    {
      studio.openRecord(record)
    } else if card.recordID == nil {
      editingCardID = card.id
      title = card.text
      bodyText = card.text
      kind = "capture"
      createSheet = true
    }
  }
  private func beginConnection(_ card: CanvasCard) {
    if let source = connectSource, source != card.id {
      connectTarget = card.id
      editingRelation = nil
      editingLocal = nil
      edgeLabel = ""
      connectionSheet = true
    } else {
      connectSource = card.id
      tool = "Connect"
    }
  }
  private func prepareCreate(_ type: String) {
    editingCardID = nil
    title = ""
    bodyText = ""
    kind = type
    createSheet = true
  }
  private var createForm: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(kind == "entity" ? "Create an entity" : "Capture a thought").font(
        .system(size: 24, weight: .medium))
      TextField("Title", text: $title).textFieldStyle(.roundedBorder)
      if kind == "entity" {
        Picker("Type", selection: $category) {
          ForEach(["Characters", "Factions", "Places", "Power systems", "Cosmology"], id: \.self) {
            Text($0).tag($0)
          }
        }
      }
      TextEditor(text: $bodyText).font(.system(size: 15)).frame(height: 160)
      if let id = editingCardID, let card = board.document.cards.first(where: { $0.id == id }),
        let data = card.image.flatMap({ Data(base64Encoded: $0) }),
        let image = ImageCache.image(data)
      {
        Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 180)
      }
      Text(
        editingCardID == nil
          ? "Saved as a draft in your world library." : "Changes are saved to this canvas card."
      ).font(.system(size: 13)).foregroundStyle(
        studio.t.secondary)
      HStack {
        Button("Cancel") { createSheet = false }
        Spacer()
        Button(editingCardID == nil ? "Create draft" : "Save card") {
          if let editingCardID {
            board.mutate { doc in
              if let index = doc.cards.firstIndex(where: { $0.id == editingCardID }) {
                doc.cards[index].text = bodyText.isEmpty ? title : bodyText
              }
            }
          } else {
            board.create(
              title: title, body: bodyText, kind: kind,
              category: kind == "entity" ? category : "Ideas")
          }
          if studio.error == nil { createSheet = false }
        }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 440).background(studio.t.background).foregroundStyle(studio.t.text)
  }
  private var libraryPicker: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text("Add from your world").font(.system(size: 23, weight: .medium))
        Spacer()
        Button("Done") { showLibrary = false }
      }
      ScrollView {
        VStack(spacing: 8) {
          ForEach(studio.records) { record in
            Button {
              board.add(record)
            } label: {
              HStack {
                Image(systemName: categoryIcon(record.category))
                Text(record.title)
                Spacer()
                Image(
                  systemName: board.document.cards.contains { $0.recordID == record.id }
                    ? "checkmark" : "plus")
              }.padding(12)
            }.buttonStyle(.plain)
          }
        }
      }.frame(height: 300)
      if studio.records.isEmpty { Text("Create a document or entity in Library first.") }
    }.padding(24).frame(width: 440).background(studio.t.background).foregroundStyle(studio.t.text)
  }
  private var connectionForm: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(editingRelation != nil || editingLocal != nil ? "Relationship" : "Connect the pieces")
        .font(.system(size: 24, weight: .medium))
      Text("\(sourceTitle) → \(targetTitle)").font(.system(size: 15)).foregroundStyle(
        studio.t.secondary)
      TextField("Relationship · e.g. guided by", text: $edgeLabel).textFieldStyle(.roundedBorder)
      Text(
        realEntityPair
          ? "A draft entity relationship, shared with Knowledge Graph."
          : "A board connection. It does not establish a lore relationship."
      ).font(.system(size: 13)).foregroundStyle(studio.t.secondary)
      HStack {
        Button("Cancel") {
          connectionSheet = false
          connectSource = nil
          connectTarget = nil
          tool = "Select"
        }
        if editingRelation != nil || editingLocal != nil { Button("Remove") { removeEdge() } }
        Spacer()
        Button("Save relationship") { saveEdge() }.disabled(
          edgeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 460).background(studio.t.background).foregroundStyle(studio.t.text)
  }
  private var sourceCard: CanvasCard? { board.document.cards.first { $0.id == connectSource } }
  private var targetCard: CanvasCard? { board.document.cards.first { $0.id == connectTarget } }
  private var sourceTitle: String {
    sourceCard.flatMap { card in studio.records.first { $0.id == card.recordID }?.title ?? card.text
    } ?? "Source"
  }
  private var targetTitle: String {
    targetCard.flatMap { card in studio.records.first { $0.id == card.recordID }?.title ?? card.text
    } ?? "Target"
  }
  private var realEntityPair: Bool {
    [sourceCard?.recordID, targetCard?.recordID].allSatisfy { id in
      studio.records.contains { $0.id == id && $0.kind == "entity" }
    }
  }
  private func saveEdge() {
    studio.perform {
      if let editingRelation {
        try studio.store.updateRelation(
          worldID: studio.worldID, id: editingRelation.id, label: edgeLabel)
      } else if let editingLocal {
        board.mutate { $0.edges[editingLocal].label = edgeLabel }
      } else if realEntityPair, let source = sourceCard?.recordID, let target = targetCard?.recordID
      {
        _ = try studio.store.addRelation(
          worldID: studio.worldID, source: source, target: target, label: edgeLabel)
      } else if let connectSource, let connectTarget {
        board.mutate {
          $0.edges.append(
            CanvasEdge(label: edgeLabel, source: connectSource, target: connectTarget))
        }
      }
      board.refreshRelations()
      connectionSheet = false
      connectSource = nil
      connectTarget = nil
      tool = "Select"
    }
  }
  private func removeEdge() {
    studio.perform {
      if let editingRelation {
        try studio.store.archiveRelation(worldID: studio.worldID, id: editingRelation.id)
        archivedRelation = editingRelation.id
      } else if let editingLocal {
        board.mutate { $0.edges.remove(at: editingLocal) }
      }
      board.refreshRelations()
      connectionSheet = false
      connectSource = nil
      connectTarget = nil
    }
  }
  private func inspect(_ edge: DisplayEdge) {
    connectSource = edge.source
    connectTarget = edge.target
    edgeLabel = edge.label
    editingRelation = board.relationships.first { $0.id == edge.id }
    editingLocal = edge.localIndex
    connectionSheet = true
  }
  private var visualEdges: [DisplayEdge] {
    var edges = board.relationships.compactMap { relation -> DisplayEdge? in
      guard let a = board.document.cards.first(where: { $0.recordID == relation.sourceID }),
        let b = board.document.cards.first(where: { $0.recordID == relation.targetID })
      else { return nil }
      return DisplayEdge(id: relation.id, source: a.id, target: b.id, label: relation.label)
    }
    edges += board.document.edges.enumerated().map {
      DisplayEdge(
        id: "local-\($0.offset)", source: $0.element.source, target: $0.element.target,
        label: $0.element.label ?? "Board link", localIndex: $0.offset)
    }
    return edges
  }
}
struct DisplayEdge: Identifiable {
  var id: String
  var source: String
  var target: String
  var label: String
  var localIndex: Int?
}

struct EntityCanvasCard: View {
  @ObservedObject var studio: Studio
  let card: CanvasCard
  var selected: Bool
  var related: Bool
  var open: () -> Void
  var select: () -> Void
  var connect: () -> Void
  @State private var hover = false
  var record: LoreRecord? { studio.records.first { $0.id == card.recordID } }
  var semantic: Color {
    switch record?.category.lowercased() {
    case "characters": return Color(hex: studio.dark ? 0xD7B899 : 0x866042)
    case "factions": return Color(hex: studio.dark ? 0xB7B6E0 : 0x70649C)
    case "power systems": return Color(hex: studio.dark ? 0xD4C48F : 0x807036)
    default: return studio.t.accent
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let data = card.image.flatMap({ Data(base64Encoded: $0) }),
        let image = ImageCache.image(data)
      {
        Image(nsImage: image).resizable().scaledToFill().frame(height: 120).clipped()
      }
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: categoryIcon(record?.category ?? "")).foregroundStyle(semantic)
          Text(
            record?.category.isEmpty == false
              ? record!.category : record?.kind == "capture" ? "Note" : "Reference"
          ).font(.system(size: 12, weight: .medium)).foregroundStyle(semantic)
          Spacer()
          Button(action: open) {
            Image(systemName: "arrow.up.right").font(.system(size: 13)).foregroundStyle(
              studio.t.secondary)
          }.buttonStyle(.plain).help("Open \(record?.title ?? card.text)")
        }
        Text(record?.title ?? card.text).font(.system(size: 17, weight: .semibold)).foregroundStyle(
          studio.t.text
        ).lineLimit(2)
        if let record, !record.body.isEmpty {
          Text(record.body).font(.system(size: 14)).lineSpacing(4).foregroundStyle(
            studio.t.secondary
          ).lineLimit(4)
        }
        HStack(spacing: 6) {
          Circle().fill(record?.state == "canon" ? Color(hex: 0x85B69B) : semantic).frame(
            width: 5, height: 5)
          Text(record?.state == "canon" ? "Canon" : "Draft").font(
            .system(size: 12, weight: .medium))
          Spacer()
          if record?.canonical != nil && record?.state != "canon" {
            Text("Canon preserved").font(.system(size: 11))
          }
          Button(action: connect) { Image(systemName: "plus.circle").font(.system(size: 16)) }
            .buttonStyle(.plain).help("Connect \(record?.title ?? card.text)")
        }.foregroundStyle(studio.t.secondary).padding(.top, 2)
      }.padding(18)
    }.background(studio.t.surface, in: RoundedRectangle(cornerRadius: 12)).clipShape(
      RoundedRectangle(cornerRadius: 12)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12).stroke(
        selected ? semantic : studio.t.border.opacity(hover ? 1 : 0.7),
        lineWidth: selected ? 1.6 : 0.8)
    )
    .shadow(color: .black.opacity(studio.dark ? 0.18 : 0.05), radius: hover ? 16 : 8, y: 4)
    .opacity(related ? 1 : 0.70).contentShape(RoundedRectangle(cornerRadius: 12))
    .onTapGesture(count: 2, perform: open).onTapGesture(perform: select)
    .onHover { value in withAnimation(.easeOut(duration: 0.15)) { hover = value } }
    .accessibilityElement(children: .contain).accessibilityLabel(record?.title ?? card.text)
  }
}
@MainActor enum ImageCache {
  static let cache = NSCache<NSData, NSImage>()
  static func image(_ data: Data) -> NSImage? {
    let key = data as NSData
    if let image = cache.object(forKey: key) { return image }
    guard let image = NSImage(data: data) else { return nil }
    cache.countLimit = 40
    cache.setObject(image, forKey: key)
    return image
  }
}
