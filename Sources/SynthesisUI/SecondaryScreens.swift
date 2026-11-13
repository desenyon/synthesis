import SwiftUI
import SynthesisCore

struct WorkspaceHeading: View {
  let title: String
  let subtitle: String
  let t: Theme
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 28, weight: .medium)).tracking(-0.8)
      Text(subtitle).font(.system(size: 13)).foregroundStyle(t.secondary)
    }
  }
}

typealias KnowledgeScreen = RelationshipGraph
struct RelationshipGraph: View {
  @ObservedObject var studio: Studio
  @State private var relationships: [Relation] = []
  @State private var query = ""
  @State private var selected: String?
  @State private var linking = false
  @State private var source = ""
  @State private var target = ""
  @State private var label = ""
  @State private var zoom = 1.0
  @State private var positions: [String: CGSize] = [:]
  var entities: [LoreRecord] { studio.records.filter { $0.kind == "entity" } }
  var visible: [LoreRecord] {
    entities.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack {
        WorkspaceHeading(
          title: "Knowledge Graph",
          subtitle: "Derived from your world’s entity relationships", t: studio.t)
        Spacer()
        Button(selected == nil ? "Copy graph to canvas" : "Copy neighborhood to canvas") {
          transferToCanvas()
        }
        .buttonStyle(QuietButton(t: studio.t)).disabled(entities.isEmpty)
        Button {
          source = entities.first?.id ?? ""
          target = entities.dropFirst().first?.id ?? ""
          linking = true
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(entities.count < 2).help(
          "Add relationship")
      }
      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(studio.t.muted)
        TextField("Find an entity", text: $query).textFieldStyle(.plain)
        Spacer()
        IconButton(icon: "minus", label: "Zoom out", t: studio.t) { zoom = max(0.4, zoom - 0.15) }
        Text("\(Int(zoom * 100))%").font(.system(size: 11)).foregroundStyle(studio.t.secondary)
        IconButton(icon: "plus", label: "Zoom in", t: studio.t) { zoom = min(2, zoom + 0.15) }
      }.font(.system(size: 13))
      if entities.isEmpty {
        VStack(spacing: 18) {
          Image(systemName: "point.3.connected.trianglepath.dotted").font(
            .system(size: 44, weight: .ultraLight)
          ).foregroundStyle(studio.t.accent)
          Text("Start with someone. Or somewhere.").font(.system(size: 24, weight: .medium))
          Button("Create an entity") { studio.sheet = .document }.buttonStyle(
            QuietButton(t: studio.t))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        GeometryReader { geo in
          let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
          let radius = min(geo.size.width, geo.size.height) * 0.30 * zoom
          ZStack {
            ForEach(relationships) { edge in
              if let a = visible.firstIndex(where: { $0.id == edge.sourceID }),
                let b = visible.firstIndex(where: { $0.id == edge.targetID })
              {
                let start = point(a, center: center, radius: radius)
                let end = point(b, center: center, radius: radius)
                let emphasized =
                  selected == nil || selected == edge.sourceID || selected == edge.targetID
                Path { path in
                  path.move(to: start)
                  path.addLine(to: end)
                }
                .stroke(
                  studio.t.accent.opacity(emphasized ? 0.6 : 0.18), lineWidth: emphasized ? 1.8 : 1
                ).allowsHitTesting(false)
                Button {
                  selected = edge.sourceID
                } label: {
                  Text(edge.label + " →").font(.system(size: 13, weight: .medium)).padding(
                    .horizontal, 10
                  ).padding(.vertical, 6)
                    .foregroundStyle(studio.t.accent).background(studio.t.surface, in: Capsule())
                }.buttonStyle(.plain).position(
                  x: start.x + (end.x - start.x) * 0.38, y: start.y + (end.y - start.y) * 0.38 - 12
                )
                .help("Inspect source of \(edge.label)")
              }
            }
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, entity in
              Button {
                selected = entity.id
              } label: {
                VStack(spacing: 10) {
                  Image(systemName: categoryIcon(entity.category)).font(
                    .system(size: 20)
                  ).foregroundStyle(studio.t.accent)
                    .frame(width: 50, height: 50).background(studio.t.surface, in: Circle())
                    .overlay(
                      Circle().stroke(
                        studio.t.accent.opacity(selected == entity.id ? 0.8 : 0.15), lineWidth: 1.5)
                    )
                  Text(entity.title).font(.system(size: 16, weight: .medium)).lineLimit(2).frame(
                    width: 150)
                }
              }.buttonStyle(.plain).position(point(index, center: center, radius: radius))
                .contextMenu { Button("Open source record") { studio.openRecord(entity) } }
            }
          }.clipped()
        }.background(studio.t.surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        if let entity = entities.first(where: { $0.id == selected }) {
          HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
              Text(entity.title).font(.system(size: 15, weight: .medium))
              Text(entity.body.isEmpty ? "An entity waiting to take shape." : entity.body).font(
                .system(size: 12)
              ).foregroundStyle(studio.t.secondary).lineLimit(2)
            }
            Spacer()
            Button("Open record ↗") { studio.openRecord(entity) }.buttonStyle(
              QuietButton(t: studio.t))
            IconButton(icon: "xmark", label: "Close selection", t: studio.t) { selected = nil }
          }.padding(18).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 14))
        }
      }
    }.padding(30).onAppear { refresh() }
      .sheet(isPresented: $linking) {
        VStack(alignment: .leading, spacing: 22) {
          Text("Give the connection meaning.").font(.system(size: 26, design: .serif))
          Picker("From", selection: $source) { ForEach(entities) { Text($0.title).tag($0.id) } }
          TextField("Relationship · e.g. belongs to", text: $label).textFieldStyle(.roundedBorder)
          Picker("To", selection: $target) { ForEach(entities) { Text($0.title).tag($0.id) } }
          Text("Saved as a draft relationship. This does not establish canon.").font(.caption)
            .foregroundStyle(.secondary)
          HStack {
            Button("Cancel") { linking = false }
            Spacer()
            Button("Connect") {
              studio.perform {
                _ = try studio.store.addRelation(
                  worldID: studio.worldID, source: source, target: target, label: label)
                linking = false
                refresh()
              }
            }.disabled(source == target || label.isEmpty)
          }
        }.padding(28).frame(width: 430)
      }
  }
  private func transferToCanvas() {
    studio.perform {
      var ids = Set(visible.map(\.id))
      if let selected {
        ids = [selected]
        for relation in relationships
        where relation.sourceID == selected || relation.targetID == selected {
          ids.insert(relation.sourceID)
          ids.insert(relation.targetID)
        }
      }
      var document = CanvasDocument()
      document.cards = entities.filter { ids.contains($0.id) }.enumerated().map { index, record in
        var card = CanvasCard(text: record.title, recordID: record.id)
        card.width = 300
        card.x = Double(index % 2) * 380 - 190
        card.y = Double(index / 2) * 320 - 120
        return card
      }
      let data = try JSONEncoder().encode(document)
      let board = try studio.store.saveBoard(
        worldID: studio.worldID, name: "Graph selection", kind: "canvas",
        content: String(decoding: data, as: UTF8.self))
      studio.canvasBoardID = board.id
      studio.navigate(.canvas)
    }
  }
  private func refresh() {
    studio.perform { relationships = try studio.store.relations(worldID: studio.worldID) }
  }
  private func point(_ index: Int, center: CGPoint, radius: Double) -> CGPoint {
    let angle = Double(index) / Double(max(1, visible.count)) * .pi * 2 - .pi / 2
    let offset = positions[visible[index].id] ?? .zero
    return CGPoint(
      x: center.x + cos(angle) * radius + offset.width,
      y: center.y + sin(angle) * radius + offset.height)
  }
}

