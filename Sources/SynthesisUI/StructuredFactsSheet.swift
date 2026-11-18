import SwiftUI
import SynthesisCore

struct StructuredFactsSheet: View {
  private enum Page {
    case list
    case form(StructuredFact?)
    case review(StructuredFact)
    case history(StructuredFact, [StructuredFactRevision])
    case evidence(LoreRecord)
  }

  private enum ValueKind: String, CaseIterable {
    case text = "Text"
    case entity = "Linked entity"
  }

  private enum Picker: String, Identifiable {
    case entity, evidence
    var id: String { rawValue }
  }

  @ObservedObject var studio: Studio
  let subject: LoreRecord
  let placement: EditorPlacement
  let close: () -> Void
  @State private var page: Page = .list
  @State private var facts: [StructuredFact] = []
  @State private var failure: String?
  @State private var loadFailed = false
  @State private var predicate = ""
  @State private var kind: ValueKind = .text
  @State private var text = ""
  @State private var valueID: String?
  @State private var evidence: StructuredFactEvidence?
  @State private var disputed = false
  @State private var picker: Picker?

  private var inScope: Bool {
    let open = placement == .main ? studio.selectedRecord : studio.splitRecord
    return studio.worldID == subject.worldID && open?.id == subject.id
  }

  private var heading: String {
    switch page {
    case .list: "Structured facts"
    case .form(let fact): fact == nil ? "Add fact" : "Edit fact"
    case .review: "Review fact for canon"
    case .history: "Fact history"
    case .evidence: "Saved source revision"
    }
  }

