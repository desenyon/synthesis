import SwiftUI
import SynthesisCore

/// Working name history belongs to the entity, whichever workspace opened it.
struct EntityNamePeriodsSheet: View {
  private enum Form {
    case add
    case edit(EntityNamePeriod)
  }

  @ObservedObject var studio: Studio
  let entity: LoreRecord
  let placement: EditorPlacement
  let editForCapture: Bool
  let close: () -> Void
  @State private var periods: [EntityNamePeriod] = []
  @State private var form: Form?
  @State private var draft = EntityNamePeriodDraft()
  @State private var loadingError: String?
  @State private var failure: String?

  private var inScope: Bool {
    let current = placement == .main ? studio.selectedRecord : studio.splitRecord
    return studio.worldID == entity.worldID
      && current?.worldID == entity.worldID && current?.id == entity.id
  }

  private var valid: Bool {
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return !name.isEmpty
      && [draft.name, draft.startLabel, draft.endLabel].allSatisfy {
        $0.trimmingCharacters(in: .whitespacesAndNewlines).count <= EntityNamePeriodDraft.textLimit
      }
  }

  private var heading: String {
    switch form {
    case .add: "Add a dated name"
    case .edit: "Edit dated name"
    case nil: "Names over time"
    }
  }

  var body: some View {
    SheetScaffold(title: heading, subtitle: entity.title, t: studio.t, width: 500, close: close) {
      if !inScope {
        Text("This editor changed. Reopen name history from the entity.")
          .font(.studio(.control)).foregroundStyle(studio.t.warning)
      } else if form != nil {
        fields
      } else {
        entries
      }
      if let failure {
        Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger)
      }
    } footer: {
      Spacer()
      if form != nil {
        Button("Back") {
          form = nil
          failure = nil
        }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
        Button("Save", action: save)
          .buttonStyle(QuietButton(t: studio.t, primary: true))
          .keyboardShortcut(.defaultAction).disabled(!inScope || !valid)
      } else {
        Button("Done", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
        Button("Add entry") {
          draft = .init()
          form = .add
          failure = nil
        }
        .buttonStyle(QuietButton(t: studio.t, primary: true))
        .disabled(!inScope || loadingError != nil)
      }
    }
    .onAppear {
      load()
      if editForCapture, ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
        let period = periods.first
      {
        edit(period)
      }
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
  }

  @ViewBuilder private var entries: some View {
    if let loadingError {
      EmptyState(
        icon: "clock.arrow.circlepath", title: "Name history unavailable", message: loadingError,
        t: studio.t
      ) {
        Button("Retry", action: load).buttonStyle(QuietButton(t: studio.t))
      }
    } else if periods.isEmpty {
      EmptyState(
        icon: "clock.arrow.circlepath", title: "No dated names yet",
        message: "Add names and aliases used at different points in this entity’s history.",
        t: studio.t
      ) { EmptyView() }
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: Space.xs) {
          ForEach(periods) { period in
            row(period)
          }
        }
      }.frame(height: min(280, CGFloat(periods.count) * 70))
    }
  }

  private var fields: some View {
    VStack(alignment: .leading, spacing: Space.md) {
      ChoiceField(
        title: "Kind", selection: $draft.kind,
        choices: EntityNameKind.allCases.map { ($0, $0.title) }, t: studio.t)
      FormField(
        label: draft.kind.title, placeholder: "Enter a name", text: $draft.name,
        t: studio.t)
      HStack(alignment: .top, spacing: Space.md) {
        FormField(label: "Start", placeholder: "Unknown", text: $draft.startLabel, t: studio.t)
          .accessibilityLabel("Name start")
        FormField(label: "End", placeholder: "Unknown", text: $draft.endLabel, t: studio.t)
          .accessibilityLabel("Name end")
      }
      Text("Dates can use your world’s wording. Leave either boundary blank when it’s unknown.")
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
    }
  }

  private func row(_ period: EntityNamePeriod) -> some View {
    HStack(spacing: Space.md) {
      VStack(alignment: .leading, spacing: 4) {
        Text(period.name).font(.studio(.control)).lineLimit(1)
        Text("\(period.kind.title) · \(dateSummary(period))")
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(2)
      }.frame(maxWidth: .infinity, alignment: .leading)
        .help(period.name)
      IconMenu(icon: "ellipsis", label: "Actions for \(period.name)", t: studio.t) {
        Button("Edit…") { edit(period) }
        if period.name != entity.title {
          Button("Use as working title") { useTitle(period) }
        }
        Divider()
        Button("Archive") { archive(period) }
      }
    }.padding(Space.sm).hoverFill(studio.t)
  }

  private func dateSummary(_ period: EntityNamePeriod) -> String {
    switch (period.startLabel.isEmpty, period.endLabel.isEmpty) {
    case (true, true): "Dates unknown"
    case (true, false): "Start unknown · Until \(period.endLabel)"
    case (false, true): "From \(period.startLabel) · End unknown"
    case (false, false): "\(period.startLabel) – \(period.endLabel)"
    }
  }

  private func load() {
    guard inScope else {
      periods = []
      return
    }
    do {
      periods = try studio.store.entityNamePeriods(worldID: entity.worldID, recordID: entity.id)
      loadingError = nil
    } catch {
      periods = []
      loadingError = error.localizedDescription
    }
  }

  private func edit(_ period: EntityNamePeriod) {
    form = .edit(period)
    draft = period.draft
    failure = nil
  }

  private func save() {
    guard inScope, valid, let form, studio.flushEditor() else { return }
    do {
      switch form {
      case .add:
        try studio.store.createEntityNamePeriod(
          worldID: entity.worldID, recordID: entity.id, draft: draft)
      case .edit(let expected):
        try studio.store.updateEntityNamePeriod(
          worldID: entity.worldID, expected: expected, draft: draft)
      }
      self.form = nil
      failure = nil
      load()
      studio.perform { try studio.reload() }
    } catch { failure = error.localizedDescription }
  }

  private func archive(_ period: EntityNamePeriod) {
    guard inScope, studio.flushEditor() else { return }
    do {
      let archived = try studio.store.archiveEntityNamePeriod(
        worldID: entity.worldID, expected: period)
      studio.perform { try studio.reload() }
      studio.show("Archived “\(period.name)”", icon: "archivebox", actionTitle: "Undo") {
        [weak studio] in
        guard let studio else { return }
        studio.perform {
          try studio.store.restoreEntityNamePeriod(
            worldID: archived.worldID, recordID: archived.recordID, id: archived.id,
            expectedRevision: archived.revision)
          if studio.worldID == archived.worldID { try studio.reload() }
        }
      }
      close()
    } catch { failure = error.localizedDescription }
  }

  private func useTitle(_ period: EntityNamePeriod) {
    guard inScope, studio.flushEditor() else { return }
    do {
      let current = try studio.store.record(worldID: entity.worldID, id: entity.id)
      let active = try studio.store.entityNamePeriods(
        worldID: current.worldID, recordID: current.id)
      guard active.contains(period) else { throw SynthesisError.stale }
      guard current.title != period.name else {
        close()
        return
      }
      let changed = try studio.store.updateEntityWorkingTitle(
        worldID: current.worldID, expected: current, title: period.name)
      studio.perform { try studio.reload() }
      studio.show("Working title updated", icon: "checkmark.circle", actionTitle: "Undo") {
        [weak studio] in
        guard let studio, studio.worldID != changed.worldID || studio.flushEditor() else { return }
        studio.perform {
          try studio.store.updateEntityWorkingTitle(
            worldID: changed.worldID, expected: changed, title: current.title)
          if studio.worldID == changed.worldID { try studio.reload() }
        }
      }
      close()
    } catch { failure = error.localizedDescription }
  }
}
