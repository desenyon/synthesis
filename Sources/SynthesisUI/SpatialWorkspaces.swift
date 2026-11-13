import AppKit
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

struct CanvasCard: Identifiable, Codable, Equatable {
  var id = UUID().uuidString
  var text = "An unwritten thought"
  var recordID: String?
  var image: String?
  var x = 0.0
  var y = 0.0
  var width = 230.0
  var height = 160.0
  var group: String?
}
struct CanvasEdge: Codable, Equatable {
  var label: String?
  var source: String
  var target: String
}
struct CanvasDocument: Codable, Equatable {
  var viewport: BoardViewport?
  var cards: [CanvasCard] = []
  var edges: [CanvasEdge] = []
}

struct CanvasScreen: View {
  @ObservedObject var studio: Studio
  @State private var boardID: String?
  @State private var loadFailed = false
  @State private var document = CanvasDocument()
  @State private var undo: [CanvasDocument] = []
  @State private var redo: [CanvasDocument] = []
  @State private var selection: Set<String> = []
  @State private var zoom = 1.0
  @State private var pan = CGSize.zero
  @State private var panStart: CGSize?
  @State private var dragStart: CanvasDocument?
  @State private var editing: String?
  @State private var text = ""
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        Text("A little room to wander.").font(.system(size: 25, design: .serif))
        Spacer()
        Menu {
          Button("Note") { add(CanvasCard()) }
          Button("Image…") { importImage() }
          Divider()
          ForEach(studio.records) { record in
            Button(record.title) { add(CanvasCard(text: record.title, recordID: record.id)) }
          }
        } label: {
          Label("Add", systemImage: "plus")
        }.menuStyle(.borderlessButton).fixedSize()
        IconButton(icon: "arrow.uturn.backward", label: "Undo canvas change", t: studio.t) {
          step(back: true)
        }.disabled(undo.isEmpty)
        IconButton(icon: "arrow.uturn.forward", label: "Redo canvas change", t: studio.t) {
          step(back: false)
        }.disabled(redo.isEmpty)
      }.padding(24)
      GeometryReader { geo in
        ZStack {
          Canvas { context, size in
            let gap = 28.0 * zoom
            let ox = pan.width.truncatingRemainder(dividingBy: gap)
            let oy = pan.height.truncatingRemainder(dividingBy: gap)
            for x in stride(from: ox, to: size.width, by: gap) {
              for y in stride(from: oy, to: size.height, by: gap) {
                context.fill(
                  Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                  with: .color(studio.t.muted.opacity(0.2)))
              }
            }
            for group in Set(document.cards.compactMap(\.group)) {
              let members = document.cards.filter { $0.group == group }
              let bounds = members.reduce(CGRect.null) {
                $0.union(rect($1, geo.size).insetBy(dx: -20, dy: -20))
              }
              context.fill(
                Path(roundedRect: bounds, cornerRadius: 20),
                with: .color(studio.t.accent.opacity(0.055)))
              context.stroke(
                Path(roundedRect: bounds, cornerRadius: 20),
                with: .color(studio.t.accent.opacity(0.13)), lineWidth: 1)
            }
            for edge in document.edges {
              if let a = document.cards.first(where: { $0.id == edge.source }),
                let b = document.cards.first(where: { $0.id == edge.target })
              {
                var path = Path()
                path.move(to: point(a, geo.size))
                path.addLine(to: point(b, geo.size))
                context.stroke(
                  path, with: .color(studio.t.accent.opacity(0.45)),
                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
              }
            }
          }.contentShape(Rectangle()).gesture(
            DragGesture().onChanged { value in
              if panStart == nil { panStart = pan }
              pan = CGSize(
                width: panStart!.width + value.translation.width,
                height: panStart!.height + value.translation.height)
            }.onEnded { _ in panStart = nil })
          ForEach(document.cards) { card in
            cardView(card).frame(width: card.width * zoom, height: card.height * zoom).position(
              point(card, geo.size)
            )
            .gesture(
              DragGesture(minimumDistance: 4).onChanged { value in
                if dragStart == nil { dragStart = document }
                guard let start = dragStart?.cards.first(where: { $0.id == card.id }),
                  let index = document.cards.firstIndex(where: { $0.id == card.id })
                else { return }
                document.cards[index].x = start.x + value.translation.width / zoom
                document.cards[index].y = start.y + value.translation.height / zoom
              }.onEnded { _ in
                if let before = dragStart { commit(before) }
                dragStart = nil
              })
          }
          if document.cards.isEmpty {
            VStack(spacing: 16) {
              Image(systemName: "square.on.square").font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(studio.t.accent)
              Text("Let the pieces find each other.").font(.system(size: 30, design: .serif))
              Text("Add a note, an image, or something from your world.").font(.system(size: 14))
                .foregroundStyle(studio.t.secondary)
              Button("Add your first note") { add(CanvasCard()) }.buttonStyle(
                QuietButton(t: studio.t, primary: true))
            }.padding(24)
          }
        }.clipped()
      }
      HStack(spacing: 12) {
        Text("Drag the open space to pan").font(.system(size: 11)).foregroundStyle(studio.t.muted)
        Spacer()
        if selection.count == 2 {
          Button("Connect") {
            let before = document
            let ids = Array(selection)
            if !document.edges.contains(where: { Set([$0.source, $0.target]) == selection }) {
              document.edges.append(CanvasEdge(source: ids[0], target: ids[1]))
              commit(before)
            }
          }.buttonStyle(.plain).font(.system(size: 12))
        }
        if selection.count > 1 {
          Button("Group") {
            let before = document
            let id = UUID().uuidString
            for index in document.cards.indices where selection.contains(document.cards[index].id) {
              document.cards[index].group = id
            }
            commit(before)
            selection = []
          }.buttonStyle(.plain).font(.system(size: 12))
        }
        if !selection.isEmpty {
          Button("Clear selection") { selection = [] }.buttonStyle(.plain).font(.system(size: 11))
        }
        zoomControls
      }.padding(16).background(studio.t.surface.opacity(0.65))
    }.disabled(loadFailed).onAppear {
      load()
      studio.editorSave = { persist() }
    }
    .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
      VStack(alignment: .leading, spacing: 18) {
        Text("A thought in progress.").font(.system(size: 26, design: .serif))
        TextEditor(text: $text).font(.system(size: 16)).frame(height: 180)
        HStack {
          Button("Cancel") { editing = nil }
          Spacer()
          Button("Save note") {
            if let index = document.cards.firstIndex(where: { $0.id == editing }) {
              let before = document
              document.cards[index].text = text
              commit(before)
            }
            editing = nil
          }
        }
      }.padding(24).frame(width: 430)
    }
  }
  private var zoomControls: some View {
    HStack(spacing: 6) {
      IconButton(icon: "minus", label: "Zoom out", t: studio.t) { zoom = max(0.3, zoom - 0.1) }
      Button("\(Int(zoom * 100))%") {
        zoom = 1
        pan = .zero
      }.font(.system(size: 11)).buttonStyle(.plain).help("Reset view")
      IconButton(icon: "plus", label: "Zoom in", t: studio.t) { zoom = min(2.5, zoom + 0.1) }
    }
  }
  private func cardView(_ card: CanvasCard) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      if let encoded = card.image, let data = Data(base64Encoded: encoded),
        let image = NSImage(data: data)
      {
        Image(nsImage: image).resizable().scaledToFit().frame(
          maxWidth: .infinity, maxHeight: .infinity)
      } else {
        if card.recordID != nil {
          Label("Linked record", systemImage: "link").font(.system(size: 10)).foregroundStyle(
            studio.t.accent)
        }
        Text(card.text).font(.system(size: 15 * zoom)).lineLimit(8).frame(
          maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      HStack {
        Button {
          if selection.contains(card.id) {
            selection.remove(card.id)
          } else {
            selection.insert(card.id)
          }
        } label: {
          Image(systemName: selection.contains(card.id) ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(studio.t.accent)
        }.buttonStyle(.plain).help("Select card for connecting or grouping")
        Spacer()
        if let id = card.recordID, let record = studio.records.first(where: { $0.id == id }) {
          Button("Open ↗") { studio.openRecord(record) }.buttonStyle(.plain).font(.system(size: 11))
            .foregroundStyle(studio.t.accent)
        } else if card.image == nil {
          Button {
            text = card.text
            editing = card.id
          } label: {
            Image(systemName: "pencil")
          }.buttonStyle(.plain).help("Edit note")
        }
        Image(systemName: "arrow.down.right").font(.system(size: 11)).foregroundStyle(
          studio.t.muted
        ).padding(3).gesture(
          DragGesture().onChanged { value in
            if dragStart == nil { dragStart = document }
            guard let start = dragStart?.cards.first(where: { $0.id == card.id }),
              let index = document.cards.firstIndex(where: { $0.id == card.id })
            else { return }
            document.cards[index].width = max(
              160, min(600, start.width + value.translation.width / zoom))
            document.cards[index].height = max(
              120, min(600, start.height + value.translation.height / zoom))
          }.onEnded { _ in
            if let before = dragStart { commit(before) }
            dragStart = nil
          }
        ).help("Drag to resize")
      }
    }.padding(16 * min(zoom, 1.2)).background(
      studio.t.surface, in: RoundedRectangle(cornerRadius: 14)
    ).overlay(
      RoundedRectangle(cornerRadius: 14).stroke(
        selection.contains(card.id) ? studio.t.accent : studio.t.border,
        lineWidth: selection.contains(card.id) ? 1.5 : 0.7)
    ).shadow(color: .black.opacity(0.04), radius: 10, y: 4)
      .contextMenu {
        Button("Remove from canvas") {
          let before = document
          document.cards.removeAll { $0.id == card.id }
          document.edges.removeAll { $0.source == card.id || $0.target == card.id }
          selection.remove(card.id)
          commit(before)
        }
        if card.group != nil {
          Button("Ungroup") {
            let before = document
            for index in document.cards.indices where document.cards[index].group == card.group {
              document.cards[index].group = nil
            }
            commit(before)
          }
        }
      }
  }
  private func point(_ card: CanvasCard, _ size: CGSize) -> CGPoint {
    CGPoint(
      x: size.width / 2 + card.x * zoom + pan.width, y: size.height / 2 + card.y * zoom + pan.height
    )
  }
  private func rect(_ card: CanvasCard, _ size: CGSize) -> CGRect {
    let p = point(card, size)
    return CGRect(
      x: p.x - card.width * zoom / 2, y: p.y - card.height * zoom / 2, width: card.width * zoom,
      height: card.height * zoom)
  }
  private func add(_ value: CanvasCard) {
    let before = document
    var card = value
    card.x = -pan.width / zoom + Double(document.cards.count % 3) * 35
    card.y = -pan.height / zoom + Double(document.cards.count % 3) * 35
    document.cards.append(card)
    commit(before)
  }
  private func commit(_ before: CanvasDocument) {
    guard before != document else { return }
    undo.append(before)
    undo = Array(undo.suffix(60))
    redo = []
    persist()
  }
  private func step(back: Bool) {
    if back, let previous = undo.popLast() {
      redo.append(document)
      document = previous
    } else if !back, let next = redo.popLast() {
      undo.append(document)
      document = next
    }
    selection = []
    persist()
  }
  private func load() {
    do {
      if let board = try studio.store.boards(worldID: studio.worldID, kind: "canvas").first {
        boardID = board.id
        document = try JSONDecoder().decode(CanvasDocument.self, from: Data(board.content.utf8))
      }
    } catch {
      loadFailed = true
      studio.error = error.localizedDescription
    }
  }
  @discardableResult private func persist() -> Bool {
    guard !loadFailed else { return true }
    do {
      let json = String(decoding: try JSONEncoder().encode(document), as: UTF8.self)
      boardID = try studio.store.saveBoard(
        worldID: studio.worldID, id: boardID, name: "Freeform", kind: "canvas", content: json
      ).id
      return true
    } catch {
      studio.error =
        "Canvas could not save. Your changes remain open. " + error.localizedDescription
      return false
    }
  }
  private func importImage() {
    studio.perform {
      if let encoded = try pickImage() {
        add(CanvasCard(text: "Image", image: encoded, width: 280, height: 220))
      }
    }
  }
}

