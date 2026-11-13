import AppKit
import SwiftUI
import SynthesisCore

/// Line-level difference used by canon review so the creator sees exactly what would change.
enum TextDiff {
  enum Kind { case same, added, removed }
  struct Line: Equatable {
    var kind: Kind
    var text: String
  }
  static func lines(old: String, new: String) -> [Line] {
    let a = old.components(separatedBy: "\n")
    let b = new.components(separatedBy: "\n")
    guard a.count * b.count <= 4_000_000 else {
      return a.map { Line(kind: .removed, text: $0) } + b.map { Line(kind: .added, text: $0) }
    }
    var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in stride(from: a.count - 1, through: 0, by: -1) {
      for j in stride(from: b.count - 1, through: 0, by: -1) {
        table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
      }
    }
    var result: [Line] = []
    var i = 0
    var j = 0
    while i < a.count && j < b.count {
      if a[i] == b[j] {
        result.append(Line(kind: .same, text: a[i]))
        i += 1
        j += 1
      } else if table[i + 1][j] >= table[i][j + 1] {
        result.append(Line(kind: .removed, text: a[i]))
        i += 1
      } else {
        result.append(Line(kind: .added, text: b[j]))
        j += 1
      }
    }
    result += a[i...].map { Line(kind: .removed, text: $0) }
    result += b[j...].map { Line(kind: .added, text: $0) }
    return result
  }
}

struct EditorScreen: View {
  enum Panel: String, Identifiable {
    case history, canon
    var id: String { rawValue }
  }
  @ObservedObject var studio: Studio
  @State private var record: LoreRecord
  @State private var title: String
  @State private var bodyText: String
  @State private var richText: String?
  @State private var category: String
  @State private var dirty = false
  @State private var status = "Saved"
  @State private var saving: Task<Void, Never>?
  @State private var reloadToken = 0
  @State private var panel: Panel?
  @State private var revisions: [RecordRevision] = []
  @State private var customCategory = false
  @State private var handle = EditorHandle()
  init(studio: Studio, record: LoreRecord) {
    self.studio = studio
    _record = State(initialValue: record)
    _title = State(initialValue: record.title)
    _bodyText = State(initialValue: record.body)
    _richText = State(initialValue: record.rtf)
    _category = State(initialValue: record.category)
  }
  var body: some View {
    GeometryReader { geo in
      VStack(spacing: 0) {
        bar
        HStack(spacing: 0) {
          writing.frame(maxWidth: .infinity, maxHeight: .infinity)
          if studio.inspector && geo.size.width >= 780 {
            Rectangle().fill(studio.t.hairline).frame(width: 1)
            RecordInspector(
              studio: studio, record: record, flush: { save() },
              updated: { record = $0 }, review: { if save() { panel = .canon } },
              history: openHistory
            ).frame(width: 300)
          }
        }
      }
    }
    .onAppear {
      studio.editorSave = { save() }
      if studio.reviewCanon == record.id {
        studio.reviewCanon = nil
        panel = .canon
      }
      if studio.captureHint == "sheet-canon" { panel = .canon }
      if studio.captureHint == "sheet-history" { openHistory() }
    }
    .onDisappear { saving?.cancel() }
    .sheet(item: $panel) { item in
      switch item {
      case .history: historySheet
      case .canon: canonSheet
      }
    }
  }

  // MARK: Bar

