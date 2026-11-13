import SwiftUI
import SynthesisCore

/// Deterministic force-directed placement. The same entities and relationships always produce
/// the same picture; nothing here is stored, because the graph is derived from the world.
enum GraphLayout {
  /// Fruchterman–Reingold inside a frame shaped like the workspace, so chains fold to fill the
  /// available area instead of stretching into a line.
  static func positions(nodes: [String], edges: [(String, String)], landscape: Bool = true)
    -> [String: CGPoint]
  {
    guard !nodes.isEmpty else { return [:] }
    if nodes.count == 1 { return [nodes[0]: .zero] }
    let k = 175.0
    let count = Double(nodes.count)
    let area = count * k * k * 1.35
    let long = (area * 1.7).squareRoot()
    let short = area / long
    let half = CGSize(width: (landscape ? long : short) / 2, height: (landscape ? short : long) / 2)
    var points: [CGPoint] = nodes.indices.map { i in
      let angle = Double(i) / count * 2 * .pi - .pi / 2
      return CGPoint(x: cos(angle) * half.width * 0.8, y: sin(angle) * half.height * 0.8)
    }
    let index = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1, $0) })
    let links = edges.compactMap { edge -> (Int, Int)? in
      guard let a = index[edge.0], let b = index[edge.1], a != b else { return nil }
      return (a, b)
    }
    var temperature = long / 8
    for _ in 0..<300 {
      var shift = Array(repeating: CGVector.zero, count: nodes.count)
      for i in nodes.indices {
        for j in nodes.indices where j > i {
          var dx = points[i].x - points[j].x
          var dy = points[i].y - points[j].y
          if dx == 0 && dy == 0 {
            dx = 0.01 * Double(i + 1)
            dy = 0.01
          }
          let distance = max(1, hypot(dx, dy))
          let force = k * k / distance
          shift[i].dx += dx / distance * force
          shift[i].dy += dy / distance * force
          shift[j].dx -= dx / distance * force
          shift[j].dy -= dy / distance * force
        }
      }
      for (a, b) in links {
        let dx = points[a].x - points[b].x
        let dy = points[a].y - points[b].y
        let distance = max(1, hypot(dx, dy))
        let force = distance * distance / k
        shift[a].dx -= dx / distance * force
        shift[a].dy -= dy / distance * force
        shift[b].dx += dx / distance * force
        shift[b].dy += dy / distance * force
      }
      for i in nodes.indices {
        let length = max(1, hypot(shift[i].dx, shift[i].dy))
        points[i].x += shift[i].dx / length * min(length, temperature)
        points[i].y += shift[i].dy / length * min(length, temperature)
        points[i].x = min(half.width, max(-half.width, points[i].x))
        points[i].y = min(half.height, max(-half.height, points[i].y))
      }
      temperature = max(1, temperature * 0.975)
    }
    let cx = (points.map(\.x).max()! + points.map(\.x).min()!) / 2
    let cy = (points.map(\.y).max()! + points.map(\.y).min()!) / 2
    return Dictionary(
      uniqueKeysWithValues: nodes.indices.map {
        (nodes[$0], CGPoint(x: points[$0].x - cx, y: points[$0].y - cy))
      })
  }
}