  private var validForm: Bool {
    guard !predicate.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
    return kind == .entity ? valueID != nil : !text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private var isChoosingRecord: Binding<Bool> {
    Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })
  }

  var body: some View {
    SheetScaffold(title: heading, t: studio.t, width: 500, close: close) {
      Text(subject.title).font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
        .lineLimit(1).help(subject.title)
      if !inScope {
        Text("The editor has changed. Open structured facts from this entity again.")
          .font(.studio(.control)).foregroundStyle(studio.t.warning)
      } else {
        content
      }
      if let failure {
        Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger)
      }
    } footer: {
      Spacer()
      footer
    }
    .onAppear {
      load()
      showCapturePage()
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
  }

  @ViewBuilder private var content: some View {
    switch page {
    case .list:
      if loadFailed {
        Button("Retry", action: load).buttonStyle(QuietButton(t: studio.t))
      } else if facts.isEmpty {
        EmptyState(
          icon: "list.bullet", title: "No structured facts yet",
          message: "Record a value and attach the saved source that supports it.", t: studio.t
        ) { EmptyView() }
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: Space.xs) {
            ForEach(facts, content: row)
          }
        }.frame(height: min(300, CGFloat(facts.count) * 100))
      }
    case .form(let fact):
      fields(editing: fact)
    case .review(let fact):
      ScrollView {
        VStack(alignment: .leading, spacing: Space.md) {
          Text(fact.predicate).font(.studio(.label))
          if let accepted = fact.accepted {
            revisionDetail(accepted, label: "Current canon")
          }
          revisionDetail(fact.working, label: "Proposed canon")
        }
      }.frame(maxHeight: 260)
    case .history(let fact, let revisions):
      ScrollView {
        LazyVStack(alignment: .leading, spacing: Space.md) {
          Text(fact.predicate).font(.studio(.label))
          ForEach(revisions.reversed()) { revision in
            VStack(alignment: .leading, spacing: Space.xs) {
              revisionDetail(
                revision, label: "Revision \(revision.revision) · \(revision.status.title)")
              if let evidence = revision.evidence {
                Button("Inspect saved source") { inspect(evidence) }
                  .buttonStyle(QuietButton(t: studio.t))
              }
            }
          }
        }
      }.frame(maxHeight: 290)
    case .evidence(let source):
      VStack(alignment: .leading, spacing: Space.xs) {
        Text(source.title).font(.studio(.label)).lineLimit(2)
        Text("Document revision \(source.version)").font(.studio(.caption))
          .foregroundStyle(studio.t.secondary)
        ScrollView {
          Text(source.body.isEmpty ? "This revision has no body text." : source.body)
            .font(.studio(.control)).frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }.frame(maxHeight: 280)
      }
    }
  }

  @ViewBuilder private var footer: some View {
    if case .list = page {
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Add fact") { edit(nil) }.buttonStyle(QuietButton(t: studio.t, primary: true))
        .disabled(!inScope || loadFailed)
    } else {
      Button("Back") { showList() }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      switch page {
      case .form(let fact):
        Button("Save draft") { save(fact) }
          .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
          .disabled(!inScope || !validForm)
      case .review(let fact):
        Button("Approve as canon") { approve(fact) }
          .buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(!inScope)
      default:
        EmptyView()
      }
    }
  }

  private func row(_ fact: StructuredFact) -> some View {
    HStack(alignment: .top, spacing: Space.sm) {
      VStack(alignment: .leading, spacing: Space.xs) {
        Text(fact.predicate).font(.studio(.captionStrong)).lineLimit(1).help(fact.predicate)
        Text("\(fact.working.status.title) · \(valueTitle(fact.working.value))")
          .font(.studio(.control)).lineLimit(2).help(valueTitle(fact.working.value))
        if let accepted = fact.accepted, accepted.id != fact.working.id {
          Text("Canon · \(valueTitle(accepted.value))").font(.studio(.caption))
            .foregroundStyle(studio.t.secondary).lineLimit(2)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
      IconMenu(icon: "ellipsis", label: "Actions for \(fact.predicate)", t: studio.t) {
        Button("Edit…") { edit(fact) }
        if fact.working.status == .draft {
          Button("Review for canon…") {
            page = .review(fact)
            failure = nil
          }
        }
        if let evidence = fact.working.evidence {
          Button("Inspect saved source") { inspect(evidence) }
        }
        if case .entity(let id) = fact.working.value,
          let entity = studio.records.first(where: { $0.id == id && $0.worldID == subject.worldID })
        {
          Button("Open linked entity") {
            guard inScope, studio.flushEditor() else { return }
            close()
            studio.openRecord(entity)
          }
        }
        Button("History…") { showHistory(fact) }
        Divider()
        Button("Archive") { archive(fact) }
      }
    }.padding(Space.sm).hoverFill(studio.t)
  }

  private func fields(editing fact: StructuredFact?) -> some View {
    VStack(alignment: .leading, spacing: Space.sm) {
      if let fact {
        Text(fact.predicate).font(.studio(.captionStrong))
      } else {
        FormField(
          label: "Property", placeholder: "For example, title", text: $predicate, t: studio.t)
      }
      ChoiceField(
        title: "Value type", selection: $kind,
        choices: ValueKind.allCases.map { ($0, $0.rawValue) }, t: studio.t)
      if kind == .text {
        FormField(label: "Value", placeholder: "Enter a value", text: $text, t: studio.t)
      } else {
        Button(valueID.map { valueTitle(.entity($0)) } ?? "Choose entity…") { picker = .entity }
          .buttonStyle(QuietButton(t: studio.t))
      }
      HStack(spacing: Space.sm) {
        Button(evidence == nil ? "Add document evidence…" : "Change document evidence…") {
          picker = .evidence
        }.buttonStyle(QuietButton(t: studio.t))
        if let evidence {
          Text("Revision \(evidence.version)").font(.studio(.caption))
            .foregroundStyle(studio.t.secondary)
          IconButton(icon: "xmark", label: "Remove evidence", t: studio.t, size: 24) {
            self.evidence = nil
          }
        }
      }
      .popover(isPresented: isChoosingRecord) {
        if let picker {
          SearchableRecordPicker(
            records: studio.records.filter {
              $0.worldID == subject.worldID
                && (picker == .entity ? $0.kind == "entity" : $0.kind != "capture")
            }, t: studio.t
          ) { record in
            self.picker = nil
            guard inScope else { return }
            do {
              if picker == .entity { valueID = record.id }
              if picker == .evidence {
                evidence = try studio.store.structuredFactEvidence(
                  worldID: subject.worldID, recordID: record.id)
              }
              failure = nil
            } catch { failure = error.localizedDescription }
          }
        }
      }
      Toggle("Mark as disputed", isOn: $disputed)
        .help("Keep this claim out of canon review while the dispute is unresolved.")
    }
  }

  private func revisionDetail(_ revision: StructuredFactRevision, label: String) -> some View {
    VStack(alignment: .leading, spacing: Space.xs) {
      Text(label).font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
      Text(valueTitle(revision.value)).font(.studio(.control))
      Text("\(revision.author) · \(revision.recordedAt)").font(.studio(.caption))
        .foregroundStyle(studio.t.secondary)
      if let evidence = revision.evidence {
        let title =
          (try? studio.store.structuredFactSource(worldID: subject.worldID, evidence: evidence)
            .title)
          ?? "Saved source"
        Text("\(title) · Revision \(evidence.version)").font(.studio(.caption))
          .foregroundStyle(studio.t.secondary)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private func valueTitle(_ value: StructuredFactValue) -> String {
    switch value {
    case .text(let text): text
    case .entity(let id):
      studio.records.first(where: { $0.id == id && $0.worldID == subject.worldID })?.title
        ?? (try? studio.store.record(worldID: subject.worldID, id: id).title)
        ?? "Linked entity unavailable"
    }
  }

  private func load() {
    guard inScope else {
      facts = []
      return
    }
    do {
      facts = try studio.store.structuredFacts(worldID: subject.worldID, subjectID: subject.id)
      if loadFailed { failure = nil }
      loadFailed = false
    } catch {
      loadFailed = true
      failure = error.localizedDescription
    }
  }

  private func showList() {
    page = .list
    failure = nil
    load()
  }

  private func edit(_ fact: StructuredFact?) {
    predicate = fact?.predicate ?? ""
    evidence = fact?.working.evidence
    disputed = fact?.working.status == .disputed
    switch fact?.working.value {
    case .entity(let id): (kind, text, valueID) = (.entity, "", id)
    case .text(let value): (kind, text, valueID) = (.text, value, nil)
    case nil: (kind, text, valueID) = (.text, "", nil)
    }
    page = .form(fact)
    failure = nil
  }

  private func save(_ fact: StructuredFact?) {
    guard inScope, validForm, studio.flushEditor() else { return }
    let value =
      kind == .entity ? valueID.map(StructuredFactValue.entity) : StructuredFactValue.text(text)
    guard let value else { return }
    let draft = StructuredFactDraft(value: value, evidence: evidence, disputed: disputed)
    do {
      if let fact {
        try studio.store.reviseStructuredFact(
          worldID: subject.worldID, expected: fact, draft: draft)
      } else {
        try studio.store.createStructuredFact(
          worldID: subject.worldID, subjectID: subject.id, predicate: predicate, draft: draft)
      }
      showList()
    } catch { failure = error.localizedDescription }
  }

  private func approve(_ fact: StructuredFact) {
    guard inScope, studio.flushEditor() else { return }
    do {
      try studio.store.approveStructuredFact(
        worldID: subject.worldID, expected: fact, confirmation: fact.working.id)
      showList()
    } catch { failure = error.localizedDescription }
  }

  private func archive(_ fact: StructuredFact) {
    guard inScope, studio.flushEditor() else { return }
    do {
      let archived = try studio.store.setStructuredFactArchived(
        worldID: subject.worldID, expected: fact, archived: true)
      close()
      studio.show("Fact archived", icon: "archivebox", actionTitle: "Undo") { [weak studio] in
        guard let studio else { return }
        studio.perform {
          try studio.store.setStructuredFactArchived(
            worldID: archived.worldID, expected: archived, archived: false)
          if studio.worldID == archived.worldID { try studio.reload() }
        }
      }
    } catch { failure = error.localizedDescription }
  }

  private func showHistory(_ fact: StructuredFact) {
    do {
      let revisions = try studio.store.structuredFactHistory(
        worldID: subject.worldID, factID: fact.id)
      page = .history(fact, revisions)
      failure = nil
    } catch { failure = error.localizedDescription }
  }

  private func inspect(_ evidence: StructuredFactEvidence) {
    do {
      page = .evidence(
        try studio.store.structuredFactSource(worldID: subject.worldID, evidence: evidence))
      failure = nil
    } catch { failure = error.localizedDescription }
  }

  private func showCapturePage() {
    guard placement == .main, inScope,
      ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil
    else { return }
    switch studio.captureHint {
    case "structured-fact-edit": edit(facts.first { $0.working.status == .draft })
    case "structured-fact-review":
      if let draft = facts.first(where: { $0.working.status == .draft }) { page = .review(draft) }
    case "structured-fact-evidence":
      if let evidence = facts.compactMap({ $0.working.evidence }).first { inspect(evidence) }
    default: break
    }
  }
}
