import SwiftFlow
import SwiftUI
import SynthesisCore

// Native graph mechanics belong to SwiftFlow; world data and approvals stay in Synthesis.
typealias KnowledgeScreen = RelationshipGraph
struct RelationshipGraph: View {
  @ObservedObject var studio: Studio
  @StateObject private var instance = SwiftFlowInstance()
  @State private var relationships: [Relation] = []
  @State private var snapshot = GraphEngine.Snapshot(nodes: [], edges: [])
  @State private var query = ""
  @State private var selected: String?
  @State private var selectedEdge: String?
  @State private var linking = false
  @State private var source = ""
  @State private var target = ""
  @State private var label = ""
  @State private var editing: Relation?
  @State private var archived: String?
  @State private var loading = false

  private var signature: String {
    studio.worldID + studio.records.map { "\($0.id):\($0.version)" }.joined(separator: "|")
      + relationships.map { "\($0.id):\($0.label)" }.joined(separator: "|")
  }
  private var visibleNodes: [Node<LoreRecord>] {
    snapshot.nodes.filter { query.isEmpty || $0.data.title.localizedCaseInsensitiveContains(query) }
      .map { node in
        var node = node
        node.selected = node.id == selected
        return node
      }
  }
  private var visibleEdges: [FlowEdge<EmptyEdgeData>] {
    let ids = Set(visibleNodes.map(\.id))
    return snapshot.edges.filter { ids.contains($0.source) && ids.contains($0.target) }.map {
      edge in
      var edge = edge
      edge.selected = edge.id == selectedEdge
      return edge
    }
  }
  private var theme: SwiftFlowTheme {
    SwiftFlowTheme(
      edgeColor: studio.t.accent.opacity(0.6), edgeSelectedColor: studio.t.accent,
      edgeWidth: 1.5, edgeSelectedWidth: 2.5, nodeSelectedBorderWidth: 0,
      handleColor: studio.t.accent, handleBorderColor: studio.t.surface, handleSize: 10,
      selectionBoxColor: studio.t.accent.opacity(0.12), selectionBoxBorderColor: studio.t.accent,
      canvasBackgroundColor: studio.t.background, gridColor: studio.t.muted.opacity(0.08),
      gridSpacing: 32,
      edgeLabelFont: .system(size: 13, weight: .medium), edgeLabelColor: studio.t.accent,
      edgeLabelBackgroundColor: studio.t.surface)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        WorkspaceHeading(
          title: "Knowledge Graph",
          subtitle: "Connections from your world. Arrange ideas freely in Canvas.", t: studio.t)
        Spacer()
        Button(selected == nil ? "Copy graph to canvas" : "Copy neighborhood to canvas") {
          transfer()
        }
        .buttonStyle(QuietButton(t: studio.t)).disabled(visibleNodes.isEmpty || loading)
        IconButton(icon: "plus", label: "Add relationship", t: studio.t) {
          editing = nil
          source = snapshot.nodes.first?.id ?? ""
          target = snapshot.nodes.dropFirst().first?.id ?? ""
          label = ""
          linking = true
        }.disabled(snapshot.nodes.count < 2)
      }
      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass").foregroundStyle(studio.t.secondary)
        TextField("Find an entity", text: $query).textFieldStyle(.plain)
        if loading { ProgressView().controlSize(.small) }
        if archived != nil { Button("Restore removed connection") { restore() } }
        Spacer()
        IconButton(icon: "minus", label: "Zoom out", t: studio.t) { instance.zoomOut() }
        Text("\(Int(instance.viewport.zoom * 100))%").monospacedDigit().frame(width: 48)
        IconButton(icon: "plus", label: "Zoom in", t: studio.t) { instance.zoomIn() }
        IconButton(
          icon: "arrow.up.left.and.arrow.down.right", label: "Fit graph to view", t: studio.t
        ) { fit() }
      }.font(.system(size: 13))
      if snapshot.nodes.isEmpty && !loading {
        VStack(spacing: 18) {
          Image(systemName: "point.3.connected.trianglepath.dotted").font(
            .system(size: 36, weight: .light)
          ).foregroundStyle(studio.t.accent)
          Text("Connections begin with your people and places.").font(.system(size: 23))
          Button("Create an entity") { studio.sheet = .document }.buttonStyle(
            QuietButton(t: studio.t))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        SwiftFlow(
          nodes: visibleNodes, edges: visibleEdges,
          onNodesChange: { changes in
            selected = applyNodeChanges(changes, nodes: visibleNodes).first(where: \.selected)?.id
            selectedEdge = nil
          },
          onEdgesChange: { changes in
            selectedEdge =
              applyEdgeChanges(changes, edges: visibleEdges).first(where: \.selected)?.id
            selected = nil
          },
          onConnect: { connection in
            guard GraphEngine.canConnect(connection, in: snapshot) else { return }
            editing = nil
            source = connection.source
            target = connection.target
            label = ""
            linking = true
          }, nodesDraggable: false, panOnScroll: true, zoomOnScroll: false,
          backgroundVariant: .dots, theme: theme, fitView: true,
          fitViewOptions: FitViewOptions(padding: 70, maxZoom: 1, duration: nil),
          onPaneClick: {
            selected = nil
            selectedEdge = nil
          },
          isValidConnection: { GraphEngine.canConnect($0, in: snapshot) },
          onBeforeDelete: { _, _ in .cancel },
          onNodeClick: {
            selected = $0.id
            selectedEdge = nil
          },
          onNodeDoubleClick: { studio.openRecord($0.data) },
          onEdgeClick: {
            selectedEdge = $0.id
            selected = nil
          },
          swiftFlowInstance: instance
        ) { node in
          nodeView(node)
        } overlay: {
          EmptyView()
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
          if !snapshot.nodes.isEmpty && visibleNodes.isEmpty {
            Text("No matching entities").foregroundStyle(studio.t.secondary)
          }
        }
      }
      if let record = snapshot.nodes.first(where: { $0.id == selected })?.data {
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text(record.title).font(.system(size: 15, weight: .medium))
            Text(record.body).lineLimit(2).font(.system(size: 14)).foregroundStyle(
              studio.t.secondary)
          }
          Spacer()
          Button("Open record") { studio.openRecord(record) }.buttonStyle(QuietButton(t: studio.t))
          IconButton(icon: "xmark", label: "Close selection", t: studio.t) { selected = nil }
        }.padding(16).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 12))
      }
      if let relation = relationships.first(where: { $0.id == selectedEdge }) {
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text("\(title(relation.sourceID)) → \(title(relation.targetID))").font(
              .system(size: 14))
            Text(relation.label + " · " + (relation.state ?? "unknown").capitalized)
              .foregroundStyle(
                studio.t.secondary)
          }
          Spacer()
          if relation.state == "draft" {
            Button("Edit connection") {
              editing = relation
              source = relation.sourceID
              target = relation.targetID
              label = relation.label
              linking = true
            }
            Button("Remove") {
              studio.perform {
                try studio.store.archiveRelation(worldID: studio.worldID, id: relation.id)
                archived = relation.id
                selectedEdge = nil
                refresh()
              }
            }
          }
          IconButton(icon: "xmark", label: "Close connection", t: studio.t) { selectedEdge = nil }
        }.font(.system(size: 13)).padding(16).background(
          studio.t.surface, in: RoundedRectangle(cornerRadius: 12))
      }
    }.padding(28).onAppear { refresh() }
      .task(id: signature) {
        loading = true
        let world = studio.worldID
        let records = studio.records
        let relations = relationships
        let result = await Task.detached(priority: .userInitiated) {
          GraphEngine.project(worldID: world, records: records, relationships: relations)
        }.value
        guard !Task.isCancelled else { return }
        snapshot = result
        loading = false
        if !result.nodes.contains(where: { $0.id == selected }) { selected = nil }
        await Task.yield()
        fit()
      }
      .sheet(isPresented: $linking) { connectionForm }
  }
  private func nodeView(_ node: Node<LoreRecord>) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 7) {
        Image(systemName: categoryIcon(node.data.category)).foregroundStyle(studio.t.accent)
        Text(node.data.category).foregroundStyle(studio.t.secondary).lineLimit(1)
        Spacer()
        Text(node.data.state.capitalized).foregroundStyle(studio.t.secondary)
      }.font(.system(size: 12))
      Text(node.data.title).font(.system(size: 16, weight: .semibold)).lineLimit(2)
      Text(node.data.body).font(.system(size: 14)).foregroundStyle(studio.t.secondary).lineLimit(2)
    }.padding(16).frame(width: 220, height: 116, alignment: .topLeading)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).stroke(
          node.selected ? studio.t.accent : studio.t.border, lineWidth: node.selected ? 1.5 : 1)
      )
      .overlay {
        HStack {
          Handle(nodeId: node.id, id: "in", type: .target, position: .left)
          Spacer()
          Handle(nodeId: node.id, id: "out", type: .source, position: .right)
        }.padding(.horizontal, -5)
      }.contextMenu { Button("Open source record") { studio.openRecord(node.data) } }
  }
  private var connectionForm: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(editing == nil ? "Give the connection meaning." : "Edit this connection").font(
        .system(size: 24, weight: .medium))
      Picker("From", selection: $source) {
        ForEach(snapshot.nodes) { Text($0.data.title).tag($0.id) }
      }.disabled(editing != nil)
      TextField("Relationship · e.g. guided by", text: $label).textFieldStyle(.roundedBorder)
      Picker("To", selection: $target) {
        ForEach(snapshot.nodes) { Text($0.data.title).tag($0.id) }
      }.disabled(editing != nil)
      Text("Saved as a draft relationship. Canon remains unchanged.").font(.system(size: 13))
        .foregroundStyle(studio.t.secondary)
      HStack {
        Button("Cancel") { linking = false }
        Spacer()
        Button("Save relationship") {
          studio.perform {
            if let editing {
              try studio.store.updateRelation(worldID: studio.worldID, id: editing.id, label: label)
            } else {
              _ = try studio.store.addRelation(
                worldID: studio.worldID, source: source, target: target, label: label)
            }
            linking = false
            refresh()
          }
        }.disabled(
          source == target || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 440)
  }
  private func refresh() {
    studio.perform { relationships = try studio.store.relations(worldID: studio.worldID) }
  }
  private func title(_ id: String) -> String {
    snapshot.nodes.first(where: { $0.id == id })?.data.title ?? "Entity"
  }
  private func fit() {
    instance.fitView(
      nodes: visibleNodes, nodeSizes: instance.nodeSizes,
      options: FitViewOptions(padding: 70, maxZoom: 1, duration: nil))
  }
  private func restore() {
    studio.perform {
      if let archived {
        try studio.store.restoreRelation(worldID: studio.worldID, id: archived)
        self.archived = nil
        refresh()
      }
    }
  }
  private func transfer() {
    studio.perform {
      let visible = GraphEngine.Snapshot(nodes: visibleNodes, edges: visibleEdges)
      let document = GraphEngine.canvasDocument(
        from: selected == nil ? visible : snapshot, selected: selected)
      let board = try studio.store.saveBoard(
        worldID: studio.worldID, name: "Graph selection", kind: "canvas",
        content: String(decoding: try JSONEncoder().encode(document), as: UTF8.self))
      studio.canvasBoardID = board.id
      studio.navigate(.canvas)
    }
  }
}
