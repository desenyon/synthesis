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
  @State private var journaling: Task<Void, Never>?
  @State private var recovered: JournalEntry?
  @State private var reloadToken = 0
  @State private var panel: Panel?
  @State private var revisions: [RecordRevision] = []
  @State private var customCategory = false
  @State private var handle = EditorHandle()
  @State private var editingRule: WorldRule?
  @State private var ruleSheet = false
  @State private var mechanicsVisible = false
  private var sectionsVisible: Bool {
    get { studio.recordSectionTabs[record.id] ?? false }
    nonmutating set { studio.recordSectionTabs[record.id] = newValue }
  }
  private var sectionCount: Int { studio.sectionParents.values.filter { $0 == record.id }.count }
  @State private var sectionParent: LoreRecord?
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
        if record.kind == "entity" { entityTabs }
        HStack(spacing: 0) {
          if record.kind == "entity" && mechanicsVisible {
            RulesLab(studio: studio, record: record).frame(
              maxWidth: .infinity, maxHeight: .infinity)
          } else if record.kind == "entity" && sectionsVisible {
            RecordSectionsPage(studio: studio, parent: record)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            writing.frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          if studio.inspector && !mechanicsVisible {
            Rectangle().fill(studio.t.hairline).frame(width: 1)
            RecordInspector(
              studio: studio, record: record, flush: { save() },
              updated: { record = $0 }, review: { if save() { panel = .canon } },
              history: openHistory,
              editRule: { rule in
                editingRule = rule
                ruleSheet = true
              }
            ).frame(width: min(300, geo.size.width * 0.42))
          }
        }
      }
    }
    .onAppear {
      studio.editorSave = { save() }
      if studio.captureHint.contains("mechanics") { mechanicsVisible = true }
      studio.perform {
        sectionParent = try studio.store.sectionParent(worldID: record.worldID, recordID: record.id)
        recovered = try studio.store.journal(worldID: record.worldID, recordID: record.id)
      }
      if studio.reviewCanon == record.id {
        studio.reviewCanon = nil
        panel = .canon
      }
      if studio.captureHint == "sheet-canon" { panel = .canon }
      if studio.captureHint == "sheet-history" { openHistory() }
    }
    .onDisappear {
      saving?.cancel()
      journaling?.cancel()
      if dirty { journal() }
    }
    .onChange(of: studio.worldRevision) { _, _ in
      // A reviewed agent revision may land while this record is open. Refresh clean editors;
      // never replace unsaved typing. The version check still rejects conflicting saves.
      guard !dirty, let latest = studio.records.first(where: { $0.id == record.id }),
        latest != record
      else { return }
      record = latest
      title = latest.title
      bodyText = latest.body
      richText = latest.rtf
      category = latest.category
      reloadToken += 1
    }
    .studioSheet(isPresented: $ruleSheet) {
      RecordRuleEditor(studio: studio, record: record, existing: editingRule) { ruleSheet = false }
    }
    .studioSheet(item: $panel) { item in
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
      RecordBreadcrumb(origin: origin, title: title, status: status, t: studio.t) {
        studio.closeRecord()
      }.layoutPriority(1)
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
        if let maps = try? studio.store.mapsForRecord(worldID: record.worldID, recordID: record.id),
          !maps.isEmpty
        {
          MenuSection("Maps") {
            ForEach(maps) { map in
              Button("Open \(map.name)") {
                if save() {
                  studio.mapBoardID = map.id
                  studio.navigate(.atlas)
                }
              }
            }
          }
        }
        Button("Show on canvas") { if save() { studio.showOnCanvas(record) } }
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

  private var entityTabs: some View {
    ContentHeader {
      FilterChip(title: "Overview", selected: !sectionsVisible && !mechanicsVisible, t: studio.t) {
        if save() {
          sectionsVisible = false
          mechanicsVisible = false
        }
      }
      FilterChip(
        title: "Sections", count: sectionCount, selected: sectionsVisible && !mechanicsVisible,
        t: studio.t
      ) {
        if save() {
          sectionsVisible = true
          mechanicsVisible = false
        }
      }
      FilterChip(title: "Mechanics", selected: mechanicsVisible, t: studio.t) {
        if save() { mechanicsVisible = true }
      }
      Spacer()
    }
    .overlay(alignment: .bottom) { Rectangle().fill(studio.t.hairline).frame(height: 1) }
  }

  // MARK: Writing

  private var writing: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let entry = recovered { recoveryBanner(entry) }
      if let parent = sectionParent {
        Button {
          if save() { studio.openRecord(parent) }
        } label: {
          StudioLabel("Back to \(parent.title)", icon: "arrow.left")
            .font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.accent).lineLimit(
              1)
        }.buttonStyle(.plain).padding(.bottom, 14)
      }
      HStack(spacing: 8) {
        StudioLabel(Vocabulary.kindLabel(record.kind), icon: recordIcon(record))
          .font(.studio(size: 12.5, weight: .medium))
          .foregroundStyle(studio.t.category(category))
        Text("·").foregroundStyle(studio.t.muted)
        categoryMenu
        if record.origin != "user-authored" {
          Text("·").foregroundStyle(studio.t.muted)
          Text(Vocabulary.originLabel(record.origin)).font(.studio(size: 12.5))
            .foregroundStyle(studio.t.muted)
            .help("Origin of this record. It is a draft until you accept it as canon.")
        }
      }.padding(.bottom, 10)
      TextField("Untitled", text: $title, axis: .vertical)
        .font(.studio(size: 30, weight: .semibold)).tracking(-0.4).textFieldStyle(.plain)
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
        styleButton("Body", size: CGFloat(studio.preferences.bodySize), bold: false)
        Spacer()
        if studio.preferences.wordCount {
          Text("\(bodyText.split { $0.isWhitespace || $0.isNewline }.count) words")
            .font(.studio(size: 12)).monospacedDigit().foregroundStyle(studio.t.muted)
        }
      }.padding(.top, 14).padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(studio.t.hairline).frame(height: 1) }
      RichDocumentEditor(
        id: record.id, body: bodyText, rtf: richText, t: studio.t, reloadToken: reloadToken,
        preferences: studio.preferences, handle: handle
      ) { text, rtf in
        bodyText = text
        richText = rtf
        changed()
      }.frame(maxHeight: .infinity)
    }.padding(.horizontal, 36).padding(.top, 18).frame(
      maxWidth: CGFloat(studio.preferences.readingWidth)
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  private func styleButton(_ name: String, size: CGFloat, bold: Bool) -> some View {
    Button {
      handle.heading(size, bold: bold)
    } label: {
      Text(name).font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.secondary)
        .padding(.horizontal, 8).frame(height: 28).hoverFill(studio.t)
    }.buttonStyle(.plain).help("Make the current paragraph \(name.lowercased())")
  }
  @ViewBuilder private var categoryMenu: some View {
    if customCategory {
      TextField("Category", text: $category).textFieldStyle(.plain).font(.studio(size: 12.5))
        .frame(width: 160).onChange(of: category) { _, _ in changed() }
        .onSubmit { customCategory = false }
    } else {
      PlainMenu {
        let known = Vocabulary.categories + ["Ideas"]
        let extra = Set(studio.records.map { Vocabulary.displayCategory($0.category) }).subtracting(
          known
        ).filter { !$0.isEmpty }
        ForEach(known + extra.sorted(), id: \.self) { name in
          Button {
            category = name
            changed()
          } label: {
            if Vocabulary.matchesCategory(category, name) {
              StudioLabel(name, icon: "checkmark")
            } else {
              Text(name)
            }
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
          Text(category.isEmpty ? "No category" : Vocabulary.displayCategory(category)).font(
            .studio(size: 12.5))
          StudioIcon("chevron.down", size: 8)
        }.foregroundStyle(studio.t.secondary).padding(.horizontal, 5).frame(height: 22)
          .hoverFill(studio.t, radius: 5)
      }.padding(.horizontal, -5).help("Change category")
    }
  }

  // MARK: Persistence

  private func changed() {
    dirty = true
    status = "Saving…"
    journaling?.cancel()
    journaling = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(200))
      guard !Task.isCancelled, dirty else { return }
      journal()
    }
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
      journaling?.cancel()
      try? studio.store.clearJournal(worldID: record.worldID, recordID: record.id)
      try studio.reload()
      return true
    } catch {
      journal()
      status = "Not saved · your text is kept here"
      studio.error = error.localizedDescription
      return false
    }
  }
  /// Device-local recovery copy, so a crash or failed save cannot lose typing.
  private func journal() {
    try? studio.store.writeJournal(
      worldID: record.worldID, recordID: record.id, title: title, body: bodyText, rtf: richText,
      category: category, baseVersion: record.version)
  }
  private func restoreRecovered(_ entry: JournalEntry) {
    title = entry.title
    bodyText = entry.body
    richText = entry.rtf
    category = entry.category
    reloadToken += 1
    recovered = nil
    changed()
  }
  private func discardRecovered(_ entry: JournalEntry) {
    recovered = nil
    studio.perform { try studio.store.clearJournal(worldID: record.worldID, recordID: record.id) }
    studio.show("Discarded the recovered text", icon: "archivebox", actionTitle: "Undo") {
      studio.perform {
        try studio.store.writeJournal(
          worldID: entry.worldID, recordID: entry.recordID, title: entry.title, body: entry.body,
          rtf: entry.rtf, category: entry.category, baseVersion: entry.baseVersion)
        recovered = entry
      }
    }
  }
  private func recoveryBanner(_ entry: JournalEntry) -> some View {
    let words = entry.body.split { $0.isWhitespace || $0.isNewline }.count
    return HStack(alignment: .top, spacing: 12) {
      StudioIcon("lifepreserver", size: 15).foregroundStyle(studio.t.warning).padding(.top, 2)
      VStack(alignment: .leading, spacing: 4) {
        Text("Unsaved text was recovered").font(.studio(size: 13.5, weight: .semibold))
        Text(
          "\(words) words from \(relativeDate(entry.updatedAt).lowercased()) never reached a saved revision."
            + (entry.baseVersion == record.version
              ? ""
              : " This page has been saved since; restoring adds a new revision and history keeps both.")
        ).font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
          Button("Restore") { restoreRecovered(entry) }
            .buttonStyle(QuietButton(t: studio.t, primary: true))
          Button("Discard") { discardRecovered(entry) }
            .buttonStyle(QuietButton(t: studio.t, role: .ghost))
        }.padding(.top, 6)
      }
      Spacer(minLength: 0)
    }.padding(12).background(
      studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(
        studio.t.warning.opacity(0.35), lineWidth: 1)
    )
    .padding(.bottom, 14).accessibilityElement(children: .contain)
    .accessibilityLabel("Unsaved text was recovered")
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
    guard save() else { return }
    studio.perform {
      let document = try studio.store.exportRecordMarkdown(
        worldID: record.worldID, recordID: record.id)
      let panel = NSSavePanel()
      panel.nameFieldStringValue = document.filename
      if panel.runModal() == .OK, let url = panel.url {
        try document.content.write(to: url, atomically: true, encoding: .utf8)
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
          StudioLabel("Title: “\(accepted.title)” → “\(title)”", icon: "textformat")
        }
        StudioLabel("\(added) added", icon: "plus").foregroundStyle(studio.t.positive)
        if accepted != nil {
          StudioLabel("\(removed) removed", icon: "minus").foregroundStyle(studio.t.danger)
        }
        Spacer()
      }.font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.secondary)
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
      .font(.studio(size: 12.5)).foregroundStyle(studio.t.muted)
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
        .font(.studio(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(tint ?? .clear).frame(width: 12)
      Text(line.text.isEmpty ? " " : line.text).font(.studio(size: 13.5)).lineSpacing(3)
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
                  Text("Revision \(revision.version)").font(.studio(size: 13.5, weight: .medium))
                  StateBadge(state: revision.snapshot.state, t: studio.t)
                  Text(relativeDate(revision.createdAt)).font(.studio(size: 12))
                    .foregroundStyle(studio.t.muted)
                  if revision.version == record.version {
                    Text("Current").font(.studio(size: 11.5, weight: .medium))
                      .foregroundStyle(studio.t.accent)
                  }
                }
                Text(
                  revision.snapshot.body.isEmpty
                    ? "Empty" : revision.snapshot.body.replacingOccurrences(of: "\n", with: " ")
                ).font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary).lineLimit(2)
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
  @State private var linkPicker = false
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var flush: () -> Bool
  var updated: (LoreRecord) -> Void
  var review: () -> Void
  var history: () -> Void
  var editRule: (WorldRule?) -> Void
  @State private var outgoing: [LoreRecord] = []
  @State private var incoming: [LoreRecord] = []
  @State private var relations: [Relation] = []
  @State private var events: [WorldEvent] = []
  @State private var rules: [WorldRule] = []
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
            Text("Revision \(record.version)").font(.studio(size: 12)).monospacedDigit()
              .foregroundStyle(t.muted)
          }
          Text(statusNote).font(.studio(size: 12.5)).foregroundStyle(t.secondary).lineSpacing(2)
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
        if record.kind == "entity",
          ["Power systems", "Cosmology", "Systems", "Factions"].contains(record.category)
            || !rules.isEmpty
        {
          section("Rules") {
            ForEach(rules) { rule in
              Button {
                editRule(rule)
              } label: {
                VStack(alignment: .leading, spacing: 5) {
                  HStack {
                    Text(rule.kind.title).foregroundStyle(t.secondary)
                    Spacer()
                    StateBadge(state: rule.state, t: t)
                  }.font(.studio(size: 12))
                  Text(rule.title).font(.studio(size: 13, weight: .medium))
                  Text(rule.body).font(.studio(size: 13)).foregroundStyle(t.secondary).lineLimit(3)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8).hoverFill(t)
              }.buttonStyle(.plain).help("Edit rule as draft")
            }
            Button("Add rule") {
              editRule(nil)
            }
            .buttonStyle(QuietButton(t: t, role: .ghost))
          }
        }
        section("Links") {
          if outgoing.isEmpty { hint("Link this to a character, place or another page.") }
          ForEach(outgoing) { linkRow($0, prefix: nil, removable: true) }
          Button {
            linkPicker = true
          } label: {
            StudioLabel("Add link", icon: "plus").font(.studio(size: 12.5, weight: .medium))
              .foregroundStyle(t.accent).padding(.horizontal, 8).frame(height: 26).hoverFill(t)
          }.buttonStyle(.plain).padding(.leading, -8)
            .popover(isPresented: $linkPicker) {
              SearchableRecordPicker(
                records: studio.records.filter { candidate in
                  candidate.id != record.id && !outgoing.contains { $0.id == candidate.id }
                }, t: t
              ) { candidate in
                link(candidate)
                linkPicker = false
              }
            }
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
                  Text(event.title).font(.studio(size: 13, weight: .medium)).lineLimit(1)
                  Text(event.dateLabel == "unknown" ? "Date unknown" : event.dateLabel)
                    .font(.studio(size: 12)).foregroundStyle(t.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                  .padding(.vertical, 5).hoverFill(t)
              }.buttonStyle(.plain).padding(.horizontal, -8)
            }
          }
        }
      }.padding(18)
    }
    .background(studio.t.sidebar.opacity(0.45))
    .onAppear {
      load()
      if studio.captureHint == "sheet-rule" { editRule(nil) }
    }
    .onChange(of: record.version) { _, _ in load() }
    .onChange(of: studio.worldRevision) { _, _ in load() }
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
    Text(text).font(.studio(size: 12.5)).foregroundStyle(studio.t.muted).lineSpacing(2)
      .fixedSize(horizontal: false, vertical: true)
  }
  private func linkRow(_ linked: LoreRecord, prefix: String?, removable: Bool) -> some View {
    HStack(spacing: 8) {
      Button {
        if flush() { studio.openRecord(linked) }
      } label: {
        HStack(spacing: 8) {
          StudioIcon(recordIcon(linked), size: 11.5)
            .foregroundStyle(studio.t.category(linked.category)).frame(width: 16)
          VStack(alignment: .leading, spacing: 1) {
            if let prefix {
              Text(prefix).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(1)
            }
            Text(linked.title).font(.studio(size: 13, weight: .medium)).lineLimit(1)
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
              Text(value).font(.studio(size: 12.5))
              Button {
                commit(values.filter { $0 != value })
              } label: {
                StudioIcon("xmark", size: 8)
                  .foregroundStyle(studio.t.muted)
              }.buttonStyle(.plain).accessibilityLabel("Remove \(value)")
            }.padding(.leading, 9).padding(.trailing, 7).frame(height: 24)
              .background(studio.t.surface, in: Capsule())
              .overlay(Capsule().stroke(studio.t.hairline, lineWidth: 1))
          }
        }
      }
      TextField(placeholder, text: text).textFieldStyle(.plain).font(.studio(size: 12.5))
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
      rules = try studio.store.rules(worldID: studio.worldID, systemID: record.id)
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

/// Manual and proposed rules share the same records and draft boundary.
struct RecordRuleEditor: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  let existing: WorldRule?
  var initialKind: WorldRule.Kind = .limit
  var close: () -> Void
  @State private var title = ""
  @State private var bodyText = ""
  @State private var error: String?
  @State private var kind: WorldRule.Kind = .limit
  @State private var requires: Set<String> = []
  @State private var candidates: [WorldRule] = []
  var body: some View {
    SheetScaffold(
      title: existing == nil ? "Add a rule" : "Edit rule",
      subtitle: "Rules of \(record.title). Saving keeps this a draft.", t: studio.t, width: 520,
      close: close
    ) {
      ChoiceField(
        title: "Kind", selection: $kind, choices: WorldRule.Kind.allCases.map { ($0, $0.title) },
        t: studio.t)
      FormField(
        label: "Title", placeholder: "A constraint, cost or technique", text: $title, t: studio.t)
      FormTextArea(
        label: "Rule", placeholder: "Describe how this rule works and where it applies.",
        text: $bodyText, t: studio.t)
      if WorkspaceStore.treeKinds.contains(kind) && !candidates.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Requires first").font(.studio(size: 12, weight: .medium))
            .foregroundStyle(studio.t.secondary)
          ScrollView {
            VStack(alignment: .leading, spacing: 2) {
              ForEach(candidates) { other in
                Button {
                  if requires.contains(other.id) {
                    requires.remove(other.id)
                  } else {
                    requires.insert(other.id)
                  }
                } label: {
                  HStack(spacing: 9) {
                    StudioIcon(
                      requires.contains(other.id) ? "checkmark.square.fill" : "square", size: 14
                    ).foregroundStyle(
                      requires.contains(other.id) ? studio.t.accent : studio.t.muted)
                    Text(other.title).font(.studio(size: 13.5)).lineLimit(1)
                    Text(other.kind.singular).font(.studio(size: 12))
                      .foregroundStyle(studio.t.muted)
                    Spacer(minLength: 0)
                  }.padding(.horizontal, 8).frame(height: 30).contentShape(Rectangle())
                    .hoverFill(studio.t)
                }.buttonStyle(.plain)
                  .accessibilityLabel("Requires \(other.title)")
                  .accessibilityAddTraits(requires.contains(other.id) ? .isSelected : [])
              }
            }
          }.frame(maxHeight: 150)
        }
      }
      if let error { Text(error).font(.studio(size: 13)).foregroundStyle(studio.t.danger) }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t))
      Button("Save draft") {
        do {
          if let existing {
            let current = try studio.store.rule(worldID: record.worldID, id: existing.id)
            guard current == existing else { throw SynthesisError.stale }
          }
          try studio.store.saveRule(
            worldID: record.worldID, systemID: record.id, existing: existing, kind: kind,
            title: title, body: bodyText, requires: Array(requires))
          try studio.reload()
          close()
        } catch { self.error = error.localizedDescription }
      }.buttonStyle(QuietButton(t: studio.t, primary: true))
        .disabled(
          title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }.onAppear {
      title = existing?.title ?? ""
      bodyText = existing?.body ?? ""
      kind = existing?.kind ?? initialKind
      if let rules = try? studio.store.rules(worldID: record.worldID, systemID: record.id),
        let edges = try? studio.store.prerequisites(worldID: record.worldID, systemID: record.id)
      {
        candidates = rules.filter {
          WorkspaceStore.treeKinds.contains($0.kind) && $0.id != existing?.id
        }
        requires = Set(edges.filter { $0.ruleID == existing?.id }.map(\.requiresID))
      }
    }
  }
}
