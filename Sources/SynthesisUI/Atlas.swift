import AppKit
import SwiftUI
import SynthesisCore

/// A creator-supplied map with markers that open real records. The image stays on this device.
struct AtlasScreen: View {
  @ObservedObject var studio: Studio
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
  @State private var authoring = AtlasAuthoring()
  private var placing: String? { authoring.markerID }
  @State private var regionPicker = false
  private var drawingRecord: String? { authoring.regionRecordID }
  private var redrawing: String? { authoring.replacedRegionID }
  private var drawingPoints: [CGPoint] { authoring.points }
  private var unmarkedRecords: [LoreRecord] {
    let placed = Set(map.markers.map(\.recordID))
    return studio.records.filter { !placed.contains($0.id) }
  }
  @State private var selectedRegion: String?
  @State private var reshapeBefore: Board?
  @State private var showMarkers = true
  @State private var showRegions = true
  private var selected: String? {
    get { studio.atlasSelectedID }
    nonmutating set { studio.atlasSelectedID = newValue }
  }
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
            Text(currentBoard?.name ?? "Atlas").font(.studio(.cardTitle))
              .lineLimit(1)
            StudioIcon("chevron.down", size: 10)
          }.foregroundStyle(studio.t.text)
        }.frame(minWidth: 120, alignment: .leading)
        if let parent = maps.first(where: { $0.id == map.parentMapID }) {
          Button("In \(parent.name)") { switchMap(parent.id) }
            .buttonStyle(QuietButton(t: studio.t, role: .ghost)).lineLimit(1)
        }
      } trailing: {
        if map.image != nil {
          BarAction(title: "Place marker", icon: "mappin.and.ellipse", t: studio.t, primary: true) {
            markerPicker = true
          }.disabled(unmarkedRecords.isEmpty)
            .help(
              unmarkedRecords.isEmpty
                ? "Every record already has a marker on this map"
                : "Choose a record, then click the map"
            )
            .popover(isPresented: $markerPicker) {
              SearchableRecordPicker(
                records: unmarkedRecords, t: studio.t
              ) { record in
                startPlacing(record.id)
                markerPicker = false
              }
            }
        }
        if map.image != nil {
          BarAction(title: "Draw region", icon: "hexagon", t: studio.t) {
            regionPicker = true
          }.disabled(studio.records.isEmpty)
            .help("Choose a record, then click around its area on the map")
            .popover(isPresented: $regionPicker) {
              SearchableRecordPicker(records: studio.records, t: studio.t) { record in
                startDrawing(record.id, replacing: nil)
                regionPicker = false
              }
            }
        }
        IconMenu(icon: "ellipsis", label: "Map actions", t: studio.t) {
          if map.image != nil {
            Toggle("Show markers", isOn: $showMarkers)
            Toggle("Show regions", isOn: $showRegions)
            Divider()
          }
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
        t: studio.t, mapOnly: true, studio: studio,
        select: { data in
          replaceImage(data.base64EncodedString())
          artworkPicker = false
        }, close: { artworkPicker = false })
    }
    .onAppear {
      studio.editorSave = { persist() }
      loadMap()
      if studio.captureHint == "atlas-details" { details = true }
      if studio.captureHint == "sheet-generate" { artworkPicker = true }
      if studio.captureHint == "atlas-regions" {
        selectedRegion = map.regions.first?.id
        selected = map.regions.first?.recordID
      }
      if studio.captureHint.hasSuffix("atlas-drawing"),
        let city = studio.records.first(where: { $0.title == "The Drowned City" })
      {
        startDrawing(city.id, replacing: nil)
        for point in [
          CGPoint(x: 0.64, y: 0.6), CGPoint(x: 0.76, y: 0.58), CGPoint(x: 0.79, y: 0.7),
          CGPoint(x: 0.67, y: 0.74),
        ] { authoring.addPoint(point) }
      }
      if studio.captureHint == "atlas-placing",
        let city = studio.records.first(where: { $0.title == "The Drowned City" })
      {
        startPlacing(city.id)
      }
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
    studio.openBoard(id, kind: "atlas")
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
        if let selected, !map.markers.contains(where: { $0.recordID == selected }),
          !map.regions.contains(where: { $0.recordID == selected })
        {
          self.selected = nil
        }
        selectedRegion = nil
        authoring.choose(.browse)
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
          guard drawingRecord == nil else { return }
          selected = nil
          selectedRegion = nil
          authoring.choose(.browse)
        },
        onDrag: { start, current, phase in
          let last = panAnchor ?? start
          pan.width += current.x - last.x
          pan.height += current.y - last.y
          panAnchor = phase == .ended ? nil : current
        },
        onKey: { event in
          guard event.keyCode == 53 else { return false }
          if drawingRecord != nil {
            cancelDrawing()
            return true
          }
          authoring.choose(.browse)
          selected = nil
          selectedRegion = nil
          return true
        })
      Image(nsImage: image).resizable().frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(
          RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.hairline, lineWidth: 1)
        )
        .shadow(color: studio.t.shadow.opacity(0.5), radius: 18, y: 6)
        .position(origin).allowsHitTesting(placing != nil || drawingRecord != nil)
        .gesture(
          SpatialTapGesture().onEnded { value in
            if drawingRecord != nil {
              authoring.addPoint(
                CGPoint(
                  x: min(1, max(0, value.location.x / width)),
                  y: min(1, max(0, value.location.y / height))))
              return
            }
            guard let id = placing else { return }
            let before = currentBoard
            let previousID = map.markers.first { $0.recordID == id }?.id ?? UUID().uuidString
            map.markers.removeAll { $0.recordID == id }
            map.markers.append(
              MapMarker(
                id: previousID, recordID: id, x: min(1, max(0, value.location.x / width)),
                y: min(1, max(0, value.location.y / height))))
            authoring.choose(.browse)
            selected = id
            if persist() { offerUndo(before, title: "Marker placed") }
          }
        )
        .accessibilityLabel("World map")
      if showRegions {
        ForEach(map.regions) { region in
          regionView(region, origin: origin, width: width, height: height)
        }
      }
      if drawingRecord != nil {
        drawingPreview(origin: origin, width: width, height: height)
      }
      if showMarkers {
        ForEach(map.markers) { marker in
          markerView(marker)
            .position(
              x: origin.x + (marker.x - 0.5) * width, y: origin.y + (marker.y - 0.5) * height
            )
            .allowsHitTesting(drawingRecord == nil)
        }
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
                .font(.studio(.label)).padding(.horizontal, 12)
                .frame(height: Metric.control).floatingPanel(studio.t)
            }
          }
          Spacer()
        }
        if let id = drawingRecord {
          HStack(spacing: 10) {
            StudioIcon("hexagon").foregroundStyle(studio.t.accent)
            Text(
              "Click around “\(studio.records.first { $0.id == id }?.title ?? "record")” · \(drawingPoints.count) \(drawingPoints.count == 1 ? "point" : "points")"
            ).font(.studio(size: 13)).lineLimit(1)
            Button("Undo point") { authoring.undoPoint() }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost)).disabled(drawingPoints.isEmpty)
            Button("Cancel") { cancelDrawing() }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost))
            Button("Done") { finishDrawing() }
              .buttonStyle(QuietButton(t: studio.t, primary: true))
              .disabled(drawingPoints.count < 3)
          }.padding(.leading, 14).padding(.trailing, 6).frame(height: 40).floatingPanel(studio.t)
        }
        if let id = placing {
          HStack(spacing: 10) {
            StudioIcon("mappin.and.ellipse").foregroundStyle(studio.t.accent)
            Text(
              "Click the map to place “\(studio.records.first { $0.id == id }?.title ?? "record")”"
            )
            .font(.studio(size: 13))
            Button("Cancel") { authoring.choose(.browse) }.buttonStyle(.plain)
              .font(.studio(.label)).foregroundStyle(studio.t.accent)
          }.padding(.horizontal, 14).frame(height: 36).floatingPanel(studio.t)
        }
        Spacer()
        HStack(alignment: .bottom) {
          if !studio.workspaceInspector,
            let record = studio.records.first(where: { $0.id == selected })
          {
            HStack(spacing: 10) {
              CategoryTile(record: record, t: studio.t, size: 30)
              VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.studio(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(
                  record.body.isEmpty ? Vocabulary.displayCategory(record.category) : record.body
                )
                .font(.studio(.caption)).foregroundStyle(studio.t.muted).lineLimit(1)
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
              withAnimation(reduceMotion ? nil : Motion.panelAnimation) {
                zoom = 1
                pan = .zero
              }
            })
        }
      }.padding(14)
    }.coordinateSpace(name: "atlas-map").clipped()
  }
  private func point(_ value: [Double], _ origin: CGPoint, _ width: Double, _ height: Double)
    -> CGPoint
  {
    CGPoint(x: origin.x + (value[0] - 0.5) * width, y: origin.y + (value[1] - 0.5) * height)
  }
  private func regionPath(
    _ points: [[Double]], _ origin: CGPoint, _ width: Double, _ height: Double
  ) -> Path {
    Path { path in
      for (index, value) in points.enumerated() where value.count == 2 {
        let p = point(value, origin, width, height)
        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
      path.closeSubpath()
    }
  }
  private func regionView(_ region: MapRegion, origin: CGPoint, width: Double, height: Double)
    -> some View
  {
    let record = studio.records.first { $0.id == region.recordID }
    let tint = record.map { studio.t.category($0.category) } ?? studio.t.muted
    let active = selectedRegion == region.id
    let path = regionPath(region.points, origin, width, height)
    let count = Double(max(1, region.points.count))
    let center = point(
      [
        region.points.map { $0.first ?? 0.5 }.reduce(0, +) / count,
        region.points.map { $0.last ?? 0.5 }.reduce(0, +) / count,
      ], origin, width, height)
    return ZStack {
      // A pale under-stroke keeps the outline legible on dark or busy map imagery.
      path.stroke(
        Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
      path.stroke(
        active ? studio.t.selectionBorder : tint.opacity(0.95),
        style: StrokeStyle(
          lineWidth: active ? 1.5 : 1, lineJoin: .round, dash: active ? [] : [6, 4]))
      // A marker for the same record already carries its name.
      if !(showMarkers && map.markers.contains { $0.recordID == region.recordID }) {
        Text(record?.title ?? "Archived record").font(.studio(.sectionLabel))
          .foregroundStyle(studio.t.text).padding(.horizontal, 6).frame(height: 18)
          .background(studio.t.surface.opacity(0.85), in: Capsule()).position(center)
          .allowsHitTesting(false)
      }
      if active && drawingRecord == nil {
        ForEach(Array(region.points.enumerated()), id: \.offset) { index, value in
          Circle().fill(studio.t.surface).overlay(
            Circle().stroke(studio.t.selectionBorder, lineWidth: 1.5)
          )
          .frame(width: 11, height: 11).contentShape(Circle().inset(by: -6))
          .position(point(value, origin, width, height))
          .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("atlas-map"))
              .onChanged { drag in
                guard let i = map.regions.firstIndex(where: { $0.id == region.id }),
                  map.regions[i].points.indices.contains(index)
                else { return }
                if reshapeBefore == nil { reshapeBefore = currentBoard }
                map.regions[i].points[index] = [
                  min(1, max(0, (drag.location.x - (origin.x - width / 2)) / width)),
                  min(1, max(0, (drag.location.y - (origin.y - height / 2)) / height)),
                ]
              }
              .onEnded { _ in
                let before = reshapeBefore
                reshapeBefore = nil
                if persist() { offerUndo(before, title: "Region reshaped") }
              }
          )
          .help("Drag to reshape").accessibilityLabel("Region point \(index + 1)")
        }
      }
    }
    .entitySurface(studio.t, selected: active, shape: path, base: tint.opacity(0.16))
    .contentShape(path)
    .onTapGesture {
      if NSApp.currentEvent?.clickCount == 2, let record {
        studio.openRecord(record)
      } else {
        selectedRegion = region.id
        selected = region.recordID
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Region: \(record?.title ?? "archived record")")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction {
      selectedRegion = region.id
      selected = region.recordID
    }
    .contextMenu {
      if let record { Button("Open record") { studio.openRecord(record) } }
      Button("Redraw region") { startDrawing(region.recordID, replacing: region.id) }
      Button("Remove region") {
        let before = currentBoard
        map.regions.removeAll { $0.id == region.id }
        if selectedRegion == region.id { selectedRegion = nil }
        if persist() { offerUndo(before, title: "Region removed") }
      }
    }
    .allowsHitTesting(drawingRecord == nil && placing == nil)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Region: \(record?.title ?? "archived record")")
  }
  private func drawingPreview(origin: CGPoint, width: Double, height: Double) -> some View {
    let points = drawingPoints.map { point([$0.x, $0.y], origin, width, height) }
    return ZStack {
      Path { path in
        for (index, p) in points.enumerated() {
          if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        if points.count >= 3 { path.closeSubpath() }
      }.fill(studio.t.accent.opacity(points.count >= 3 ? 0.14 : 0))
      Path { path in
        for (index, p) in points.enumerated() {
          if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
      }.stroke(studio.t.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
      ForEach(Array(points.enumerated()), id: \.offset) { _, p in
        Circle().fill(studio.t.accent).frame(width: 8, height: 8).position(p)
      }
    }.allowsHitTesting(false)
  }
  private func startPlacing(_ recordID: String) {
    guard studio.records.contains(where: { $0.id == recordID }) else { return }
    authoring.choose(.marker(recordID))
    selected = nil
    selectedRegion = nil
  }
  private func startDrawing(_ recordID: String, replacing: String?) {
    guard studio.records.contains(where: { $0.id == recordID }) else { return }
    selected = nil
    selectedRegion = nil
    authoring.choose(.region(record: recordID, replacing: replacing))
  }
  private func cancelDrawing() { authoring.choose(.browse) }
  private func finishDrawing() {
    guard let recordID = drawingRecord, drawingPoints.count >= 3 else { return }
    let before = currentBoard
    let points = drawingPoints.map { [Double($0.x), Double($0.y)] }
    if let id = redrawing, let index = map.regions.firstIndex(where: { $0.id == id }) {
      map.regions[index].points = points
    } else {
      map.regions.append(MapRegion(recordID: recordID, points: points))
    }
    let created = redrawing ?? map.regions.last?.id
    let title = redrawing == nil ? "Region added" : "Region redrawn"
    cancelDrawing()
    if persist() {
      selectedRegion = created
      selected = recordID
      offerUndo(before, title: title)
    }
  }
  private func changeZoom(_ factor: Double, anchor: CGPoint = .zero) {
    let next = SpatialViewport.zoom(
      scale: zoom, pan: pan, factor: factor, anchor: anchor, limits: 0.5...5)
    zoom = next.scale
    pan = next.pan
  }
  private func stepZoom(_ factor: Double) {
    withAnimation(reduceMotion ? nil : Motion.panelAnimation) { changeZoom(factor) }
  }
  private func markerView(_ marker: MapMarker) -> some View {
    let record = studio.records.first { $0.id == marker.recordID }
    let active = selected == marker.recordID
    let tint = record.map { studio.t.category($0.category) } ?? studio.t.muted
    return VStack(spacing: 3) {
      StudioIcon("mappin.circle.fill", size: 24)
        .foregroundStyle(active ? studio.t.selectionBorder : tint)
        .background(studio.t.surface.opacity(0.96), in: Circle())
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
      Text(record?.title ?? "Archived record").font(.studio(size: 11.5, weight: .medium))
        .lineLimit(1).padding(.horizontal, 6).frame(height: 18)
        .entitySurface(
          studio.t, selected: active, shape: Capsule(), base: studio.t.surface.opacity(0.92),
          bordered: true
        )
        .foregroundStyle(studio.t.text)
    }
    .onTapGesture {
      if NSApp.currentEvent?.clickCount == 2, let record {
        studio.openRecord(record)
      } else {
        selectedRegion = nil
        selected = marker.recordID
      }
    }
    .contextMenu {
      if let record { Button("Open record") { studio.openRecord(record) } }
      Button("Move marker") {
        startPlacing(marker.recordID)
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
    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction {
      selectedRegion = nil
      selected = marker.recordID
    }
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
