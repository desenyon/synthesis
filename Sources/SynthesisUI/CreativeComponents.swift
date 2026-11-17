import SwiftUI
import SynthesisCore

extension Studio {
  var creativeScope: CreativeScope? {
    if destination == .library, selectedRecord?.kind == "entity" { return .entity }
    return CreativeScope(rawValue: destination.rawValue.lowercased())
  }
  var creativeParent: String? { creativeScope == .entity ? selectedRecord?.id : nil }
}

struct CreativeComponentsSheet: View {
  @ObservedObject var studio: Studio
  let scope: CreativeScope
  let parentID: String?
  @State private var components: [CreativeComponent] = []
  @State private var removed: [CreativeComponent] = []
  @State private var creating = false
  @State private var kind: CreativeKind = .notes
  @State private var title = ""
  @State private var content = ""
  @State private var message: String?
  private var subtitle: String {
    parentID.flatMap { id in studio.records.first { $0.id == id }?.title }
      ?? scope.rawValue.capitalized
  }
  var body: some View {
    SheetScaffold(
      title: "Creative components", subtitle: subtitle, t: studio.t, width: 680,
      close: { studio.sheet = nil }
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let message { Text(message).font(.studio(size: 13)).foregroundStyle(studio.t.danger) }
          if creating {
            HStack(spacing: 6) {
              ForEach(CreativeKind.allCases, id: \.self) { value in
                FilterChip(title: value.rawValue.capitalized, selected: kind == value, t: studio.t)
                {
                  kind = value
                }
              }
            }
            FormField(label: "Title", placeholder: "Make this your own", text: $title, t: studio.t)
            Text(instructions).font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
            TextEditor(text: $content).font(.studio(size: 14)).scrollContentBackground(.hidden)
              .padding(10).frame(height: 150).background(
                studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius)
              )
              .accessibilityLabel("Component content")
            HStack {
              Spacer()
              Button("Cancel") { creating = false }.buttonStyle(
                QuietButton(t: studio.t, role: .ghost))
              Button("Create draft") { create() }.buttonStyle(
                QuietButton(t: studio.t, primary: true)
              )
              .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
          } else if components.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("Give your ideas a shape").font(.studio(size: 22, weight: .semibold))
              Text(
                "Build a custom reference, a list of open questions, or a path of progression. Every component is editable lore you can search, link and export."
              )
              .font(.studio(size: 14)).foregroundStyle(studio.t.secondary).lineSpacing(4)
            }.padding(.vertical, 16)
          } else {
            LazyVStack(spacing: 12) {
              ForEach(components) { component in
                CreativeComponentCard(studio: studio, component: component, dismissBeforeOpen: true)
              }
            }
          }
          if !removed.isEmpty {
            DisclosureGroup("Removed · \(removed.count)") {
              ForEach(removed) { component in
                HStack {
                  Text(component.record.title).lineLimit(1)
                  Spacer()
                  Button("Restore") {
                    studio.perform {
                      try studio.store.setCreativeComponentArchived(
                        worldID: studio.worldID, id: component.id, archived: false)
                      try studio.reload()
                    }
                  }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
                }.font(.studio(size: 13))
              }
            }.font(.studio(size: 13)).tint(studio.t.secondary)
          }
        }
      }.frame(height: creating ? 340 : (components.isEmpty ? 180 : 440))
    } footer: {
      Text("Saved as versioned lore").font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      Spacer()
      if !creating {
        Button("Add component") { creating = true }.buttonStyle(
          QuietButton(t: studio.t, primary: true))
      }
    }
    .onAppear {
      load()
      if studio.captureHint == "component-new" {
        creating = true
        kind = .checklist
        title = "Unanswered questions"
        content = "- [ ] Who remembers the first crossing?"
      }
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
  }
  private var instructions: String {
    switch kind {
    case .notes: return "Write freely. You can refine the full document in the editor."
    case .facts: return "One fact per line: Label: value. Unknown details can stay open."
    case .checklist: return "One task per line, beginning with - [ ] or - [x]."
    case .progression: return "One stage per line, in order. Describe its name, cost or threshold."
    }
  }
  private func load() {
    do {
      components = try studio.store.creativeComponents(worldID: studio.worldID).filter {
        $0.scope == scope && $0.parentID == parentID
      }
      removed = try studio.store.creativeComponents(worldID: studio.worldID, archived: true).filter
      { $0.scope == scope && $0.parentID == parentID }
      message = nil
    } catch { message = error.localizedDescription }
  }
  private func create() {
    do {
      try studio.store.createCreativeComponent(
        worldID: studio.worldID, scope: scope, kind: kind, parentID: parentID, title: title,
        body: content)
      try studio.reload()
      title = ""
      content = ""
      creating = false
      message = nil
    } catch { message = error.localizedDescription }
  }
}

