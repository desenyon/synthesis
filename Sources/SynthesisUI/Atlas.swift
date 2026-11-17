import AppKit
import SwiftUI
import SynthesisCore

/// A creator-supplied map with markers that open real records. The image stays on this device.
struct AtlasScreen: View {
  @ObservedObject var studio: Studio
  @State private var markerPicker = false
  @State private var artworkPicker = false
  @State private var boardID: String?
  @State private var currentBoard: Board?
  @State private var maps: [Board] = []
  @State private var loadedMap = AtlasDocument()
  @State private var loadedWorld = ""
  @State private var details = false
  @State private var reloadConfirmation = false
  @State private var newMap = false
  @State private var loadFailed = false
  @State private var map = AtlasDocument()
  @State private var mapImage: NSImage?
  @State private var zoom = 1.0
  @State private var pan = CGSize.zero
  @State private var panAnchor: CGPoint?
  @State private var placing: String?
  @State private var selected: String?
  var body: some View {
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        PlainMenu(flexible: true) {
          MenuSection("Maps") {
            ForEach(maps) { board in
              Button(board.name) { switchMap(board.id) }
            }
          }
          Divider()
          Button("New map…") {
            newMap = true
            details = true
          }
        } label: {
          HStack(spacing: 8) {
            StudioIcon("map", size: 16)
            Text(currentBoard?.name ?? "Atlas").font(.studio(size: 16, weight: .semibold))
              .lineLimit(1)
            StudioIcon("chevron.down", size: 10)
          }.foregroundStyle(studio.t.text)
        }
        if let parent = maps.first(where: { $0.id == map.parentMapID }) {
          Button("In \(parent.name)") { switchMap(parent.id) }
            .buttonStyle(QuietButton(t: studio.t, role: .ghost)).lineLimit(1)
        }
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
        }
        IconMenu(icon: "ellipsis", label: "Map actions", t: studio.t) {
          Button("New map…") {
            newMap = true
            details = true
          }
          if map != loadedMap {
            Button("Reload saved map…") { reloadConfirmation = true }
          }
          if currentBoard != nil {
            Button("Map details…") {
              newMap = false
              details = true
            }
            Button("Remove map") { removeMap() }
          }
          if map.image != nil {
            Divider()
            Button("Replace map image…") { upload() }
            Button("Choose an illustration…") { artworkPicker = true }
          }
        }
      }
      GeometryReader { geo in
        if loadFailed {
          EmptyState(
            icon: "map", title: "This map could not be opened",
            message:
              "Its saved content has been left untouched. You can retry or choose another map.",
            t: studio.t
          ) {
            Button("Retry") { loadMap() }.buttonStyle(QuietButton(t: studio.t))
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let image = mapImage {
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
    .studioSheet(isPresented: $reloadConfirmation) {
      SheetScaffold(
        title: "Reload the saved map?",
        subtitle: "Unsaved map changes in this window will be discarded.", t: studio.t, width: 440,
        close: { reloadConfirmation = false }
      ) {
        Text("The stored image, markers and map details will replace the version currently open.")
          .font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
      } footer: {
        Spacer()
        Button("Keep changes") { reloadConfirmation = false }.buttonStyle(QuietButton(t: studio.t))
        Button("Reload saved map") {
          map = loadedMap
          loadMap()
          reloadConfirmation = false
        }.buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    }
    .studioSheet(isPresented: $details) {
      AtlasMapEditor(studio: studio, board: newMap ? nil : currentBoard, maps: maps) { board in
        details = false
        if let board { switchMap(board.id) }
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
      if studio.captureHint == "atlas-details" { details = true }
      if studio.captureHint == "atlas-new" {
        newMap = true
        details = true
      }
    }
    .onChange(of: studio.worldRevision) { _, _ in loadMap() }
    .onChange(of: studio.mapBoardID) { _, _ in loadMap() }
  }
  private func switchMap(_ id: String) {
    guard persist() else { return }
    studio.mapBoardID = id
    loadMap()
  }
  private func loadMap() {
    guard loadedWorld != studio.worldID || map == loadedMap else { return }
    do {
      maps = try studio.store.boards(worldID: studio.worldID, kind: "atlas")
      let board = maps.first(where: { $0.id == studio.mapBoardID }) ?? maps.first
      let changed = loadedWorld != studio.worldID || boardID != board?.id
      let next =
        try board.map { try JSONDecoder().decode(AtlasDocument.self, from: Data($0.content.utf8)) }
        ?? AtlasDocument()
      mapImage = ImageCache.image(base64: next.image)
      boardID = board?.id
      currentBoard = board
      map = next
      loadedMap = next
      loadedWorld = studio.worldID
      studio.mapBoardID = board?.id
      if changed {
        zoom = 1
        pan = .zero
        selected = nil
        placing = nil
      }
      loadFailed = false
    } catch {
      loadFailed = true
      studio.error = error.localizedDescription
    }
  }
  private func removeMap() {
    guard let board = currentBoard, persist() else { return }
    let world = loadedWorld
    studio.perform {
      try studio.store.archiveAtlasMap(worldID: world, id: board.id)
      studio.mapBoardID = nil
      loadMap()
      studio.show("Map removed", actionTitle: "Undo") {
        studio.perform {
          try studio.store.setBoardArchived(worldID: world, id: board.id, archived: false)
          try studio.reload()
        }
      }
      try studio.reload()
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
          changeZoom(
            factor,
            anchor: CGPoint(x: location.x - size.width / 2, y: location.y - size.height / 2))
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
            let previousID = map.markers.first { $0.recordID == id }?.id ?? UUID().uuidString
            map.markers.removeAll { $0.recordID == id }
            map.markers.append(
              MapMarker(
                id: previousID, recordID: id, x: min(1, max(0, value.location.x / width)),
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
        HStack(spacing: 8) {
          if let place = studio.records.first(where: { $0.id == map.placeID }) {
            Button {
              studio.openRecord(place)
            } label: {
              StudioLabel(place.title, icon: "mappin.and.ellipse").lineLimit(1)
            }.buttonStyle(QuietButton(t: studio.t))
          }
          let children = maps.filter {
            (try? AtlasLinks(content: $0.content).parentMapID) == boardID
          }
          if !children.isEmpty {
            PlainMenu {
              ForEach(children) { child in Button(child.name) { switchMap(child.id) } }
            } label: {
              StudioLabel("Local maps · \(children.count)", icon: "chevron.down")
                .font(.studio(size: 13, weight: .medium)).padding(.horizontal, 12)
                .frame(height: Metric.control).floatingPanel(studio.t)
            }
          }
          Spacer()
        }
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
            zoom: zoom, t: studio.t, zoomOut: { stepZoom(1 / 1.25) },
            zoomIn: { stepZoom(1.25) },
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
  private func changeZoom(_ factor: Double, anchor: CGPoint = .zero) {
    let next = SpatialViewport.zoom(
      scale: zoom, pan: pan, factor: factor, anchor: anchor, limits: 0.5...5)
    zoom = next.scale
    pan = next.pan
  }
  private func stepZoom(_ factor: Double) {
    withAnimation(.easeOut(duration: 0.18)) { changeZoom(factor) }
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
      Button("Move marker") {
        placing = marker.recordID
        selected = nil
      }
      Button("Remove marker") {
        let before = currentBoard
        map.markers.removeAll { $0.id == marker.id }
        if selected == marker.recordID { selected = nil }
        if persist() { offerUndo(before, title: "Marker removed") }
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
    let previous = currentBoard
    map.image = image
    mapImage = ImageCache.image(base64: image)
    zoom = 1
    pan = .zero
    if persist() {
      offerUndo(previous, title: "Map image updated")
    }
  }
  private func offerUndo(_ before: Board?, title: String) {
    guard let before, let after = currentBoard else {
      studio.show(title)
      return
    }
    let world = loadedWorld
    studio.show(title, actionTitle: "Undo") {
      studio.perform {
        _ = try studio.store.saveAtlasMap(
          worldID: world, id: before.id, name: before.name,
          content: before.content, expected: after)
        try studio.reload()
      }
    }
  }
  @discardableResult private func persist() -> Bool {
    guard !loadFailed else { return map == loadedMap }
    guard map != loadedMap else { return true }
    guard loadedWorld == studio.worldID else { return false }
    do {
      let saved = try studio.store.saveAtlasMap(
        worldID: loadedWorld, id: boardID, name: currentBoard?.name ?? "World map",
        content: String(decoding: try JSONEncoder().encode(map), as: UTF8.self),
        expected: currentBoard)
      currentBoard = saved
      boardID = saved.id
      loadedMap = map
      studio.mapBoardID = saved.id
      maps = try studio.store.boards(worldID: loadedWorld, kind: "atlas")
      return true
    } catch {
      studio.error = "Atlas could not save. Your changes remain open. " + error.localizedDescription
      return false
    }
  }
}
