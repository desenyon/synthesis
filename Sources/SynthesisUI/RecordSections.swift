import SwiftUI
import SynthesisCore

/// Creator-defined sections share the same records, citations and editor as the Library.
struct RecordSectionsPage: View {
  @ObservedObject var studio: Studio
  let parent: LoreRecord
  @State private var sections: [RecordSection] = []
  @State private var components: [CreativeComponent] = []
  @State private var removed: [RecordSection] = []
  @State private var creating = false
  @State private var showRemoved = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      ContentColumn {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            Text("Sections").font(.studio(.cardTitle))
            Text("\(sections.count + components.count)").font(.studio(.caption)).foregroundStyle(
              studio.t.secondary)
            Spacer()
            Button("Add component") { studio.sheet = .components }.buttonStyle(
              QuietButton(t: studio.t))
            Button {
              creating = true
            } label: {
              StudioLabel("Add section", icon: "plus")
            }
            .buttonStyle(QuietButton(t: studio.t))
          }
          ForEach(components) { component in
            CreativeComponentCard(studio: studio, component: component)
          }
          if sections.isEmpty && components.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Make room for the details").font(.studio(size: 18, weight: .medium))
              Text(
                "Add a history, a motive, a tradition — or a section entirely your own. Your writing stays in Overview."
              )
              .font(.studio(size: 14)).foregroundStyle(studio.t.secondary).lineSpacing(4)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
              .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 16))
          } else {
            LazyVStack(spacing: 12) {
              ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                card(section, index: index)
              }
            }
          }
          if !removed.isEmpty {
            DisclosureGroup(isExpanded: $showRemoved) {
              VStack(spacing: 6) {
                ForEach(removed) { section in
                  HStack {
                    Text(section.record.title).lineLimit(1)
                    Spacer()
                    Button("Restore") { archive(section, value: false) }
                      .buttonStyle(QuietButton(t: studio.t, role: .ghost))
                  }.font(.studio(size: 13)).padding(.vertical, 3)
                }
              }.padding(.top, 8)
            } label: {
              Text("Removed sections · \(removed.count)").font(.studio(size: 13))
                .foregroundStyle(studio.t.secondary)
            }.tint(studio.t.secondary)
          }
        }.padding(.vertical, 28)
      }
    }
    .onAppear {
      load()
      if studio.captureHint == "sheet-section" { creating = true }
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
    .studioSheet(isPresented: $creating) {
      NewRecordSection(studio: studio, parent: parent) { creating = false }
    }
  }

  private func card(_ section: RecordSection, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Button {
          studio.openRecord(section.record)
        } label: {
          Text(section.record.title).font(.studio(size: 17, weight: .semibold))
            .foregroundStyle(studio.t.text).lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).help("Open \(section.record.title)")
        if section.record.state == "canon" { StateBadge(state: "canon", t: studio.t) }
        IconButton(icon: "pencil.line", label: "Edit \(section.record.title)", t: studio.t) {
          studio.openRecord(section.record)
        }
        IconMenu(icon: "ellipsis", label: "Section actions", t: studio.t) {
          Button("Move up") { move(index, by: -1) }.disabled(index == 0)
          Button("Move down") { move(index, by: 1) }.disabled(index == sections.count - 1)
          if studio.mode == .assisted {
            Button("Reference in conversation") {
              studio.reference(section.record)
              studio.companionExpanded = true
            }
          }
          Button("Show on canvas") { studio.showOnCanvas(section.record) }
          Divider()
          Button("Remove from page") { archive(section, value: true) }
        }
      }
      if section.record.body.isEmpty {
        Text("Ready for your notes.").font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
      } else {
        Text(section.record.body).font(.studio(size: 14.5)).lineSpacing(4)
          .foregroundStyle(studio.t.secondary).lineLimit(5).textSelection(.enabled)
      }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.panelRadius))
      .overlay(
        RoundedRectangle(cornerRadius: Metric.panelRadius).stroke(studio.t.hairline, lineWidth: 1))
  }

  private func load() {
    studio.perform {
      components = try studio.store.creativeComponents(worldID: parent.worldID).filter {
        $0.parentID == parent.id
      }
      let archivedComponents = try studio.store.creativeComponents(
        worldID: parent.worldID, archived: true)
      let componentRecords = Set((components + archivedComponents).map { $0.record.id })
      sections = try studio.store.recordSections(worldID: parent.worldID, parentID: parent.id)
        .filter { !componentRecords.contains($0.record.id) }
      removed = try studio.store.recordSections(
        worldID: parent.worldID, parentID: parent.id, archived: true)
    }
  }
  private func move(_ index: Int, by offset: Int) {
    let target = index + offset
    guard sections.indices.contains(target) else { return }
    var ids = sections.map(\.id)
    ids.swapAt(index, target)
    studio.perform {
      try studio.store.reorderRecordSections(
        worldID: parent.worldID, parentID: parent.id, orderedIDs: ids)
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { load() }
    }
  }
  private func archive(_ section: RecordSection, value: Bool) {
    let worldID = parent.worldID
    studio.perform {
      try studio.store.setRecordSectionArchived(worldID: worldID, id: section.id, archived: value)
      try studio.reload()
      if value {
        studio.show(
          "Removed section · its document stays in Library", icon: "archivebox", actionTitle: "Undo"
        ) {
          studio.perform {
            try studio.store.setRecordSectionArchived(
              worldID: worldID, id: section.id, archived: false)
            try studio.reload()
          }
        }
      }
    }
  }
}

struct NewRecordSection: View {
  @ObservedObject var studio: Studio
  let parent: LoreRecord
  var close: () -> Void
  @State private var title = ""
  @State private var notes = ""
  private var suggestions: [String] {
    switch parent.category.lowercased() {
    case "characters":
      return ["History", "Motivations", "Relationships", "Abilities", "Open questions"]
    case "factions", "systems":
      return ["Purpose", "Structure", "Traditions", "Membership", "Rivalries"]
    case "places": return ["Geography", "People", "Landmarks", "History", "Atmosphere"]
    case "power systems":
      return ["Principles", "Costs and limits", "Progression", "Techniques", "Open questions"]
    case "cosmology": return ["Origins", "Realms", "Natural laws", "Beliefs", "Unknowns"]
    default: return ["History", "Details", "Connections", "Open questions"]
    }
  }
  var body: some View {
    SheetScaffold(
      title: "New section", subtitle: "A space inside \(parent.title), shaped by you.",
      t: studio.t, width: 540, close: close
    ) {
      FormField(label: "Title", placeholder: "Name your section", text: $title, t: studio.t)
      PlainMenu {
        ForEach(suggestions, id: \.self) { name in Button(name) { title = name } }
      } label: {
        StudioLabel("Choose a starting name", icon: "chevron.down")
          .font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
      }
      Text("Notes").font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.secondary)
      TextEditor(text: $notes).font(.studio(size: 15)).scrollContentBackground(.hidden)
        .padding(8).frame(height: 160)
        .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.floatingRadius))
        .overlay(
          RoundedRectangle(cornerRadius: Metric.floatingRadius).stroke(
            studio.t.hairline, lineWidth: 1)
        )
        .accessibilityLabel("Section notes")
      Text("Saved as a draft with its own history and canon review.")
        .font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create section") {
        studio.perform {
          try studio.store.createRecordSection(
            worldID: parent.worldID, parentID: parent.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: notes)
          try studio.reload()
          close()
        }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
}
