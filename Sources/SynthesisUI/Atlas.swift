import AppKit
import SwiftUI
import SynthesisCore

/// A creator-supplied map with markers that open real records. The image stays on this device.
struct AtlasScreen: View {
  @ObservedObject var studio: Studio
  @State private var markerPicker = false
  @State private var artworkPicker = false
  @State private var boardID: String?
  @State private var loadFailed = false
  @State private var map = AtlasDocument()
  @State private var zoom = 1.0
  @State private var pan = CGSize.zero
  @State private var panAnchor: CGPoint?
  @State private var placing: String?
  @State private var selected: String?
  var body: some View {
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: Destination.atlas.icon, title: "Atlas",
          detail: map.image == nil
            ? nil : "\(map.markers.count) \(map.markers.count == 1 ? "marker" : "markers")",
          t: studio.t)
      } trailing: {
        if map.image != nil {
          Button {
            markerPicker = true
          } label: {
            StudioLabel("Place marker", icon: "mappin.and.ellipse")
              .font(.studio(size: 13, weight: .medium)).foregroundStyle(studio.t.onAccent)
              .padding(.horizontal, 12).frame(height: Metric.control)
              .background(studio.t.accent, in: RoundedRectangle(cornerRadius: Metric.radius))
          }.buttonStyle(.plain).disabled(studio.records.isEmpty)
            .help("Choose a record, then click the map")
            .popover(isPresented: $markerPicker) {
              SearchableRecordPicker(
                records: studio.records.filter { record in
                  !map.markers.contains { $0.recordID == record.id }
                }, t: studio.t
              ) { record in
                placing = record.id
                markerPicker = false
              }
            }
          IconMenu(icon: "ellipsis", label: "Map actions", t: studio.t) {
            Button("Replace map image…") { upload() }
            Button("Choose an illustration…") { artworkPicker = true }
          }
        }
      }
      GeometryReader { geo in
        if let image = ImageCache.image(base64: map.image) {
          mapView(image, size: geo.size)
        } else {
          EmptyState(
            icon: Destination.atlas.icon, title: "No map yet",
            message:
              "Bring a drawing or a rendered map, then pin the places, people and events of this world to it.",
            t: studio.t
          ) {
            Button("Choose a map image…") { upload() }
              .buttonStyle(QuietButton(t: studio.t, primary: true))
            Button("Sample illustrations…") { artworkPicker = true }
              .buttonStyle(QuietButton(t: studio.t))
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .studioSheet(isPresented: $artworkPicker) {
      ArtworkPicker(
        t: studio.t, mapOnly: true,
        select: { data in
          replaceImage(data.base64EncodedString())
          artworkPicker = false
        }, close: { artworkPicker = false })
    }
    .onAppear {
      studio.editorSave = { persist() }
      loadMap()
    }
    .onChange(of: studio.worldRevision) { _, _ in loadMap() }
    .onChange(of: studio.mapBoardID) { _, _ in loadMap() }
  }
  private func loadMap() {
    do {
      let boards = try studio.store.boards(worldID: studio.worldID, kind: "atlas")
      if let board = boards.first(where: { $0.id == studio.mapBoardID }) ?? boards.first {
        boardID = board.id
        map = try JSONDecoder().decode(AtlasDocument.self, from: Data(board.content.utf8))
      } else {
        boardID = nil
        map = AtlasDocument()
      }
      loadFailed = false
    } catch {
      loadFailed = true
      studio.error = error.localizedDescription
    }
  }
  private func mapView(_ image: NSImage, size: CGSize) -> some View {
    let ratio = image.size.width / max(1, image.size.height)
    let width = min(size.width - 56, (size.height - 56) * ratio) * zoom
    let height = width / ratio
    let origin = CGPoint(x: size.width / 2 + pan.width, y: size.height / 2 + pan.height)
    return ZStack {
      CanvasInputSurface(
        onPan: {
          pan.width += $0.width
          pan.height += $0.height
        },
        onZoom: { factor, location in
          let next = min(5, max(0.5, zoom * factor))
          let ratio = next / zoom
          let anchor = CGPoint(x: location.x - size.width / 2, y: location.y - size.height / 2)
          pan.width = anchor.x - (anchor.x - pan.width) * ratio
          pan.height = anchor.y - (anchor.y - pan.height) * ratio
          zoom = next
        },
        onClick: {
          selected = nil
          placing = nil
        },
        onDrag: { start, current, phase in
          let last = panAnchor ?? start
          pan.width += current.x - last.x
          pan.height += current.y - last.y
          panAnchor = phase == .ended ? nil : current
        },
        onKey: { event in
          guard event.keyCode == 53 else { return false }
          placing = nil
          selected = nil
          return true
        })
      Image(nsImage: image).resizable().frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(studio.t.hairline, lineWidth: 1))
        .shadow(color: studio.t.shadow.opacity(0.5), radius: 18, y: 6)
        .position(origin).allowsHitTesting(placing != nil)
        .gesture(
          SpatialTapGesture().onEnded { value in
            guard let id = placing else { return }
            map.markers.append(
              MapMarker(
                recordID: id, x: min(1, max(0, value.location.x / width)),
                y: min(1, max(0, value.location.y / height))))
            placing = nil
            selected = id
            persist()
          }
        )
        .accessibilityLabel("World map")
      ForEach(map.markers) { marker in
        markerView(marker)
          .position(
            x: origin.x + (marker.x - 0.5) * width, y: origin.y + (marker.y - 0.5) * height)
      }
      VStack {
        if let id = placing {
          HStack(spacing: 10) {
            StudioIcon("mappin.and.ellipse").foregroundStyle(studio.t.accent)
            Text(
              "Click the map to place “\(studio.records.first { $0.id == id }?.title ?? "record")”"
            )
            .font(.studio(size: 13))
            Button("Cancel") { placing = nil }.buttonStyle(.plain)
              .font(.studio(size: 13, weight: .medium)).foregroundStyle(studio.t.accent)
          }.padding(.horizontal, 14).frame(height: 36).floatingPanel(studio.t)
        }
        Spacer()
        HStack(alignment: .bottom) {
          if let record = studio.records.first(where: { $0.id == selected }) {
            HStack(spacing: 10) {
              CategoryTile(record: record, t: studio.t, size: 30)
              VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.studio(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(
                  record.body.isEmpty ? Vocabulary.displayCategory(record.category) : record.body
                )
                .font(.studio(size: 12)).foregroundStyle(studio.t.muted).lineLimit(1)
              }.frame(maxWidth: 240, alignment: .leading)
              Button("Open") { studio.openRecord(record) }
                .buttonStyle(QuietButton(t: studio.t))
            }.padding(8).floatingPanel(studio.t)
          }
          Spacer()
          ZoomControls(
            zoom: zoom, t: studio.t, zoomOut: { zoom = max(0.5, zoom / 1.25) },
            zoomIn: { zoom = min(5, zoom * 1.25) },
            fit: {
              withAnimation(.easeOut(duration: 0.2)) {
                zoom = 1
                pan = .zero
              }
            })
        }
      }.padding(14)
    }.clipped()
  }
  private func markerView(_ marker: MapMarker) -> some View {
    let record = studio.records.first { $0.id == marker.recordID }
    let active = selected == marker.recordID
    let tint = record.map { studio.t.category($0.category) } ?? studio.t.muted
    return VStack(spacing: 3) {
      StudioIcon("mappin.circle.fill", size: active ? 28 : 24)
        .symbolRenderingMode(.palette).foregroundStyle(Color.white, tint)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
      Text(record?.title ?? "Archived record").font(.studio(size: 11.5, weight: .medium))
        .lineLimit(1).padding(.horizontal, 6).frame(height: 18)
        .background(studio.t.surface.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(active ? tint : studio.t.hairline, lineWidth: 1))
        .foregroundStyle(studio.t.text)
    }
    .onTapGesture {
      if NSApp.currentEvent?.clickCount == 2, let record {
        studio.openRecord(record)
      } else {
        selected = active ? nil : marker.recordID
      }
    }
    .contextMenu {
      if let record { Button("Open record") { studio.openRecord(record) } }
      Button("Remove marker") {
        let removed = marker
        map.markers.removeAll { $0.id == marker.id }
        if selected == marker.recordID { selected = nil }
        persist()
        studio.show("Marker removed", icon: "minus.circle", actionTitle: "Undo") {
          map.markers.append(removed)
          persist()
        }
      }
    }
    .help(record?.title ?? "Archived record")
    .accessibilityLabel("Marker: \(record?.title ?? "archived record")")
    .accessibilityAddTraits(.isButton)
  }
  private func upload() {
    studio.perform {
      if let image = try pickImage() {
        replaceImage(image)
      }
    }
  }
  private func replaceImage(_ image: String) {
    let previous = map
    map.image = image
    zoom = 1
    pan = .zero
    if persist() {
      studio.show("Map image updated", icon: "photo", actionTitle: "Undo") {
        map = previous
        persist()
      }
    }
  }
  @discardableResult private func persist() -> Bool {
    guard !loadFailed else { return true }
    guard boardID != nil || map.image != nil || !map.markers.isEmpty else { return true }
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