struct TimelineScreen: View {
  @ObservedObject var studio: Studio
  @State private var events: [WorldEvent] = []
  @State private var adding = false
  @State private var title = ""
  @State private var date = ""
  @State private var order = ""
  @State private var source = ""
  @State private var filter = ""
  @State private var spacing = 30.0
  var filtered: [WorldEvent] {
    events.filter {
      filter.isEmpty || $0.dateLabel.localizedCaseInsensitiveContains(filter)
        || $0.title.localizedCaseInsensitiveContains(filter)
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 26) {
      HStack {
        WorkspaceHeading(
          title: "Universal history",
          subtitle: "History with room for uncertainty, myth, and missing years.", t: studio.t)
        Spacer()
        Button {
          source = studio.records.first?.id ?? ""
          adding = true
        } label: {
          Image(systemName: "plus")
        }.buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(studio.records.isEmpty)
          .help("Add event")
      }
      HStack {
        TextField("Find an era or event", text: $filter).textFieldStyle(.plain)
        Spacer()
        IconButton(icon: "minus", label: "Compact timeline", t: studio.t) {
          spacing = max(12, spacing - 12)
        }
        IconButton(icon: "plus", label: "Expand timeline", t: studio.t) {
          spacing = min(120, spacing + 12)
        }
      }.font(.system(size: 13))
      ScrollView {
        VStack(alignment: .leading, spacing: spacing) {
          ForEach(filtered) { event in
            HStack(alignment: .top, spacing: 20) {
              VStack(spacing: 8) {
                Circle().fill(studio.t.accent.opacity(0.7)).frame(width: 9, height: 9)
                Rectangle().fill(studio.t.border).frame(width: 1, height: 80)
              }.frame(width: 18)
              VStack(alignment: .leading, spacing: 12) {
                Text(event.dateLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(
                  studio.t.accent)
                Text(event.title).font(.system(size: 24, weight: .medium))
                if let record = studio.records.first(where: { $0.id == event.sourceID }) {
                  Button {
                    studio.openRecord(record)
                  } label: {
                    Label(record.title + " ↗", systemImage: "doc.text")
                  }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(studio.t.secondary)
                }
                Text("Draft event").font(.system(size: 10)).foregroundStyle(studio.t.muted)
              }
              Spacer()
            }.padding(.vertical, 10)
          }
          if filtered.isEmpty {
            Text(events.isEmpty ? "Every history starts somewhere." : "No matching events.").font(
              .system(size: 24, weight: .medium)
            ).padding(.top, 70)
            Text(
              studio.records.isEmpty
                ? "Create a source document or entity in Library first."
                : "Add an event with a source record. Dates can be unknown."
            ).font(.system(size: 14)).foregroundStyle(studio.t.secondary)
          }
        }.padding(.vertical, 24).frame(maxWidth: 800, alignment: .leading).frame(
          maxWidth: .infinity, alignment: .leading)
      }
    }.padding(30).onAppear { refresh() }
      .sheet(isPresented: $adding) {
        VStack(alignment: .leading, spacing: 20) {
          Text("A moment that matters.").font(.system(size: 24, weight: .medium))
          TextField("Event title", text: $title)
          TextField("Date or era · leave empty if unknown", text: $date)
          TextField("Optional chronology order (integer)", text: $order)
          Picker("Source", selection: $source) {
            ForEach(studio.records) { Text($0.title).tag($0.id) }
          }
          Text(
            "Date labels preserve your world's own language. Ordering does not invent calendar precision."
          ).font(.caption).foregroundStyle(.secondary)
          HStack {
            Button("Cancel") { adding = false }
            Spacer()
            Button("Add event") {
              studio.perform {
                guard order.isEmpty || Int(order) != nil else {
                  throw SynthesisError.invalid("Order must be an integer or blank.")
                }
                _ = try studio.store.addEvent(
                  worldID: studio.worldID, title: title, date: date, source: source,
                  order: Int(order))
                adding = false
                title = ""
                date = ""
                order = ""
                refresh()
              }
            }.disabled(title.isEmpty || source.isEmpty)
          }
        }.textFieldStyle(.roundedBorder).padding(28).frame(width: 430)
      }
  }
  private func refresh() {
    studio.perform { events = try studio.store.events(worldID: studio.worldID) }
  }
}