  private var origin: String { studio.libraryCategory ?? studio.destination.rawValue }
  private var bar: some View {
    WorkspaceBar(studio: studio) {
      Button {
        studio.closeRecord()
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
          Text(origin).font(.system(size: 13.5, weight: .medium))
        }.foregroundStyle(studio.t.secondary).padding(.horizontal, 7).frame(height: 28)
          .hoverFill(studio.t)
      }.buttonStyle(.plain).padding(.leading, -6).help("Back to \(origin)")
        .keyboardShortcut("[", modifiers: .command)
      Text("/").foregroundStyle(studio.t.muted.opacity(0.6))
      Text(title.isEmpty ? "Untitled" : title).font(.system(size: 13.5, weight: .medium))
        .lineLimit(1).layoutPriority(-1)
      Text(status).font(.system(size: 12)).lineLimit(1)
        .foregroundStyle(status.contains("Not saved") ? studio.t.danger : studio.t.muted)
        .padding(.leading, 4)
    } trailing: {
      if record.state == "canon" {
        StateBadge(state: "canon", t: studio.t).padding(.horizontal, 6)
          .help("This revision is accepted canon. Editing starts a new draft.")
      } else {
        BarAction(
          title: "Review for canon", icon: "checkmark.seal", t: studio.t,
          help: record.kind == "capture"
            ? "Turn this idea into a document before canon review"
            : "Compare this draft with accepted canon and decide"
        ) { if save() { panel = .canon } }.disabled(record.kind == "capture")
      }
      IconMenu(icon: "ellipsis", label: "More actions", t: studio.t) {
        Button("Revision history") { openHistory() }
        if record.kind == "capture" {
          Button("Turn into a document") {
            if save() {
              studio.perform {
                record = try studio.store.convertCapture(worldID: studio.worldID, id: record.id)
                try studio.reload()
              }
            }
          }
        }
        if studio.mode == .assisted {
          Button("Reference in conversation") {
            if save() {
              studio.reference(record)
              studio.navigate(.chat)
            }
          }
        }
        Button("Export as Markdown…") { export() }
        Divider()
        Button("Archive") { if save() { studio.archive(record) } }
      }
      IconButton(
        icon: "sidebar.right", label: studio.inspector ? "Hide details" : "Show details",
        t: studio.t, active: studio.inspector
      ) { withAnimation(.easeOut(duration: 0.16)) { studio.toggleInspector() } }
    }
  }

  // MARK: Writing

  private var writing: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Label(Vocabulary.kindLabel(record.kind), systemImage: recordIcon(record))
          .font(.system(size: 12.5, weight: .medium))
          .foregroundStyle(studio.t.category(category))
        Text("·").foregroundStyle(studio.t.muted)
        categoryMenu
        if record.origin != "user-authored" {
          Text("·").foregroundStyle(studio.t.muted)
          Text(Vocabulary.originLabel(record.origin)).font(.system(size: 12.5))
            .foregroundStyle(studio.t.muted)
            .help("Origin of this record. It is a draft until you accept it as canon.")
        }
      }.padding(.bottom, 10)
      TextField("Untitled", text: $title, axis: .vertical)
        .font(.system(size: 30, weight: .semibold)).tracking(-0.4).textFieldStyle(.plain)
        .onChange(of: title) { _, _ in changed() }.accessibilityLabel("Title")
      HStack(spacing: 2) {
        IconButton(icon: "bold", label: "Bold · ⌘B", t: studio.t) { handle.send("toggleBoldface:") }
        IconButton(icon: "italic", label: "Italic · ⌘I", t: studio.t) {
          handle.send("toggleItalics:")
        }
        IconButton(icon: "underline", label: "Underline · ⌘U", t: studio.t) {
          handle.send("underline:")
        }
        Rectangle().fill(studio.t.hairline).frame(width: 1, height: 16).padding(.horizontal, 5)
        styleButton("Heading", size: 22, bold: true)
        styleButton("Subheading", size: 18, bold: true)
        styleButton("Body", size: 16, bold: false)
        Spacer()
        Text("\(bodyText.split { $0.isWhitespace || $0.isNewline }.count) words")
          .font(.system(size: 12)).monospacedDigit().foregroundStyle(studio.t.muted)
      }.padding(.top, 14).padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(studio.t.hairline).frame(height: 1) }
      RichDocumentEditor(
        id: record.id, body: bodyText, rtf: richText, t: studio.t, reloadToken: reloadToken,
        handle: handle
      ) { text, rtf in
        bodyText = text
        richText = rtf
        changed()
      }.frame(maxHeight: .infinity)
    }.padding(.horizontal, 36).padding(.top, 18).frame(maxWidth: 780)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  private func styleButton(_ name: String, size: CGFloat, bold: Bool) -> some View {
    Button {
      handle.heading(size, bold: bold)
    } label: {
      Text(name).font(.system(size: 12.5, weight: .medium)).foregroundStyle(studio.t.secondary)
        .padding(.horizontal, 8).frame(height: 28).hoverFill(studio.t)
    }.buttonStyle(.plain).help("Make the current paragraph \(name.lowercased())")
  }
  @ViewBuilder private var categoryMenu: some View {
    if customCategory {
      TextField("Category", text: $category).textFieldStyle(.plain).font(.system(size: 12.5))
        .frame(width: 160).onChange(of: category) { _, _ in changed() }
        .onSubmit { customCategory = false }
    } else {
      PlainMenu {
        let known = Vocabulary.categories + ["Ideas"]
        let extra = Set(studio.records.map(\.category)).subtracting(known).filter { !$0.isEmpty }
        ForEach(known + extra.sorted(), id: \.self) { name in
          Button {
            category = name
            changed()
          } label: {
            if category == name { Label(name, systemImage: "checkmark") } else { Text(name) }
          }
        }
        Divider()
        Button("No category") {
          category = ""
          changed()
        }
        Button("Custom…") { customCategory = true }
      } label: {
        HStack(spacing: 4) {
          Text(category.isEmpty ? "No category" : category).font(.system(size: 12.5))
          Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
        }.foregroundStyle(studio.t.secondary).padding(.horizontal, 5).frame(height: 22)
          .hoverFill(studio.t, radius: 5)
      }.padding(.horizontal, -5).help("Change category")
    }
  }

  // MARK: Persistence

  private func changed() {
    dirty = true
    status = "Saving…"
    saving?.cancel()
    saving = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(650))
      guard !Task.isCancelled else { return }
      _ = save()
    }
  }
  @discardableResult private func save() -> Bool {
    saving?.cancel()
    guard dirty else { return true }
    do {
      record = try studio.store.saveRecord(
        worldID: record.worldID, id: record.id, version: record.version, title: title,
        body: bodyText, rtf: richText, category: category)
      dirty = false
      status = "Saved"
      try studio.reload()
      return true
    } catch {
      status = "Not saved · your text is kept here"
      studio.error = error.localizedDescription
      return false
    }
  }
  private func openHistory() {
    guard save() else { return }
    studio.perform {
      revisions = try studio.store.history(worldID: studio.worldID, id: record.id)
      panel = .history
    }
  }
  private func restore(_ revision: RecordRevision) {
    studio.perform {
      record = try studio.store.restoreRevision(
        worldID: record.worldID, id: record.id, version: record.version, revisionID: revision.id)
      bodyText = record.body
      richText = record.rtf
      title = record.title
      category = record.category
      dirty = false
      status = "Saved"
      reloadToken += 1
      panel = nil
      try studio.reload()
      studio.show(
        "Restored revision \(revision.version) as a new draft", icon: "clock.arrow.circlepath")
    }
  }
  private func export() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(title).md"
    if panel.runModal() == .OK, let url = panel.url {
      studio.perform {
        try "# \(title)\n\n\(bodyText)".write(to: url, atomically: true, encoding: .utf8)
        studio.show("Exported \(url.lastPathComponent)", icon: "square.and.arrow.up")
      }
    }
  }

  // MARK: Sheets

  private var canon: (title: String, body: String)? {
    guard let data = record.canonical?.data(using: .utf8),
      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return nil }
    return (object["title"] as? String ?? "", object["body"] as? String ?? "")
  }
  private func closePanel() { panel = nil }
  private var canonSheet: some View {
    let accepted = canon
    let diff = TextDiff.lines(old: accepted?.body ?? "", new: bodyText)
    let added = diff.filter { $0.kind == .added && !$0.text.isEmpty }.count
    let removed = diff.filter { $0.kind == .removed && !$0.text.isEmpty }.count
    return SheetScaffold(
      title: "Review for canon",
      subtitle: accepted == nil
        ? "Nothing is canon for “\(title)” yet. Accepting establishes revision \(record.version) exactly as shown."
        : "Accepting replaces the canon version of “\(title)” with revision \(record.version).",
      t: studio.t, width: 640, close: closePanel
    ) {
      HStack(spacing: 12) {
        if let accepted, accepted.title != title {
          Label("Title: “\(accepted.title)” → “\(title)”", systemImage: "textformat")
        }
        Label("\(added) added", systemImage: "plus").foregroundStyle(studio.t.positive)
        if accepted != nil {
          Label("\(removed) removed", systemImage: "minus").foregroundStyle(studio.t.danger)
        }
        Spacer()
      }.font(.system(size: 12.5, weight: .medium)).foregroundStyle(studio.t.secondary)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(diff.enumerated()), id: \.offset) { _, line in
            if accepted == nil {
              diffRow(TextDiff.Line(kind: .same, text: line.text))
            } else {
              diffRow(line)
            }
          }
        }.padding(.vertical, 6)
      }.frame(height: min(320, max(84, CGFloat(diff.count) * 27 + 14)))
        .background(studio.t.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(studio.t.hairline, lineWidth: 1))
      Text(
        "Only you can accept canon. Earlier versions, including the current canon, stay in history."
      )
      .font(.system(size: 12.5)).foregroundStyle(studio.t.muted)
      .fixedSize(horizontal: false, vertical: true)
    } footer: {
      Spacer()
      Button("Keep as draft") { panel = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Accept as canon") {
        studio.perform {
          record = try studio.store.promote(
            worldID: studio.worldID, id: record.id, version: record.version,
            confirmation: record.id)
          try studio.reload()
          panel = nil
          studio.show("“\(record.title)” is now canon", icon: "checkmark.seal")
        }
      }.buttonStyle(QuietButton(t: studio.t, primary: true))
    }
  }
  private func diffRow(_ line: TextDiff.Line) -> some View {
    let tint: Color? =
      line.kind == .added ? studio.t.positive : (line.kind == .removed ? studio.t.danger : nil)
    return HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(line.kind == .added ? "+" : (line.kind == .removed ? "−" : " "))
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(tint ?? .clear).frame(width: 12)
      Text(line.text.isEmpty ? " " : line.text).font(.system(size: 13.5)).lineSpacing(3)
        .foregroundStyle(line.kind == .same ? studio.t.secondary : studio.t.text)
        .strikethrough(line.kind == .removed, color: studio.t.danger.opacity(0.6))
        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
    }.padding(.horizontal, 12).padding(.vertical, 3)
      .background((tint ?? .clear).opacity(tint == nil ? 0 : 0.12))
  }
  private var historySheet: some View {
    SheetScaffold(
      title: "Revision history",
      subtitle: "Restoring creates a new draft. Accepted canon is never overwritten.",
      t: studio.t, width: 560, close: closePanel
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 1) {
          ForEach(revisions) { revision in
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                  Text("Revision \(revision.version)").font(.system(size: 13.5, weight: .medium))
                  StateBadge(state: revision.snapshot.state, t: studio.t)
                  Text(relativeDate(revision.createdAt)).font(.system(size: 12))
                    .foregroundStyle(studio.t.muted)
                  if revision.version == record.version {
                    Text("Current").font(.system(size: 11.5, weight: .medium))
                      .foregroundStyle(studio.t.accent)
                  }
                }
                Text(
                  revision.snapshot.body.isEmpty
                    ? "Empty" : revision.snapshot.body.replacingOccurrences(of: "\n", with: " ")
                ).font(.system(size: 12.5)).foregroundStyle(studio.t.secondary).lineLimit(2)
              }
              Spacer(minLength: 8)
              if revision.version != record.version {
                Button("Restore") { restore(revision) }.buttonStyle(QuietButton(t: studio.t))
              }
            }.padding(10).hoverFill(studio.t, radius: 9)
          }
        }
      }.frame(height: min(360, max(120, CGFloat(revisions.count) * 70)))
    } footer: {
      Spacer()
      Button("Done") { panel = nil }.buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
  }
}