func pickImage() throws -> String? {
  let panel = NSOpenPanel()
  panel.allowedContentTypes = [.png, .jpeg]
  panel.allowsMultipleSelection = false
  guard panel.runModal() == .OK, let url = panel.url else { return nil }
  let data = try Data(contentsOf: url)
  guard data.count <= 6_000_000, NSImage(data: data) != nil else {
    throw SynthesisError.invalid("Choose a PNG or JPEG image under 6 MB.")
  }
  return data.base64EncodedString()
}

struct MapMarker: Identifiable, Codable {
  var id = UUID().uuidString
  var recordID: String
  var x: Double
  var y: Double
}
struct AtlasDocument: Codable {
  var image: String?
  var markers: [MapMarker] = []
}
struct AtlasScreen: View {
  @ObservedObject var studio: Studio
  @State private var boardID: String?
  @State private var loadFailed = false
  @State private var map = AtlasDocument()
  @State private var zoom = 1.0
  @State private var pan = CGSize.zero
  @State private var panStart: CGSize?
  @State private var placing: String?
  @State private var selected: String?
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        WorkspaceHeading(
          title: "Beyond the horizon.", subtitle: "A place for the geography only you can imagine.",
          t: studio.t)
        Spacer()
        if map.image == nil {
          Button("Upload map") { upload() }.buttonStyle(QuietButton(t: studio.t, primary: true))
        } else {
          Menu {
            ForEach(studio.records) { record in Button(record.title) { placing = record.id } }
          } label: {
            Label("Place marker", systemImage: "mappin.and.ellipse")
          }.menuStyle(.borderlessButton).fixedSize().disabled(studio.records.isEmpty)
        }
      }.padding(26)
      GeometryReader { geo in
        if let encoded = map.image, let data = Data(base64Encoded: encoded),
          let image = NSImage(data: data)
        {
          let ratio = image.size.width / max(1, image.size.height)
          let width = min(geo.size.width - 48, (geo.size.height - 48) * ratio) * zoom
          let height = width / ratio
          let origin = CGPoint(
            x: geo.size.width / 2 + pan.width, y: geo.size.height / 2 + pan.height)
          ZStack {
            Color.clear.contentShape(Rectangle()).gesture(
              DragGesture().onChanged { drag in
                if panStart == nil { panStart = pan }
                pan = CGSize(
                  width: panStart!.width + drag.translation.width,
                  height: panStart!.height + drag.translation.height)
              }.onEnded { _ in panStart = nil })
            Image(nsImage: image).resizable().frame(width: width, height: height).clipShape(
              RoundedRectangle(cornerRadius: 8)
            ).shadow(color: .black.opacity(0.09), radius: 18).position(origin)
              .gesture(
                SpatialTapGesture().onEnded { value in
                  if let id = placing {
                    map.markers.append(
                      MapMarker(
                        recordID: id, x: min(1, max(0, value.location.x / width)),
                        y: min(1, max(0, value.location.y / height))))
                    placing = nil
                    persist()
                  }
                }
              )
              .simultaneousGesture(
                DragGesture(minimumDistance: 4).onChanged { drag in
                  if placing == nil {
                    if panStart == nil { panStart = pan }
                    pan = CGSize(
                      width: panStart!.width + drag.translation.width,
                      height: panStart!.height + drag.translation.height)
                  }
                }.onEnded { _ in panStart = nil })
            ForEach(map.markers) { marker in
              Button {
                selected = marker.recordID
              } label: {
                Image(systemName: "mappin.circle.fill").font(.system(size: 29)).symbolRenderingMode(
                  .palette
                ).foregroundStyle(.white, studio.t.accent).shadow(
                  color: .black.opacity(0.18), radius: 4)
              }.buttonStyle(.plain).help(
                studio.records.first { $0.id == marker.recordID }?.title ?? "Linked place"
              ).position(
                x: origin.x + (marker.x - 0.5) * width, y: origin.y + (marker.y - 0.5) * height)
            }
          }.clipped()
        } else {
          VStack(spacing: 18) {
            Image(systemName: "map").font(.system(size: 48, weight: .ultraLight)).foregroundStyle(
              studio.t.accent)
            Text("Your world doesn't need a map.\nUntil you want one.").font(
              .system(size: 31, design: .serif)
            ).multilineTextAlignment(.center)
            Text("Bring a PNG or JPEG, then connect its places to your lore.").font(
              .system(size: 14)
            ).foregroundStyle(studio.t.secondary).multilineTextAlignment(.center)
            Button("Choose a map") { upload() }.buttonStyle(QuietButton(t: studio.t))
          }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      HStack {
        if let id = placing {
          Text(
            "Click the map to place \(studio.records.first { $0.id == id }?.title ?? "this record")."
          ).font(.system(size: 12))
          Button("Cancel") { placing = nil }.buttonStyle(.plain)
        } else if let record = studio.records.first(where: { $0.id == selected }) {
          Button("Open \(record.title) ↗") { studio.openRecord(record) }.buttonStyle(.plain)
            .foregroundStyle(studio.t.accent)
        } else {
          Text("Your map stays on this device.").font(.system(size: 11)).foregroundStyle(
            studio.t.secondary)
        }
        Spacer()
        IconButton(icon: "minus", label: "Zoom out", t: studio.t) { zoom = max(0.5, zoom - 0.2) }
        Button("\(Int(zoom * 100))%") {
          zoom = 1
          pan = .zero
        }.buttonStyle(.plain).font(.system(size: 11))
        IconButton(icon: "plus", label: "Zoom in", t: studio.t) { zoom = min(5, zoom + 0.2) }
      }.padding(16)
    }.onAppear {
      studio.editorSave = { persist() }
      do {
        if let board = try studio.store.boards(worldID: studio.worldID, kind: "atlas").first {
          boardID = board.id
          map = try JSONDecoder().decode(AtlasDocument.self, from: Data(board.content.utf8))
        }
      } catch {
        loadFailed = true
        studio.error = error.localizedDescription
      }
    }
  }
  private func upload() {
    studio.perform {
      if let image = try pickImage() {
        map.image = image
        persist()
      }
    }
  }
  @discardableResult private func persist() -> Bool {
    guard !loadFailed else { return true }
    do {
      boardID = try studio.store.saveBoard(
        worldID: studio.worldID, id: boardID, name: "Atlas", kind: "atlas",
        content: String(decoding: try JSONEncoder().encode(map), as: UTF8.self)
      ).id
      return true
    } catch {
      studio.error = "Atlas could not save. Your changes remain open. " + error.localizedDescription
      return false
    }
  }
}
