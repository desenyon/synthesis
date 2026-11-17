import SwiftUI
import SynthesisCore

struct RelationshipGraph: View {
  enum Panel: String, Identifiable {
    case edit
    var id: String { rawValue }
  }
  @ObservedObject var studio: Studio
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.controlActiveState) private var controlActiveState
  @State private var relationships: [Relation] = []
  @State private var artworkIDs: [String: String] = [:]
  private var detailLevel: GraphDetail { GraphDetail(scale: zoom) }
  private var layout: [String: CGPoint] {
    get { studio.graphView.positions }
    nonmutating set { studio.graphView.positions = newValue }
  }
  private var layoutLandscape: Bool? {
    get { studio.graphView.landscape }
    nonmutating set { studio.graphView.landscape = newValue }
  }
  private var signature: String {
    get { studio.graphView.signature }
    nonmutating set { studio.graphView.signature = newValue }
  }
  @State private var layoutTask: Task<Void, Never>?
  @State private var layoutWorldID: String?
  @State private var pendingSignature: String?
  private var query: String {
    get { studio.graphView.query }
    nonmutating set { studio.graphView.query = newValue }
  }
  private var selected: String? {
    get { studio.graphSelectedID }
    nonmutating set { studio.graphSelectedID = newValue }
  }
  @State private var connecting: String?
  @State private var hoveredEdge: String?
  private var zoom: Double {
    get { studio.graphView.zoom }
    nonmutating set { studio.graphView.zoom = newValue }
  }
  private var pan: CGSize {
    get { studio.graphView.pan }
    nonmutating set { studio.graphView.pan = newValue }
  }
  @State private var panAnchor: CGPoint?
  @State private var dragNode: (id: String, origin: CGPoint)?
  @State private var area = CGSize(width: 900, height: 600)
  @State private var panel: Panel?
  @State private var label = ""
  @State private var editing: Relation?
  private var framed: Bool {
    get { studio.graphView.framed }
    nonmutating set { studio.graphView.framed = newValue }
  }
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
        SearchField(text: $studio.graphView.query, placeholder: "Find an entity", t: studio.t)
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
          beginRelationship(from: selected ?? nodes.first?.id ?? "")
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
        graph(nodes)
      }
    }
    .onAppear {
      if studio.captureHint == "graph-selected" {
        selected = entities.first { $0.title == "Mira Vale" }?.id
      } else if studio.captureHint == "sheet-relation" {
        studio.beginRelationship(
          sourceID: entities.first { $0.title == "Oren Ashe" }?.id,
          targetID: entities.first { $0.title == "The Glass Sea" }?.id, entitiesOnly: true)
        studio.recordLinkDraft?.label = "fears"
      }
    }
    .onChange(of: selected) { _, _ in hoveredEdge = nil }
    .onChange(of: controlActiveState) { _, _ in hoveredEdge = nil }
    .onChange(of: studio.worldRevision) { _, _ in refresh() }
    .onDisappear {
      layoutTask?.cancel()
      layoutTask = nil
      pendingSignature = nil
      hoveredEdge = nil
      connecting = nil
    }
    .studioSheet(item: $panel) { item in
      switch item {
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
  private func curve(_ edge: Relation, _ size: CGSize, lanes: [String: Double]) -> GraphRoute? {
    guard layout[edge.sourceID] != nil, layout[edge.targetID] != nil else { return nil }
    return GraphRoute.between(
      point(edge.sourceID, size), point(edge.targetID, size),
      scale: zoom, lane: (lanes[edge.id] ?? 0) * zoom, cardSize: detailLevel.cardSize,
      obstacles: layout.keys.filter { $0 != edge.sourceID && $0 != edge.targetID }.map {
        let centre = point($0, size)
        return CGRect(
          x: centre.x - detailLevel.cardSize.width * zoom / 2,
          y: centre.y - detailLevel.cardSize.height * zoom / 2,
          width: detailLevel.cardSize.width * zoom, height: detailLevel.cardSize.height * zoom)
      })
  }
  private func graph(_ nodes: [LoreRecord]) -> some View {
    GeometryReader { geo in
      let lanes = edgeLanes(
        relationships.map {
          DisplayEdge(id: $0.id, source: $0.sourceID, target: $0.targetID, label: $0.label)
        }, spacing: 30)
      let routes = Dictionary(
        uniqueKeysWithValues: relationships.compactMap { edge in
          curve(edge, geo.size, lanes: lanes).map { (edge.id, $0) }
        })
      ZStack {
        Canvas { context, size in
          for edge in relationships {
            guard let c = routes[edge.id] else { continue }
            let strong = emphasized(edge)
            let color = studio.t.accent.opacity(strong ? (hoveredEdge == edge.id ? 1 : 0.7) : 0.16)
            var path = Path()
            path.move(to: c.start)
            path.addCurve(to: c.end, control1: c.first, control2: c.second)
            context.stroke(
              path, with: .color(color),
              style: StrokeStyle(lineWidth: hoveredEdge == edge.id ? 2 : 1.4, lineCap: .round))
            let angle = atan2(c.end.y - c.second.y, c.end.x - c.second.x)
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
            changeZoom(
              factor,
              anchor: CGPoint(
                x: location.x - geo.size.width / 2, y: location.y - geo.size.height / 2))
          },
          onClick: {
            selected = nil
            connecting = nil
            hoveredEdge = nil
          },
          onDrag: { start, current, phase in
            let last = panAnchor ?? start
            pan.width += current.x - last.x
            pan.height += current.y - last.y
            panAnchor = phase == .ended ? nil : current
          },
          onKey: { event in
            guard event.keyCode == 53 else { return false }
            selected = nil
            connecting = nil
            return true
          })
        ForEach(relationships) { edge in
          if let route = routes[edge.id] { edgeControl(edge, route: route) }
        }
        ForEach(nodes.filter { visible($0.id, in: geo.size) }) { entity in
          node(entity, size: geo.size)
        }
        if relationships.isEmpty || connecting != nil {
          Text(
            connecting == nil
              ? "Choose a card’s connector to link two entities."
              : "Choose another entity’s connector · Escape to cancel"
          )
          .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
          .padding(.horizontal, 14).frame(height: 34).floatingPanel(studio.t)
          .frame(maxHeight: .infinity, alignment: .top).padding(.top, 14)
        }
        VStack {
          if !studio.focusMode && !studio.workspaceInspector,
            let entity = nodes.first(where: { $0.id == selected })
          {
            detail(entity).frame(
              maxWidth: .infinity, alignment: studio.companionExpanded ? .leading : .trailing
            )
            .id(entity.id).transition(Motion.panelTransition)
          }
          Spacer(minLength: 0)
          HStack {
            Spacer()
            ZoomControls(
              zoom: zoom, t: studio.t, zoomOut: { stepZoom(1 / 1.2) },
              zoomIn: { stepZoom(1.2) }, fit: { frame(geo.size) })
          }
        }.padding(14).animation(reduceMotion ? nil : Motion.panelAnimation, value: selected)
      }
      .background(studio.t.spatialBackground)
      .coordinateSpace(name: "graph").clipped()
      .onAppear {
        area = geo.size
        if !framed { layoutLandscape = area.width >= area.height }
        refresh()
        if !framed {
          framed = true
          frame(geo.size, animated: false)
        }
      }
      .onChange(of: geo.size) { _, size in
        area = size
        // Focus, inspectors and window resizing must not rearrange the universe.
        // Pan is relative to the viewport centre, so the focal point stays put.
      }
    }
  }
  private func visible(_ id: String, in size: CGSize) -> Bool {
    let centre = point(id, size)
    let bounds = CGRect(
      x: centre.x - detailLevel.cardSize.width * zoom / 2,
      y: centre.y - detailLevel.cardSize.height * zoom / 2,
      width: detailLevel.cardSize.width * zoom, height: detailLevel.cardSize.height * zoom)
    return CGRect(origin: .zero, size: size).insetBy(dx: -32, dy: -32).intersects(bounds)
  }

  private func edgeControl(_ edge: Relation, route: GraphRoute) -> some View {
    let strong = emphasized(edge)
    let showLabel = detailLevel.showsRelationship(hovered: hoveredEdge == edge.id)
    let labelWidth = min(200.0, max(60, Double(edge.label.count) * 7 + 16))
    var path = Path()
    path.move(to: route.start)
    path.addCurve(to: route.end, control1: route.first, control2: route.second)
    var hit = path.strokedPath(StrokeStyle(lineWidth: 14))
    // One combined hit region prevents hover flicker when the revealed label covers its edge.
    if showLabel {
      hit.addRoundedRect(
        in: CGRect(
          x: route.middle.x - labelWidth / 2, y: route.middle.y - 11,
          width: labelWidth, height: 22), cornerSize: CGSize(width: 11, height: 11))
    }
    return Button {
      editing = edge
      label = edge.label
      panel = .edit
    } label: {
      ZStack {
        path.stroke(Color.clear, lineWidth: 14)
        if showLabel {
          Text(edge.label).font(.studio(.captionStrong)).lineLimit(1)
            .foregroundStyle(strong ? studio.t.accent : studio.t.muted)
            .padding(.horizontal, 8).frame(height: 22).frame(width: labelWidth)
            .background(studio.t.surface, in: Capsule())
            .overlay(
              Capsule().stroke(
                hoveredEdge == edge.id ? studio.t.accent.opacity(0.8) : studio.t.border,
                lineWidth: 1)
            )
            .opacity(strong ? 1 : 0.45).position(route.middle)
        }
      }.contentShape(hit)
    }.buttonStyle(.plain)
      .accessibilityLabel(
        "\(name(edge.sourceID)) \(edge.label) \(name(edge.targetID)). Edit relationship."
      )
      .help("\(name(edge.sourceID)) \(edge.label) \(name(edge.targetID))")
      .onContinuousHover { phase in
        switch phase {
        case .active: if controlActiveState == .key { hoveredEdge = edge.id }
        case .ended: if hoveredEdge == edge.id { hoveredEdge = nil }
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
    let count = relationships.filter { $0.sourceID == entity.id || $0.targetID == entity.id }.count
    return VStack(alignment: .leading, spacing: 0) {
      if detailLevel == .overview {
        HStack(spacing: 9) {
          StudioIcon(recordIcon(entity), size: max(16, 10 / zoom)).foregroundStyle(tint)
          Text(entity.title).font(.studio(size: max(17, 12 / zoom), weight: .semibold))
            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
          Circle().fill(studio.t.state(entity.state)).frame(width: 6, height: 6)
        }.padding(.horizontal, 14).frame(maxHeight: .infinity)
      } else {
        HStack(spacing: 7) {
          StudioIcon(recordIcon(entity), size: 13).foregroundStyle(tint)
          Text(entity.category.isEmpty ? "Entity" : Vocabulary.displayCategory(entity.category))
            .font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary).lineLimit(1)
          Spacer(minLength: 4)
          IconButton(icon: "arrow.up.forward", label: "Open \(entity.title)", t: studio.t, size: 22)
          {
            studio.openRecord(entity)
          }
        }.padding(.horizontal, 13).frame(height: 30)
        Rectangle().fill(studio.t.hairline).frame(height: 1).padding(.horizontal, 13)
        VStack(alignment: .leading, spacing: 8) {
          Text(entity.title).font(.studio(size: max(17, 12 / zoom), weight: .semibold))
            .tracking(-0.3).lineLimit(detailLevel == .detail ? 2 : 1)
          HStack(alignment: .top, spacing: 10) {
            if detailLevel == .detail, let revision = artworkIDs[entity.id] {
              GraphArtwork(
                store: studio.store, worldID: studio.worldID, recordID: entity.id,
                revision: revision)
            }
            Text(entity.body.isEmpty ? "Open this record to begin writing." : entity.body)
              .font(.studio(size: max(14, 11 / zoom))).foregroundStyle(studio.t.secondary)
              .lineSpacing(3).lineLimit(detailLevel == .detail ? 4 : 1)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }.padding(.horizontal, 14).padding(.vertical, 11)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        HStack {
          Text("\(count) \(count == 1 ? "connection" : "connections")").lineLimit(1)
          Spacer(minLength: 4)
          Circle().fill(studio.t.state(entity.state)).frame(width: 4, height: 4)
          Text(entity.state.capitalized)
        }.font(.studio(size: max(11.5, 9 / zoom))).foregroundStyle(studio.t.secondary)
          .padding(.horizontal, 13).frame(height: 28)
          .overlay(alignment: .top) { Rectangle().fill(studio.t.hairline).frame(height: 1) }
      }
    }.frame(width: detailLevel.cardSize.width, height: detailLevel.cardSize.height)
      .entitySurface(
        studio.t, selected: isSelected, radius: Metric.cardRadius,
        base: studio.t.surface, bordered: true
      )
      .elevation(.card, t: studio.t)
      .overlay(alignment: .leading) { port(entity, tint: tint).offset(x: -6) }
      .overlay(alignment: .trailing) { port(entity, tint: tint).offset(x: 6) }
      .scaleEffect(zoom).frame(
        width: detailLevel.cardSize.width * zoom, height: detailLevel.cardSize.height * zoom
      )
      .opacity(dim ? 0.35 : 1)
      .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: dim)
      .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: isSelected)
      .contentShape(Rectangle())
      .onTapGesture {
        if NSApp.currentEvent?.clickCount == 2 {
          studio.openRecord(entity)
        } else {
          selected = entity.id
        }
      }
      .gesture(
        DragGesture(minimumDistance: 4, coordinateSpace: .named("graph"))
          .onChanged { value in
            if dragNode?.id != entity.id { dragNode = (entity.id, layout[entity.id] ?? .zero) }
            hoveredEdge = nil
            guard let origin = dragNode?.origin else { return }
            layout[entity.id] = CGPoint(
              x: origin.x + value.translation.width / zoom,
              y: origin.y + value.translation.height / zoom)
          }
          .onEnded { _ in dragNode = nil }
      )
      .position(x: point(entity.id, size).x, y: point(entity.id, size).y)
      .contextMenu {
        Button("Open record") { studio.openRecord(entity) }
        Button("Inspect") { studio.inspect(.record(entity.id)) }
        Button("Connect from here…") {
          beginRelationship(from: entity.id)
        }.disabled(entities.count < 2)
      }
      .help(entity.title)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(entity.category.isEmpty ? "Entity" : Vocabulary.displayCategory(entity.category)): \(entity.title)"
      )
      .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
      .accessibilityAction { selected = entity.id }
      .accessibilityAction(named: "Open record") { studio.openRecord(entity) }
  }
  private func beginRelationship(from id: String, to other: String? = nil) {
    connecting = nil
    editing = nil
    studio.beginRelationship(sourceID: id, targetID: other, entitiesOnly: true)
  }

  private func port(_ entity: LoreRecord, tint: Color) -> some View {
    Button {
      if let first = connecting, first != entity.id {
        beginRelationship(from: first, to: entity.id)
      } else {
        connecting = connecting == entity.id ? nil : entity.id
      }
    } label: {
      Circle().fill(tint).frame(width: 7, height: 7).padding(3)
        .background(studio.t.surface, in: Circle())
        .overlay(Circle().stroke(tint.opacity(connecting == entity.id ? 1 : 0.55), lineWidth: 1))
    }.buttonStyle(.plain).help(
      connecting == nil ? "Connect from \(entity.title)" : "Connect to \(entity.title)"
    )
    .accessibilityLabel("Connect \(entity.title)")
  }
  private func detail(_ entity: LoreRecord) -> some View {
    detailContent(entity).padding(14).frame(width: 290)
      .floatingPanel(studio.t, radius: Metric.cardRadius)
      .accessibilityElement(children: .contain).accessibilityLabel("Entity details")
  }
  private func detailContent(_ entity: LoreRecord) -> some View {
    let related = relationships.filter { $0.sourceID == entity.id || $0.targetID == entity.id }
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        CategoryTile(record: entity, t: studio.t, size: 32)
        VStack(alignment: .leading, spacing: 3) {
          Text(entity.title).font(.studio(size: 15, weight: .semibold)).lineLimit(2)
          HStack(spacing: 8) {
            if !entity.category.isEmpty {
              Text(Vocabulary.displayCategory(entity.category)).font(.studio(.caption))
                .foregroundStyle(studio.t.muted)
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
        Text(entity.body).font(.studio(size: 13)).lineSpacing(3).foregroundStyle(studio.t.secondary)
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
                StudioIcon(outward ? "arrow.right" : "arrow.left")
                  .font(.studio(size: 9, weight: .bold)).foregroundStyle(studio.t.muted)
                Text(relation.label).font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
                Text(name(other)).font(.studio(size: 12.5, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
              }.padding(.horizontal, 7).frame(height: 26).hoverFill(studio.t, radius: 6)
            }.buttonStyle(.plain)
          }
        }.padding(.horizontal, -7)
      }
      HStack(spacing: 6) {
        Button("Open record") { studio.openRecord(entity) }
        Button("Inspect") { studio.inspect(.record(entity.id)) }
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
    if layoutWorldID == nil { layoutWorldID = studio.worldID }
    guard layoutWorldID == studio.worldID else { return }
    let world = studio.worldID
    studio.perform {
      relationships = try studio.store.relations(worldID: studio.worldID)
      artworkIDs = try studio.store.recordArtworkIDs(worldID: studio.worldID)
      let nodes = entities.map(\.id).sorted()
      let landscape = layoutLandscape ?? (area.width >= area.height)
      let next =
        nodes.joined(separator: ",") + "|\(landscape)|"
        + relationships.map { "\($0.sourceID)>\($0.targetID)" }.sorted().joined(separator: ",")
      if next == signature && pendingSignature != nil {
        // Undo can return to the completed topology while a newer layout is still running.
        layoutTask?.cancel()
        layoutTask = nil
        pendingSignature = nil
      }
      if next != signature && next != pendingSignature {
        let initiallyEmpty = layout.isEmpty
        layoutTask?.cancel()
        layoutTask = nil
        pendingSignature = next
        let edges = relationships.map { ($0.sourceID, $0.targetID) }
        if nodes.count <= 80 {
          layout = GraphLayout.positions(nodes: nodes, edges: edges, landscape: landscape)
          signature = next
          pendingSignature = nil
          if framed && initiallyEmpty { frame(area, animated: false) }
        } else {
          let worker = Task.detached(priority: .userInitiated) {
            GraphLayout.positions(nodes: nodes, edges: edges, landscape: landscape)
          }
          layoutTask = Task {
            let result = await withTaskCancellationHandler {
              await worker.value
            } onCancel: {
              worker.cancel()
            }
            guard !Task.isCancelled, studio.worldID == world, pendingSignature == next else {
              return
            }
            layout = result
            signature = next
            layoutTask = nil
            pendingSignature = nil
            if framed && initiallyEmpty { frame(area, animated: false) }
          }
        }
      }
      if let selected, !nodes.contains(selected) { self.selected = nil }
    }
  }
  private func changeZoom(_ factor: Double, anchor: CGPoint = .zero) {
    let next = SpatialViewport.zoom(scale: zoom, pan: pan, factor: factor, anchor: anchor)
    zoom = next.scale
    pan = next.pan
    hoveredEdge = nil
  }
  private func stepZoom(_ factor: Double) {
    withAnimation(reduceMotion ? nil : Motion.panelAnimation) { changeZoom(factor) }
  }
  /// Centres and scales the whole graph into the visible area.
  private func frame(_ size: CGSize, animated: Bool = true) {
    guard !layout.isEmpty else { return }
    let xs = layout.values.map(\.x)
    let ys = layout.values.map(\.y)
    let width = (xs.max()! - xs.min()!) + GraphLayout.cardSize.width + 96
    let height = (ys.max()! - ys.min()!) + GraphLayout.cardSize.height + 96
    // Fit uses maximum card bounds. Semantic detail never rearranges node centres.
    let scale = min(1, max(0.1, min(size.width / width, (size.height - 40) / height)))
    let apply = {
      let capturedScale: Double? =
        studio.captureHint.contains("graph-zoom-")
        ? (studio.captureHint.hasSuffix("overview")
          ? 0.42
          : studio.captureHint.hasSuffix("summary") ? 0.75 : 1.1) : nil
      zoom = capturedScale ?? scale
      pan = CGSize(
        width: -(xs.max()! + xs.min()!) / 2 * scale,
        height: -(ys.max()! + ys.min()!) / 2 * scale - 10)
      if capturedScale != nil, let focus = entities.first(where: { $0.title == "Mira Vale" }),
        let centre = layout[focus.id]
      {
        pan = CGSize(width: -centre.x * zoom - size.width * 0.22, height: -centre.y * zoom)
      }
    }
    if animated {
      withAnimation(reduceMotion ? nil : Motion.panelAnimation) { apply() }
    } else {
      apply()
    }
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
        card.x = (layout[record.id]?.x ?? 0) * 1.2
        card.y = (layout[record.id]?.y ?? 0) * 1.3
        return card
      }
      let data = try JSONEncoder().encode(document)
      let board = try studio.store.saveBoard(
        worldID: studio.worldID, name: title, kind: "canvas",
        content: String(decoding: data, as: UTF8.self))
      studio.openBoard(board.id, kind: "canvas")
      studio.show("Copied to a new board. Moving cards there never changes the graph.")
    }
  }

  // MARK: Sheets

  private var suggestions: [String] {
    Array(Set(relationships.map(\.label))).sorted().prefix(6).map { $0 }
  }
  private func closePanel() { panel = nil }
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
