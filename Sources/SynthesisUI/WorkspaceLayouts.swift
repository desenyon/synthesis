import SwiftUI
import SynthesisCore

public enum RecordPageTab: String, Codable { case overview, sections, mechanics }

/// Device-local presentation, scoped to one universe. No writing or model permissions are saved.
struct WorkspaceArrangement: Codable, Equatable {
  var location: NavigationLocation
  var collapsed: Bool
  var inspector: Bool
  var workspaceInspector: Bool
  var inspectionTarget: InspectionTarget?
  var companion: Bool
  var companionWidth: Double
  var density: InformationDensity
  var readingWidth: Int
  var entityTab: RecordPageTab
}
struct WorkspaceLayout: Codable, Equatable, Identifiable {
  var id: String
  var name: String
  var createdAt: String
  var updatedAt: String
  var archived = false
  var arrangement: WorkspaceArrangement
}
private struct LayoutArchive: Codable {
  var version = 1
  var layouts: [WorkspaceLayout]
}

extension Studio {
  var workspaceArrangement: WorkspaceArrangement {
    WorkspaceArrangement(
      location: navigationLocation, collapsed: collapsed, inspector: inspector,
      workspaceInspector: workspaceInspector, inspectionTarget: inspectionTarget,
      companion: companionExpanded, companionWidth: companionWidth,
      density: preferences.density, readingWidth: preferences.readingWidth,
      entityTab: selectedRecord.flatMap { recordTabs[$0.id] } ?? .overview)
  }
  func savedLayouts(includeArchived: Bool = false) throws -> [WorkspaceLayout] {
    guard let raw = try store.preference("workspace-layouts:\(worldID)") else { return [] }
    let archive: LayoutArchive
    do { archive = try JSONDecoder().decode(LayoutArchive.self, from: Data(raw.utf8)) } catch {
      throw SynthesisError.invalid(
        "Saved layouts could not be read. The original data is preserved.")
    }
    guard archive.version == 1,
      Set(archive.layouts.map(\.id)).count == archive.layouts.count,
      archive.layouts.allSatisfy({ $0.arrangement.location.worldID == worldID })
    else {
      throw SynthesisError.invalid("These saved layouts do not belong to this universe or format.")
    }
    return archive.layouts.filter { includeArchived || !$0.archived }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
  private func writeLayouts(_ layouts: [WorkspaceLayout]) throws {
    try store.setPreference(
      "workspace-layouts:\(worldID)",
      value: String(decoding: JSONEncoder().encode(LayoutArchive(layouts: layouts)), as: UTF8.self))
    layoutRevision += 1
  }
  private func layoutName(
    _ name: String, in layouts: [WorkspaceLayout], excluding id: String? = nil
  ) throws -> String {
    let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.count <= 80 else {
      throw SynthesisError.invalid("Give the layout a name of 1–80 characters.")
    }
    guard
      !layouts.contains(where: {
        !$0.archived && $0.id != id
          && $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame
      })
    else {
      throw SynthesisError.invalid(
        "A layout already uses that name. Rename it or choose Update to replace its arrangement.")
    }
    return value
  }
  @discardableResult func saveLayout(name: String) throws -> WorkspaceLayout {
    guard flushEditor() else {
      throw SynthesisError.invalid("Save the current writing before saving a layout.")
    }
    var layouts = try savedLayouts(includeArchived: true)
    let name = try layoutName(name, in: layouts)
    let now = Date().ISO8601Format()
    let layout = WorkspaceLayout(
      id: UUID().uuidString, name: name, createdAt: now, updatedAt: now,
      arrangement: workspaceArrangement)
    layouts.append(layout)
    try writeLayouts(layouts)
    return layout
  }
  func renameLayout(_ id: String, name: String) throws {
    var layouts = try savedLayouts(includeArchived: true)
    guard let index = layouts.firstIndex(where: { $0.id == id && !$0.archived }) else {
      throw SynthesisError.notFound
    }
    layouts[index].name = try layoutName(name, in: layouts, excluding: id)
    layouts[index].updatedAt = Date().ISO8601Format()
    try writeLayouts(layouts)
  }
  func updateLayout(_ id: String) throws {
    guard flushEditor() else {
      throw SynthesisError.invalid("Save the current writing before updating a layout.")
    }
    var layouts = try savedLayouts(includeArchived: true)
    guard let index = layouts.firstIndex(where: { $0.id == id && !$0.archived }) else {
      throw SynthesisError.notFound
    }
    let previous = layouts[index]
    layouts[index].arrangement = workspaceArrangement
    layouts[index].updatedAt = Date().ISO8601Format()
    let updated = layouts[index]
    try writeLayouts(layouts)
    offerLayoutUndo(previous: previous, expected: updated, message: "Updated “\(updated.name)”")
  }
  func archiveLayout(_ id: String, archived: Bool = true) throws {
    var layouts = try savedLayouts(includeArchived: true)
    guard let index = layouts.firstIndex(where: { $0.id == id }) else {
      throw SynthesisError.notFound
    }
    if !archived { _ = try layoutName(layouts[index].name, in: layouts, excluding: id) }
    let previous = layouts[index]
    layouts[index].archived = archived
    layouts[index].updatedAt = Date().ISO8601Format()
    let updated = layouts[index]
    try writeLayouts(layouts)
    offerLayoutUndo(
      previous: previous, expected: updated,
      message: "\(archived ? "Archived" : "Restored") “\(updated.name)”")
  }
  private func offerLayoutUndo(
    previous: WorkspaceLayout, expected: WorkspaceLayout, message: String
  ) {
    let world = worldID
    show(message, actionTitle: "Undo") { [weak self] in
      guard let self, self.worldID == world else { return }
      self.perform {
        var layouts = try self.savedLayouts(includeArchived: true)
        guard let index = layouts.firstIndex(where: { $0.id == expected.id }),
          layouts[index] == expected
        else {
          throw SynthesisError.stale
        }
        _ = try self.layoutName(previous.name, in: layouts, excluding: previous.id)
        layouts[index] = previous
        try self.writeLayouts(layouts)
      }
    }
  }
  @discardableResult func applyLayout(_ id: String) -> Bool {
    var applied = false
    withNavigation {
      perform {
        guard let layout = try savedLayouts().first(where: { $0.id == id }) else {
          throw SynthesisError.notFound
        }
        let arrangement = layout.arrangement
        try validateNavigation(arrangement.location)
        guard flushEditor() else { return }
        guard restoreNavigation(arrangement.location) else { return }
        collapsed = arrangement.collapsed
        inspector = arrangement.inspector
        workspaceInspector = arrangement.workspaceInspector
        inspectionTarget = arrangement.inspectionTarget
        if let target = inspectionTarget, (try? inspectionData(for: target)) == nil {
          inspectionTarget = nil
        }
        companionExpanded = mode == .assisted && arrangement.companion
        companionWidth =
          arrangement.companionWidth.isFinite ? min(460, max(320, arrangement.companionWidth)) : 400
        if let record = selectedRecord { recordTabs[record.id] = arrangement.entityTab }
        var nextPreferences = preferences
        nextPreferences.density = arrangement.density
        nextPreferences.readingWidth = arrangement.readingWidth
        nextPreferences = nextPreferences.validated
        try store.setPreferences([
          "sidebar": collapsed ? "collapsed" : "expanded",
          "inspector": inspector ? "shown" : "hidden",
          "workspace-inspector": workspaceInspector ? "shown" : "hidden",
          "companion-width": String(companionWidth),
          "studio-preferences": String(
            decoding: JSONEncoder().encode(nextPreferences), as: UTF8.self),
        ])
        preferences = nextPreferences
        applied = true
        show("Opened “\(layout.name)”")
      }
    }
    return applied
  }
}

struct WorkspaceLayoutsSheet: View {
  @ObservedObject var studio: Studio
  @State private var name = ""
  @State private var renaming: String?
  @State private var items: [WorkspaceLayout] = []
  @State private var failure: String?
  @State private var archivedExpanded = false
  private var active: [WorkspaceLayout] { items.filter { !$0.archived } }
  private var archived: [WorkspaceLayout] { items.filter(\.archived) }
  var body: some View {
    SheetScaffold(
      title: "Workspace layouts",
      subtitle: "Save views and panel arrangements for \(studio.world?.name ?? "this universe").",
      t: studio.t, width: 600, close: { studio.sheet = nil }
    ) {
      VStack(alignment: .leading, spacing: 12) {
        Text(renaming == nil ? "Save the current arrangement" : "Rename layout")
          .font(.studio(.control))
        HStack(spacing: 10) {
          FormField(
            placeholder: "Research, Writing, Cartography…", text: $name, t: studio.t, submit: save)
          Button(renaming == nil ? "Save layout" : "Rename", action: save)
            .buttonStyle(QuietButton(t: studio.t, primary: true))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          if renaming != nil {
            IconButton(icon: "xmark", label: "Cancel rename", t: studio.t) {
              name = ""
              renaming = nil
            }
          }
        }
        Text("Layouts stay on this Mac. Applying one keeps your writing and AI mode unchanged.")
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      }
      if let failure { Text(failure).font(.studio(.label)).foregroundStyle(studio.t.danger) }
      if active.isEmpty {
        Text("Save your first layout to return to this arrangement later.")
          .font(.studio(.label)).foregroundStyle(studio.t.secondary).padding(.vertical, 16)
      }
      if !items.isEmpty {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(active) { row($0) }
            if !archived.isEmpty {
              DisclosureGroup("Archived layouts · \(archived.count)", isExpanded: $archivedExpanded)
              {
                VStack(spacing: 2) { ForEach(archived) { row($0) } }.padding(.top, 8)
              }.font(.studio(.label)).tint(studio.t.secondary)
            }
          }
        }.frame(
          height: min(
            320,
            CGFloat(
              active.count * 70 + (archived.isEmpty ? 0 : 40)
                + (archivedExpanded ? archived.count * 70 : 0))))
      }
    } footer: {
      Spacer()
      Button("Done") { studio.sheet = nil }.buttonStyle(QuietButton(t: studio.t))
    }
    .task(id: "\(studio.worldID):\(studio.layoutRevision)") { load() }
  }
  private func row(_ layout: WorkspaceLayout) -> some View {
    HStack(spacing: 12) {
      StudioIcon(layout.arrangement.location.destination.icon, size: 17)
        .foregroundStyle(studio.t.secondary).frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(layout.name).font(.studio(.control)).lineLimit(1).help(layout.name)
        Text(detail(layout)).font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(
          2)
      }.frame(maxWidth: .infinity, alignment: .leading)
      if layout.archived {
        Button("Restore") { run { try studio.archiveLayout(layout.id, archived: false) } }
          .buttonStyle(QuietButton(t: studio.t, role: .ghost))
      } else {
        Button("Open") {
          if studio.applyLayout(layout.id) { studio.sheet = nil }
        }.buttonStyle(QuietButton(t: studio.t))
        IconMenu(icon: "ellipsis", label: "Actions for \(layout.name)", t: studio.t) {
          Button("Rename…") {
            name = layout.name
            renaming = layout.id
          }
          Button("Update with current arrangement") { run { try studio.updateLayout(layout.id) } }
          Divider()
          Button("Archive layout") { run { try studio.archiveLayout(layout.id) } }
        }
      }
    }.padding(.vertical, 10).padding(.horizontal, 8).hoverFill(studio.t)
  }
  private func detail(_ layout: WorkspaceLayout) -> String {
    let a = layout.arrangement
    let subject =
      a.location.recordID.flatMap { id in studio.records.first { $0.id == id }?.title }
      ?? a.location.category ?? a.location.destination.rawValue
    return [
      subject, a.density.rawValue.capitalized,
      (a.location.recordID == nil ? a.workspaceInspector : a.inspector) ? "Inspector" : nil,
    ]
    .compactMap { $0 }.joined(separator: " · ")
  }
  private func load() {
    do {
      items = try studio.savedLayouts(includeArchived: true)
      failure = nil
    } catch { failure = error.localizedDescription }
  }
  private func run(_ action: () throws -> Void) {
    do {
      try action()
      load()
    } catch { failure = error.localizedDescription }
  }
  private func save() {
    run {
      if let renaming {
        try studio.renameLayout(renaming, name: name)
      } else {
        try studio.saveLayout(name: name)
      }
      name = ""
      renaming = nil
    }
  }
}