struct RelationshipGraph: View {
  enum Panel: String, Identifiable {
    case create, edit
    var id: String { rawValue }
  }
  @ObservedObject var studio: Studio
  @State private var relationships: [Relation] = []
  @State private var layout: [String: CGPoint] = [:]
  @State private var signature = ""
  @State private var query = ""
  @State private var selected: String?
  @State private var hoveredEdge: String?
  @State private var zoom = 1.0
  @State private var pan = CGSize.zero
  @State private var panAnchor: CGPoint?
  @State private var dragNode: (id: String, origin: CGPoint)?
  @State private var area = CGSize(width: 900, height: 600)
  @State private var panel: Panel?
  @State private var source = ""
  @State private var target = ""
  @State private var label = ""
  @State private var editing: Relation?
  @State private var framed = false
  private var entities: [LoreRecord] { studio.records.filter { $0.kind == "entity" } }
  private func matches(_ entity: LoreRecord) -> Bool {
    query.isEmpty || entity.title.localizedCaseInsensitiveContains(query)
      || entity.category.localizedCaseInsensitiveContains(query)
  }
  var body: some View {
    let nodes = entities
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: Destination.knowledge.icon, title: "Graph",
          detail:
            "\(nodes.count) \(nodes.count == 1 ? "entity" : "entities") · \(relationships.count) \(relationships.count == 1 ? "relationship" : "relationships")",
          t: studio.t)
      } trailing: {
        SearchField(text: $query, placeholder: "Find an entity", t: studio.t)
          .frame(minWidth: 120, idealWidth: 200, maxWidth: 200)
        BarAction(
          title: selected == nil ? "Copy to canvas" : "Copy neighbourhood",
          icon: "rectangle.on.rectangle", t: studio.t,
          help: "Create an editable board from what is shown. The graph itself is not changed."
        ) { transferToCanvas() }.disabled(nodes.isEmpty)
        BarAction(
          title: "Relationship", icon: "plus", t: studio.t, primary: true,
          help: nodes.count < 2 ? "Create two entities first" : "Connect two entities"
        ) {
          source = selected ?? nodes.first?.id ?? ""
          target = nodes.first { $0.id != source }?.id ?? ""
          label = ""
          panel = .create
        }.disabled(nodes.count < 2)
      }
      if nodes.isEmpty {
        EmptyState(
          icon: Destination.knowledge.icon, title: "No entities yet",
          message:
            "The graph draws itself from the characters, factions and places you create and the relationships between them.",
          t: studio.t
        ) {
          Button("New entity") {
            studio.newRecordKind = "entity"
            studio.sheet = .document
          }.buttonStyle(QuietButton(t: studio.t, primary: true))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        GeometryReader { outer in
          // Wide windows dock the details beside the graph; narrow ones float them over it.
          let docked = outer.size.width >= 860
          HStack(spacing: 0) {
            graph(nodes, floating: !docked)
            if docked, let entity = nodes.first(where: { $0.id == selected }) {
              Rectangle().fill(studio.t.hairline).frame(width: 1)
              ScrollView { detail(entity, docked: true) }.frame(width: 300)
                .background(studio.t.sidebar.opacity(0.45))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
          }.animation(.easeOut(duration: 0.16), value: selected)
        }
      }
    }
    .onAppear {
      refresh()
      if studio.captureHint == "graph-selected" {
        selected = entities.first { $0.title == "Mira Vale" }?.id
      } else if studio.captureHint == "sheet-relation" {
        source = entities.first { $0.title == "Oren Ashe" }?.id ?? ""
        target = entities.first { $0.title == "The Glass Sea" }?.id ?? ""
        label = "fears"
        panel = .create
      }
    }
    .onChange(of: studio.records) { _, _ in refresh() }
    .sheet(item: $panel) { item in
      switch item {
      case .create: createSheet
      case .edit: editSheet
      }
    }
  }

  // MARK: Drawing

  private func point(_ id: String, _ size: CGSize) -> CGPoint {
    let world = layout[id] ?? .zero
    return CGPoint(
      x: size.width / 2 + world.x * zoom + pan.width,
      y: size.height / 2 + world.y * zoom + pan.height)
  }
  private func emphasized(_ edge: Relation) -> Bool {
    hoveredEdge == edge.id || selected == nil || selected == edge.sourceID
      || selected == edge.targetID
  }
  private func curve(_ edge: Relation, _ size: CGSize, lanes: [String: Double])
    -> (start: CGPoint, control: CGPoint, end: CGPoint)?
  {
    guard layout[edge.sourceID] != nil, layout[edge.targetID] != nil else { return nil }
    let a = point(edge.sourceID, size)
    let b = point(edge.targetID, size)
    let distance = max(1, hypot(b.x - a.x, b.y - a.y))
    let unit = CGVector(dx: (b.x - a.x) / distance, dy: (b.y - a.y) / distance)
    // Keep a stable normal for both directions of a pair so opposite edges bow apart.
    let flip: Double = edge.sourceID < edge.targetID ? 1 : -1
    let normal = CGVector(dx: -unit.dy * flip, dy: unit.dx * flip)
    let lane = lanes[edge.id] ?? 0
    let start = CGPoint(x: a.x + unit.dx * 27, y: a.y + unit.dy * 27)
    let end = CGPoint(x: b.x - unit.dx * 30, y: b.y - unit.dy * 30)
    let control = CGPoint(
      x: (start.x + end.x) / 2 + normal.dx * lane * 1.9,
      y: (start.y + end.y) / 2 + normal.dy * lane * 1.9)
    return (start, control, end)
  }
  private func graph(_ nodes: [LoreRecord], floating: Bool) -> some View {
    GeometryReader { geo in
      let lanes = edgeLanes(
        relationships.map {
          DisplayEdge(id: $0.id, source: $0.sourceID, target: $0.targetID, label: $0.label)
        }, spacing: 30)
      ZStack {
        Canvas { context, size in
          for edge in relationships {
            guard let c = curve(edge, size, lanes: lanes) else { continue }
            let strong = emphasized(edge)
            let color = studio.t.accent.opacity(strong ? (hoveredEdge == edge.id ? 1 : 0.7) : 0.16)
            var path = Path()
            path.move(to: c.start)
            path.addQuadCurve(to: c.end, control: c.control)
            context.stroke(
              path, with: .color(color),
              style: StrokeStyle(lineWidth: hoveredEdge == edge.id ? 2 : 1.4, lineCap: .round))
            let angle = atan2(c.end.y - c.control.y, c.end.x - c.control.x)
            var arrow = Path()
            arrow.move(to: c.end)
            arrow.addLine(
              to: CGPoint(x: c.end.x - cos(angle - 0.42) * 9, y: c.end.y - sin(angle - 0.42) * 9))
            arrow.addLine(
              to: CGPoint(x: c.end.x - cos(angle + 0.42) * 9, y: c.end.y - sin(angle + 0.42) * 9))
            arrow.closeSubpath()
            context.fill(arrow, with: .color(color))
          }
        }.allowsHitTesting(false)
        CanvasInputSurface(
          onPan: {
            pan.width += $0.width
            pan.height += $0.height
          },
          onZoom: { factor, location in
            let next = min(2.2, max(0.4, zoom * factor))
            let ratio = next / zoom
            let anchor = CGPoint(
              x: location.x - geo.size.width / 2, y: location.y - geo.size.height / 2)
            pan.width = anchor.x - (anchor.x - pan.width) * ratio
            pan.height = anchor.y - (anchor.y - pan.height) * ratio
            zoom = next
          },
          onClick: { selected = nil },
          onDrag: { start, current, phase in
            let last = panAnchor ?? start
            pan.width += current.x - last.x
            pan.height += current.y - last.y
            panAnchor = phase == .ended ? nil : current
          },
          onKey: { event in
            guard event.keyCode == 53 else { return false }
            selected = nil
            return true
          })
        ForEach(relationships) { edge in
          if let c = curve(edge, geo.size, lanes: lanes),
            hypot(c.end.x - c.start.x, c.end.y - c.start.y) > 54 || hoveredEdge == edge.id
          {
            let strong = emphasized(edge)
            Button {
              editing = edge
              label = edge.label
              panel = .edit
            } label: {
              Text(edge.label).font(.system(size: 12, weight: .medium)).lineLimit(1)
                .foregroundStyle(strong ? studio.t.accent : studio.t.muted)
                .padding(.horizontal, 8).frame(height: 22)
                .background(studio.t.background, in: Capsule())
                .overlay(
                  Capsule().stroke(
                    hoveredEdge == edge.id ? studio.t.accent.opacity(0.8) : studio.t.border,
                    lineWidth: 1))
            }.buttonStyle(.plain).opacity(strong ? 1 : 0.45)
              .help("\(name(edge.sourceID)) \(edge.label) \(name(edge.targetID)). Click to edit.")
              .onHover { hoveredEdge = $0 ? edge.id : (hoveredEdge == edge.id ? nil : hoveredEdge) }
              .position(
                x: (c.start.x + 2 * c.control.x + c.end.x) / 4,
                y: (c.start.y + 2 * c.control.y + c.end.y) / 4)
          }
        }
        ForEach(nodes) { entity in node(entity, size: geo.size) }
        if relationships.isEmpty {
          Text("Connect two entities to draw the first relationship.")
            .font(.system(size: 13)).foregroundStyle(studio.t.secondary)
            .padding(.horizontal, 14).frame(height: 34).floatingPanel(studio.t)
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 14)
        }
        VStack {
          if floating, let entity = nodes.first(where: { $0.id == selected }) {
            detail(entity, docked: false).frame(maxWidth: .infinity, alignment: .trailing)
              .transition(.opacity)
          }
          Spacer(minLength: 0)
          HStack {
            Spacer()
            ZoomControls(
              zoom: zoom, t: studio.t, zoomOut: { zoom = max(0.4, zoom / 1.2) },
              zoomIn: { zoom = min(2.2, zoom * 1.2) }, fit: { frame(geo.size) })
          }
        }.padding(14).animation(.easeOut(duration: 0.14), value: selected)
      }
      .coordinateSpace(name: "graph").clipped()
      .onAppear {
        area = geo.size
        refresh()
        if !framed {
          framed = true
          frame(geo.size, animated: false)
        }
      }
      .onChange(of: geo.size) { old, size in
        area = size
        if (old.width >= old.height) != (size.width >= size.height) {
          refresh()
        } else if abs(old.width - size.width) > 80 {
          // Docking or hiding the details changes the room available; keep everything in view.
          frame(size)
        }
      }
    }
  }
  private func node(_ entity: LoreRecord, size: CGSize) -> some View {
    let tint = studio.t.category(entity.category)
    let isSelected = selected == entity.id
    let neighbour =
      selected == nil || isSelected
      || relationships.contains {
        ($0.sourceID == selected && $0.targetID == entity.id)
          || ($0.targetID == selected && $0.sourceID == entity.id)
      }
    let dim = !neighbour || !matches(entity)
    return VStack(spacing: 7) {
      Image(systemName: recordIcon(entity)).font(.system(size: 17)).foregroundStyle(tint)
        .frame(width: 46, height: 46).background(studio.t.surface, in: Circle())
        .overlay(
          Circle().stroke(tint.opacity(isSelected ? 1 : 0.45), lineWidth: isSelected ? 2 : 1.2)
        )
        .shadow(color: studio.t.shadow.opacity(0.4), radius: 6, y: 2)
      // The backing hugs the text so it never hides a neighbouring relationship label.
      Text(entity.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
        .multilineTextAlignment(.center).padding(.horizontal, 4).padding(.vertical, 1)
        .background(studio.t.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
        .frame(width: 140)
    }
    .opacity(dim ? 0.35 : 1)
    .contentShape(Rectangle())
    .onTapGesture {
      if NSApp.currentEvent?.clickCount == 2 {
        studio.openRecord(entity)
      } else {
        selected = isSelected ? nil : entity.id
      }
    }
    .gesture(
      DragGesture(minimumDistance: 4, coordinateSpace: .named("graph"))
        .onChanged { value in
          if dragNode?.id != entity.id { dragNode = (entity.id, layout[entity.id] ?? .zero) }
          guard let origin = dragNode?.origin else { return }
          layout[entity.id] = CGPoint(
            x: origin.x + value.translation.width / zoom,
            y: origin.y + value.translation.height / zoom)
        }
        .onEnded { _ in dragNode = nil }
    )
    .position(x: point(entity.id, size).x, y: point(entity.id, size).y + 14)
    .contextMenu {
      Button("Open record") { studio.openRecord(entity) }
      Button("Connect from here…") {
        source = entity.id
        target = entities.first { $0.id != entity.id }?.id ?? ""
        label = ""
        panel = .create
      }.disabled(entities.count < 2)
    }
    .help(entity.title)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(entity.category.isEmpty ? "Entity" : entity.category): \(entity.title)")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
  @ViewBuilder private func detail(_ entity: LoreRecord, docked: Bool) -> some View {
    if docked {
      detailContent(entity).padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain).accessibilityLabel("Entity details")
    } else {
      detailContent(entity).padding(14).frame(width: 290)
        .floatingPanel(studio.t, radius: Metric.cardRadius)
    }
  }
  private func detailContent(_ entity: LoreRecord) -> some View {
    let related = relationships.filter { $0.sourceID == entity.id || $0.targetID == entity.id }
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        CategoryTile(record: entity, t: studio.t, size: 32)
        VStack(alignment: .leading, spacing: 3) {
          Text(entity.title).font(.system(size: 15, weight: .semibold)).lineLimit(2)
          HStack(spacing: 8) {
            if !entity.category.isEmpty {
              Text(entity.category).font(.system(size: 12)).foregroundStyle(studio.t.muted)
            }
            StateBadge(state: entity.state, t: studio.t)
          }
        }
        Spacer(minLength: 0)
        IconButton(icon: "xmark", label: "Clear selection", t: studio.t, size: 22) {
          selected = nil
        }
      }
      if !entity.body.isEmpty {
        Text(entity.body).font(.system(size: 13)).lineSpacing(3).foregroundStyle(studio.t.secondary)
          .lineLimit(4).fixedSize(horizontal: false, vertical: true)
      }
      if !related.isEmpty {
        VStack(alignment: .leading, spacing: 1) {
          ForEach(related) { relation in
            let outward = relation.sourceID == entity.id
            let other = outward ? relation.targetID : relation.sourceID
            Button {
              selected = other
            } label: {
              HStack(spacing: 6) {
                Image(systemName: outward ? "arrow.right" : "arrow.left")
                  .font(.system(size: 9, weight: .bold)).foregroundStyle(studio.t.muted)
                Text(relation.label).font(.system(size: 12.5)).foregroundStyle(studio.t.secondary)
                Text(name(other)).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
              }.padding(.horizontal, 7).frame(height: 26).hoverFill(studio.t, radius: 6)
            }.buttonStyle(.plain)
          }
        }.padding(.horizontal, -7)
      }
      HStack(spacing: 6) {
        Button("Open record") { studio.openRecord(entity) }
          .buttonStyle(QuietButton(t: studio.t, primary: true))
        Button("Copy neighbourhood") { transferToCanvas() }.buttonStyle(QuietButton(t: studio.t))
      }
    }
  }
  private func name(_ id: String) -> String {
    studio.records.first { $0.id == id }?.title ?? "Unknown"
  }

  // MARK: Data

  private func refresh() {
    studio.perform {
      relationships = try studio.store.relations(worldID: studio.worldID)
      let nodes = entities.map(\.id).sorted()
      let landscape = area.width >= area.height
      let next =
        nodes.joined(separator: ",") + "|\(landscape)|"
        + relationships.map { "\($0.sourceID)>\($0.targetID)" }.sorted().joined(separator: ",")
      if next != signature {
        signature = next
        layout = GraphLayout.positions(
          nodes: nodes, edges: relationships.map { ($0.sourceID, $0.targetID) },
          landscape: landscape)
        if framed { frame(area, animated: false) }
      }
      if let selected, !nodes.contains(selected) { self.selected = nil }
    }
  }
  /// Centres and scales the whole graph into the visible area.
  private func frame(_ size: CGSize, animated: Bool = true) {
    guard !layout.isEmpty else { return }
    let xs = layout.values.map(\.x)
    let ys = layout.values.map(\.y)
    let width = (xs.max()! - xs.min()!) + 250
    let height = (ys.max()! - ys.min()!) + 190
    // Below 60% labels collide; keep them readable and let the creator pan instead.
    let scale = min(1.2, max(0.6, min(size.width / width, (size.height - 40) / height)))
    let apply = {
      zoom = scale
      pan = CGSize(
        width: -(xs.max()! + xs.min()!) / 2 * scale,
        height: -(ys.max()! + ys.min()!) / 2 * scale - 10)
    }
    if animated { withAnimation(.easeOut(duration: 0.2)) { apply() } } else { apply() }
  }
  private func transferToCanvas() {
    studio.perform {
      var ids = Set(entities.filter(matches).map(\.id))
      var title = "Graph copy"
      if let selected {
        ids = [selected]
        for relation in relationships
        where relation.sourceID == selected || relation.targetID == selected {
          ids.insert(relation.sourceID)
          ids.insert(relation.targetID)
        }
        title = "Around \(name(selected))"
      }
      var document = CanvasDocument()
      // Keep the graph's arrangement so the board opens looking like what was copied.
      document.cards = entities.filter { ids.contains($0.id) }.map { record in
        var card = CanvasCard(text: record.title, recordID: record.id)
        card.width = 300
        card.x = (layout[record.id]?.x ?? 0) * 1.9
        card.y = (layout[record.id]?.y ?? 0) * 1.5
        return card
      }
      let data = try JSONEncoder().encode(document)
      let board = try studio.store.saveBoard(
        worldID: studio.worldID, name: title, kind: "canvas",
        content: String(decoding: data, as: UTF8.self))
      studio.canvasBoardID = board.id
      studio.navigate(.canvas)
      studio.show("Copied to a new board. Moving cards there never changes the graph.")
    }
  }

  // MARK: Sheets

  private var suggestions: [String] {
    Array(Set(relationships.map(\.label))).sorted().prefix(6).map { $0 }
  }
  private func picker(_ title: String, selection: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
      PlainMenu {
        ForEach(entities) { entity in Button(entity.title) { selection.wrappedValue = entity.id } }
      } label: {
        HStack {
          Text(name(selection.wrappedValue)).font(.system(size: 14)).lineLimit(1)
          Spacer()
          Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
            .foregroundStyle(studio.t.muted)
        }.padding(.horizontal, 10).frame(width: 196, height: 34)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(
            RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.border, lineWidth: 1))
      }
    }
  }
  private func closePanel() { panel = nil }
  private var createSheet: some View {
    let valid = source != target && !label.trimmingCharacters(in: .whitespaces).isEmpty
    let save = {
      studio.perform {
        _ = try studio.store.addRelation(
          worldID: studio.worldID, source: source, target: target,
          label: label.trimmingCharacters(in: .whitespacesAndNewlines))
        panel = nil
        refresh()
      }
    }
    return SheetScaffold(title: "New relationship", t: studio.t, close: closePanel) {
      HStack(alignment: .bottom, spacing: 10) {
        picker("From", selection: $source)
        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
          .foregroundStyle(studio.t.muted).padding(.bottom, 11)
        picker("To", selection: $target)
      }
      FormField(
        label: "How are they connected?", placeholder: "guided by, rules, born in…", text: $label,
        t: studio.t, submit: { if valid { save() } })
      if !suggestions.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(suggestions, id: \.self) { value in
              FilterChip(title: value, selected: label == value, t: studio.t) { label = value }
            }
          }
        }.scrollIndicators(.never)
      }
      Text("Saved as a draft relationship. It is not canon.").font(.system(size: 12.5))
        .foregroundStyle(studio.t.muted)
    } footer: {
      Spacer()
      Button("Cancel") { panel = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Connect", action: save).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction).disabled(!valid)
    }
  }
  @ViewBuilder private var editSheet: some View {
    if let relation = editing {
      RelationEditor(
        t: studio.t, title: "Edit relationship", source: name(relation.sourceID),
        target: name(relation.targetID), label: $label,
        note: "A draft relationship between two entities. Changes are recorded in its history.",
        suggestions: suggestions, removable: true,
        save: {
          studio.perform {
            try studio.store.updateRelation(worldID: studio.worldID, id: relation.id, label: label)
            panel = nil
            refresh()
          }
        },
        remove: {
          studio.perform {
            try studio.store.archiveRelation(worldID: studio.worldID, id: relation.id)
            panel = nil
            refresh()
            studio.show("Removed “\(relation.label)”", icon: "minus.circle", actionTitle: "Undo") {
              studio.perform {
                try studio.store.restoreRelation(worldID: studio.worldID, id: relation.id)
                refresh()
              }
            }
          }
        }, cancel: { panel = nil })
    }
  }
}