struct CreativeComponentCard: View {
  @ObservedObject var studio: Studio
  let component: CreativeComponent
  var dismissBeforeOpen = false
  private var record: LoreRecord { component.record }
  private var lines: [CreativeLine] {
    record.body.components(separatedBy: "\n").enumerated().map {
      CreativeLine($0.element, index: $0.offset)
    }.filter { !$0.text.isEmpty }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(component.kind.rawValue.capitalized).font(.studio(.captionStrong))
            .foregroundStyle(studio.t.secondary)
          Text(record.title).font(.studio(size: 18, weight: .semibold)).lineLimit(2)
        }
        Spacer(minLength: 6)
        IconButton(icon: "arrow.up.forward", label: "Open \(record.title)", t: studio.t) {
          if dismissBeforeOpen { studio.sheet = nil }
          studio.openRecord(record)
        }
        IconMenu(icon: "ellipsis", label: "Component actions", t: studio.t) {
          Button("Show on canvas") {
            if dismissBeforeOpen { studio.sheet = nil }
            studio.showOnCanvas(record)
          }
          if studio.mode == .assisted {
            Button("Reference in conversation") {
              if dismissBeforeOpen { studio.sheet = nil }
              studio.reference(record)
              studio.companionExpanded = true
            }
          }
          Button("Remove component") { archive() }
        }
      }
      if record.body.isEmpty {
        Text("Open this component to begin writing.").font(.studio(size: 14)).foregroundStyle(
          studio.t.secondary)
      } else if component.kind == .notes {
        Text(record.body).font(.studio(size: 14.5)).lineSpacing(4).foregroundStyle(
          studio.t.secondary
        ).lineLimit(8).textSelection(.enabled)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(Array(lines.prefix(40).enumerated()), id: \.element.id) { index, line in
            lineView(line, number: index + 1)
          }
        }
        if lines.count > 40 {
          Text("\(lines.count - 40) more lines in the document").font(.studio(.caption))
            .foregroundStyle(studio.t.secondary)
        }
      }
      HStack {
        StateBadge(state: record.state, t: studio.t)
        Spacer()
        Text("Revision \(record.version)").font(.studio(size: 11.5)).foregroundStyle(
          studio.t.secondary)
      }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(studio.t.hairline, lineWidth: 1))
  }
  @ViewBuilder private func lineView(_ line: CreativeLine, number: Int) -> some View {
    if component.kind == .checklist, let checked = line.checked {
      Button {
        studio.perform {
          try studio.store.toggleCreativeCheck(
            worldID: record.worldID, id: component.id, version: record.version, line: line.id)
          try studio.reload()
        }
      } label: {
        HStack(alignment: .top, spacing: 10) {
          StudioIcon(checked ? "checkmark.circle" : "circle", size: 17).foregroundStyle(
            checked ? studio.t.accent : studio.t.secondary)
          Text(line.text).strikethrough(checked).foregroundStyle(
            checked ? studio.t.secondary : studio.t.text
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        }.contentShape(Rectangle())
      }.buttonStyle(.plain).font(.studio(size: 14)).disabled(record.rtf != nil)
        .accessibilityLabel("\(checked ? "Completed" : "Open"): \(line.text)")
    } else if component.kind == .facts, let colon = line.text.firstIndex(of: ":") {
      HStack(alignment: .top, spacing: 16) {
        Text(String(line.text[..<colon])).foregroundStyle(studio.t.secondary).frame(
          width: 140, alignment: .leading)
        Text(
          String(line.text[line.text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        ).frame(maxWidth: .infinity, alignment: .leading)
      }.font(.studio(size: 14)).textSelection(.enabled)
    } else {
      HStack(alignment: .top, spacing: 12) {
        if component.kind == .progression {
          Text("\(number)").font(.studio(size: 12, weight: .semibold)).foregroundStyle(
            studio.t.accent
          )
          .frame(width: 25, height: 25).background(studio.t.accent.opacity(0.12), in: Circle())
        }
        Text(line.text).font(.studio(size: 14)).lineSpacing(3).frame(
          maxWidth: .infinity, alignment: .leading
        ).textSelection(.enabled)
      }
    }
  }
  private func archive() {
    studio.perform {
      try studio.store.setCreativeComponentArchived(
        worldID: record.worldID, id: component.id, archived: true)
      try studio.reload()
      studio.show("Removed component. Its lore is preserved.", actionTitle: "Undo") {
        studio.perform {
          try studio.store.setCreativeComponentArchived(
            worldID: record.worldID, id: component.id, archived: false)
          try studio.reload()
        }
      }
    }
  }
}