/// Everything connected to the open record: status, metadata, links, relationships and events.
struct RecordInspector: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var flush: () -> Bool
  var updated: (LoreRecord) -> Void
  var review: () -> Void
  var history: () -> Void
  @State private var outgoing: [LoreRecord] = []
  @State private var incoming: [LoreRecord] = []
  @State private var relations: [Relation] = []
  @State private var events: [WorldEvent] = []
  @State private var newTag = ""
  @State private var newAlias = ""
  var body: some View {
    let t = studio.t
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        section("Status") {
          HStack(spacing: 8) {
            StateBadge(state: record.state, t: t)
            Spacer()
            Text("Revision \(record.version)").font(.system(size: 12)).monospacedDigit()
              .foregroundStyle(t.muted)
          }
          Text(statusNote).font(.system(size: 12.5)).foregroundStyle(t.secondary).lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
          HStack(spacing: 6) {
            if record.state != "canon" && record.kind != "capture" {
              Button("Review for canon", action: review).buttonStyle(QuietButton(t: t))
            }
            Button("History", action: history).buttonStyle(QuietButton(t: t, role: .ghost))
          }
        }
        section("Tags") {
          tokens(record.tags ?? [], placeholder: "Add a tag", text: $newTag) { values in
            saveMetadata(tags: values, aliases: record.aliases ?? [])
          }
        }
        section("Also known as") {
          tokens(record.aliases ?? [], placeholder: "Add an alias", text: $newAlias) { values in
            saveMetadata(tags: record.tags ?? [], aliases: values)
          }
        }
        if record.kind == "entity" {
          section("Relationships") {
            if relations.isEmpty {
              hint("No relationships yet. Connect entities in Graph or on a canvas.")
            }
            ForEach(relations) { relation in
              let outward = relation.sourceID == record.id
              let other = studio.records.first {
                $0.id == (outward ? relation.targetID : relation.sourceID)
              }
              if let other {
                linkRow(
                  other, prefix: outward ? relation.label : "← \(relation.label)", removable: false)
              }
            }
            Button("Open in Graph") { studio.navigate(.knowledge) }
              .buttonStyle(QuietButton(t: t, role: .ghost)).padding(.leading, -12)
          }
        }
        section("Links") {
          if outgoing.isEmpty { hint("Link this to a character, place or another page.") }
          ForEach(outgoing) { linkRow($0, prefix: nil, removable: true) }
          PlainMenu {
            let candidates = studio.records.filter { candidate in
              candidate.id != record.id && !outgoing.contains { $0.id == candidate.id }
            }
            ForEach(candidates.prefix(60)) { candidate in
              Button(candidate.title) { link(candidate) }
            }
            if candidates.isEmpty { Text("Nothing else to link yet") }
          } label: {
            Label("Add link", systemImage: "plus").font(.system(size: 12.5, weight: .medium))
              .foregroundStyle(t.accent).padding(.horizontal, 8).frame(height: 26).hoverFill(t)
          }.padding(.leading, -8)
        }
        if !incoming.isEmpty {
          section("Referenced by") {
            ForEach(incoming) { linkRow($0, prefix: nil, removable: false) }
          }
        }
        if !events.isEmpty {
          section("On the timeline") {
            ForEach(events) { event in
              Button {
                studio.navigate(.timeline)
              } label: {
                VStack(alignment: .leading, spacing: 2) {
                  Text(event.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                  Text(event.dateLabel == "unknown" ? "Date unknown" : event.dateLabel)
                    .font(.system(size: 12)).foregroundStyle(t.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                  .padding(.vertical, 5).hoverFill(t)
              }.buttonStyle(.plain).padding(.horizontal, -8)
            }
          }
        }
      }.padding(18)
    }
    .background(studio.t.sidebar.opacity(0.45))
    .onAppear(perform: load)
    .onChange(of: record.version) { _, _ in load() }
    .accessibilityElement(children: .contain).accessibilityLabel("Record details")
  }
  private var statusNote: String {
    let origin = record.origin == "ai-proposed" ? "An AI-proposed draft. " : ""
    switch record.state {
    case "canon": return "Accepted canon. Editing starts a new draft and keeps this version."
    case "idea": return origin + "A loose idea. Turn it into a document to review it for canon."
    default:
      return origin
        + (record.canonical != nil
          ? "A draft. The accepted canon version is preserved until you replace it."
          : "A draft. Nothing here is established until you accept it.")
    }
  }
  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      SectionLabel(title: title, t: studio.t)
      content()
    }
  }
  private func hint(_ text: String) -> some View {
    Text(text).font(.system(size: 12.5)).foregroundStyle(studio.t.muted).lineSpacing(2)
      .fixedSize(horizontal: false, vertical: true)
  }
  private func linkRow(_ linked: LoreRecord, prefix: String?, removable: Bool) -> some View {
    HStack(spacing: 8) {
      Button {
        if flush() { studio.openRecord(linked) }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: recordIcon(linked)).font(.system(size: 11.5))
            .foregroundStyle(studio.t.category(linked.category)).frame(width: 16)
          VStack(alignment: .leading, spacing: 1) {
            if let prefix {
              Text(prefix).font(.system(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(1)
            }
            Text(linked.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
          }
          Spacer(minLength: 0)
        }.padding(.horizontal, 8).padding(.vertical, 5).hoverFill(studio.t)
      }.buttonStyle(.plain).help("Open \(linked.title)")
      if removable {
        IconButton(icon: "xmark", label: "Remove link to \(linked.title)", t: studio.t, size: 22) {
          studio.perform {
            try studio.store.unlinkRecord(
              worldID: studio.worldID, source: record.id, target: linked.id)
            load()
          }
        }
      }
    }.padding(.leading, -8)
  }
  private func tokens(
    _ values: [String], placeholder: String, text: Binding<String>,
    commit: @escaping ([String]) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      if !values.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(values, id: \.self) { value in
            HStack(spacing: 4) {
              Text(value).font(.system(size: 12.5))
              Button {
                commit(values.filter { $0 != value })
              } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                  .foregroundStyle(studio.t.muted)
              }.buttonStyle(.plain).accessibilityLabel("Remove \(value)")
            }.padding(.leading, 9).padding(.trailing, 7).frame(height: 24)
              .background(studio.t.surface, in: Capsule())
              .overlay(Capsule().stroke(studio.t.hairline, lineWidth: 1))
          }
        }
      }
      TextField(placeholder, text: text).textFieldStyle(.plain).font(.system(size: 12.5))
        .onSubmit {
          let value = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !value.isEmpty else { return }
          text.wrappedValue = ""
          if !values.contains(value) { commit((values + [value]).sorted()) }
        }
        .padding(.horizontal, 8).frame(height: 28)
        .background(studio.t.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(studio.t.hairline, lineWidth: 1))
    }
  }
  private func saveMetadata(tags: [String], aliases: [String]) {
    guard flush() else { return }
    studio.perform {
      let current = try studio.store.record(worldID: studio.worldID, id: record.id)
      let saved = try studio.store.saveMetadata(
        worldID: studio.worldID, id: record.id, version: current.version, tags: tags,
        aliases: aliases)
      try studio.reload()
      updated(saved)
    }
  }
  private func link(_ target: LoreRecord) {
    studio.perform {
      try studio.store.linkRecord(worldID: studio.worldID, source: record.id, target: target.id)
      load()
    }
  }
  private func load() {
    studio.perform {
      outgoing = try studio.store.linkedRecords(worldID: studio.worldID, id: record.id)
      incoming = try studio.store.linkedRecords(
        worldID: studio.worldID, id: record.id, incoming: true)
      relations = try studio.store.relations(worldID: studio.worldID).filter {
        $0.sourceID == record.id || $0.targetID == record.id
      }
      events = try studio.store.events(worldID: studio.worldID).filter {
        $0.sourceID == record.id
      }
    }
  }
}

/// Wrapping row layout for tag chips.
struct FlowLayout: Layout {
  var spacing: CGFloat = 6
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(width: proposal.width ?? .infinity, subviews: subviews).size
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let layout = arrange(width: bounds.width, subviews: subviews)
    for (index, point) in layout.points.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
    }
  }
  private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
    var points: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var widest: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      points.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      widest = max(widest, x - spacing)
    }
    return (CGSize(width: widest, height: y + rowHeight), points)
  }
}
