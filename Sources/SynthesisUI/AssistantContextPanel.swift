import SwiftUI
import SynthesisCore

struct ComposerAttachment: Identifiable {
  enum Kind: Equatable {
    case record, board, history

    var saved: WritableKeyPath<AssistantContextOptions, [String]> {
      switch self {
      case .record: \.recordIDs
      case .board: \.boardIDs
      case .history: \.laneIDs
      }
    }

    var temporary: WritableKeyPath<AssistantRequestPins, [String]> {
      switch self {
      case .record: \.recordIDs
      case .board: \.boardIDs
      case .history: \.laneIDs
      }
    }
  }
  let key: String
  let title: String
  let icon: String
  let kind: Kind
  let pinned: Bool
  var id: String { "\(kind):\(key)" }
}

extension Studio {
  var composerAttachments: [ComposerAttachment] {
    let pins = activeRequestPins
    let excludedRecords = contextExcludedRecordIDs
    let excludedHistory = contextExcludedLaneIDs
    func joined(_ kind: ComposerAttachment.Kind) -> [(id: String, pinned: Bool)] {
      let temporarilyPinned = Set(pins[keyPath: kind.temporary])
      let excluded: Set<String>
      switch kind {
      case .record: excluded = excludedRecords
      case .history: excluded = excludedHistory
      case .board: excluded = []
      }
      var seen = Set<String>()
      return (contextOptions[keyPath: kind.saved] + pins[keyPath: kind.temporary]).compactMap {
        guard seen.insert($0).inserted, !excluded.contains($0) else { return nil }
        return ($0, temporarilyPinned.contains($0))
      }
    }
    let items: [ComposerAttachment] =
      joined(.record).compactMap { id, pinned in
        records.first { $0.id == id }.map {
          ComposerAttachment(
            key: id, title: $0.title, icon: categoryIcon($0.category), kind: .record, pinned: pinned
          )
        }
      }
      + joined(.board).compactMap { id, pinned in
        contextBoards.first { $0.id == id }.map {
          ComposerAttachment(
            key: id, title: $0.name, icon: $0.kind == "atlas" ? "map" : "rectangle.on.rectangle",
            kind: .board, pinned: pinned)
        }
      }
      + joined(.history).compactMap { id, pinned in
        contextLanes.first { $0.id == id }.map {
          ComposerAttachment(
            key: id, title: $0.name, icon: "calendar", kind: .history, pinned: pinned)
        }
      }
    return items.filter(\.pinned) + items.filter { !$0.pinned }
  }
  func removeAttachment(_ item: ComposerAttachment) {
    if item.pinned {
      updateRequestPins { $0[keyPath: item.kind.temporary].removeAll { $0 == item.key } }
    } else {
      updateContext { $0[keyPath: item.kind.saved].removeAll { $0 == item.key } }
    }
  }
}

/// Local inspection, never a provider call. The preview and send use the same core builder.
struct AssistantContextPanel: View {
  private enum Exclusion: Equatable {
    case explicit, inherited

    var reason: String {
      switch self {
      case .explicit: "Excluded from context"
      case .inherited: "Excluded with its history branch"
      }
    }
  }

  @ObservedObject var studio: Studio
  let prompt: String
  let attachments: Bool
  @State private var nextMessageOnly: Bool
  @State private var section = "Records"
  @State private var query = ""
  @State private var acceptedRecordIDs: Set<String> = []
  @State private var preview: AssistantContext?
  @State private var failure: String?
  @State private var viewingSubmitted = false

  init(studio: Studio, prompt: String, attachments: Bool = false, nextMessageOnly: Bool = false) {
    self.studio = studio
    self.prompt = prompt
    self.attachments = attachments
    _nextMessageOnly = State(initialValue: nextMessageOnly)
    _viewingSubmitted = State(initialValue: studio.busy && studio.submittedAssistantContext != nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        StudioIcon(attachments ? "paperclip" : "eye", size: 16)
        Text(attachments ? "Attach world context" : "World context")
          .font(.studio(size: 15, weight: .semibold))
        Spacer(minLength: 0)
      }
      if attachments {
        attachmentBrowser
      } else {
        contextInspector
      }
    }.padding(18).frame(width: 410, height: 520, alignment: .topLeading)
      .foregroundStyle(studio.t.text).background(studio.t.surface)
      .onAppear(perform: refresh)
      .onChange(of: studio.contextOptions) { _, _ in refresh() }
      .onChange(of: studio.activeRequestPins) { _, _ in refresh() }
      .onChange(of: studio.worldRevision) { _, _ in refresh() }
      .onReceive(studio.$submittedAssistantContext) { submitted in
        if submitted == nil { viewingSubmitted = false }
        if submitted != nil && studio.busy { viewingSubmitted = true }
      }
  }

  private var attachmentBrowser: some View {
    let excludedRecords = studio.contextExcludedRecordIDs
    let excludedHistory = studio.contextExcludedLaneIDs
    return VStack(alignment: .leading, spacing: 10) {
      Text(
        "Live references from \(studio.world?.name ?? "this universe"). Nothing is copied or sent yet."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      HStack {
        SegmentedSwitch(
          choices: [
            .init(value: false, title: "Saved attachments"),
            .init(value: true, title: "Next message only"),
          ],
          selected: nextMessageOnly, label: "Attachment duration", t: studio.t
        ) { nextMessageOnly = $0 }
        Spacer(minLength: 6)
        if nextMessageOnly && !studio.activeRequestPins.isEmpty {
          Button("Clear pins", action: studio.clearRequestPins)
            .buttonStyle(QuietButton(t: studio.t, role: .ghost))
        }
      }
      HStack(spacing: 4) {
        ForEach(["Records", "Canvas", "Atlas", "History"], id: \.self) { name in
          Button {
            section = name
          } label: {
            Text(name).font(.studio(size: 12.5, weight: .medium)).padding(.horizontal, 10)
              .frame(height: 30)
              .background(section == name ? studio.t.secondarySurface : .clear, in: Capsule())
          }.buttonStyle(.plain).help("Browse \(name.lowercased())")
        }
      }
      SearchField(text: $query, placeholder: "Find in \(section.lowercased())", t: studio.t)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 3) {
          if section == "Records" {
            ForEach(matchingRecords) { record in
              recordRow(
                record, effectiveExclusions: excludedRecords,
                hasAcceptedVersion: !studio.contextOptions.canonOnly
                  || acceptedRecordIDs.contains(record.id))
            }
            if matchingRecords.isEmpty { empty }
          } else if section == "History" {
            ForEach(matchingLanes) { lane in
              historyRow(lane, effectiveExclusions: excludedHistory)
            }
            if matchingLanes.isEmpty { empty }
          } else {
            ForEach(matchingBoards) { board in
              attachRow(
                title: board.name,
                subtitle: board.kind == "atlas"
                  ? "Map metadata and linked places · no image bytes"
                  : "Linked records and their positions",
                icon: board.kind == "atlas" ? "map" : "rectangle.on.rectangle",
                key: board.id, kind: .board)
            }
            if matchingBoards.isEmpty { empty }
          }
        }
      }
      Text(
        nextMessageOnly
          ? "Pins apply to your next message. History includes nested periods. Maps and boards include linked lore and metadata."
          : "Attachments stay with this universe until removed. History includes nested periods. Maps and boards include linked lore and metadata."
      )
      .font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var contextInspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if studio.submittedAssistantContext != nil {
          ChoiceField(
            title: "Inspect", selection: $viewingSubmitted,
            choices: [(false, "Draft preview"), (true, "Submitted request")], t: studio.t)
        }
        if viewingSubmitted, let submitted = studio.submittedAssistantContext {
          Text(
            submitted.includesHistory
              ? "Snapshot prepared for the last request, with recent conversation enabled."
              : "Snapshot prepared for the last request. Earlier messages were withheld."
          ).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
          contextSources(submitted, submitted: true)
        } else {
          draftContext
        }
      }
    }
  }

  private var draftContext: some View {
    VStack(alignment: .leading, spacing: 14) {
      ChoiceField(
        title: "Read from", selection: studio.assistantContextBinding(\.scope),
        choices: AssistantContextScope.allCases.map { ($0, $0.title) }, t: studio.t)
      Toggle("Accepted lore only", isOn: studio.assistantContextBinding(\.canonOnly))
        .font(.studio(size: 13))
        .help("Use saved versions that you accepted as canon")
      if studio.contextOptions.canonOnly {
        Text(
          "Context uses saved accepted versions. Attachments and pins select eligible records. Working drafts, earlier messages and live workspace details are omitted."
        )
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      }
      exclusionSettings
      ChoiceField(
        title: "Context size", selection: studio.assistantContextBinding(\.budget),
        choices: AssistantContextBudget.allCases.map { ($0, $0.title) }, t: studio.t
      )
      .help("Limits direct references and the number of full record excerpts.")
      let count = studio.composerAttachments.filter(\.pinned).count
      if count > 0 {
        StudioLabel("\(count) pinned for the next message", icon: "pin")
          .font(.studio(.caption)).foregroundStyle(studio.t.accent)
      }
      Toggle(
        "Include workspace selection", isOn: studio.assistantContextBinding(\.includeSelection)
      ).font(
        .studio(size: 13)
      )
      .help("Includes selected lore and the active canvas, map or history branch.")
      Toggle(
        "Include recent conversation",
        isOn: studio.assistantContextHistoryBinding
      )
      .font(.studio(size: 13)).disabled(studio.contextOptions.restricted)
      Text(
        studio.contextOptions.restricted
          ? "Earlier messages are withheld for restricted context, so they cannot reintroduce excluded lore. Your new message is still sent."
          : "Up to 20 earlier messages accompany this request. Excerpts and the world index are bounded; this is not a token or cost estimate."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      if let failure {
        Text(failure).font(.studio(size: 13)).foregroundStyle(studio.t.warning)
      } else if let preview {
        contextSources(preview, submitted: false)
      }
      Text(
        "Preview refreshes on Send. Exclusions apply to context sources and their indexed data. Creator-written text is included. Images stay local."
      )
      .font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
    }
  }

  @ViewBuilder private func contextSources(_ context: AssistantContext, submitted: Bool)
    -> some View
  {
    HStack {
      Text("\(context.sources.count) \(submitted ? "submitted records" : "records to read")")
        .font(.studio(size: 13, weight: .semibold))
      Spacer()
      Text("of \(context.eligibleCount) eligible").font(.studio(size: 11.5)).foregroundStyle(
        studio.t.muted)
    }
    if context.sources.isEmpty {
      let message =
        submitted
        ? "No lore excerpts were included."
        : (studio.contextOptions.canonOnly
          ? "No accepted record versions match this context."
          : "No lore excerpts. Attach records or broaden the scope.")
      Text(message).font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
    }
    ForEach(context.sources) { source in
      DisclosureGroup {
        Text(String(source.record.body.prefix(3000))).font(.studio(size: 12.5))
          .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        if !submitted {
          Button("Exclude from context") {
            studio.updateContext {
              if !$0.excludedRecordIDs.contains(source.id) {
                $0.excludedRecordIDs.append(source.id)
              }
            }
          }.buttonStyle(QuietButton(t: studio.t))
        }
      } label: {
        VStack(alignment: .leading, spacing: 3) {
          Text(source.record.title).font(.studio(.label)).lineLimit(1)
          Text(source.reason).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
        }
      }.tint(studio.t.secondary)
    }
    DisclosureGroup("Exact lore excerpts") {
      Text(context.lore.isEmpty ? "No excerpts." : context.lore)
        .font(.studio(.caption)).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.font(.studio(size: 12.5)).tint(studio.t.secondary)
    DisclosureGroup("Structured workspace index") {
      Text(context.workspace).font(.system(size: 11, design: .monospaced))
        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
    }.font(.studio(size: 12.5)).tint(studio.t.secondary)
  }

  @ViewBuilder private var exclusionSettings: some View {
    let recordIDs = studio.contextOptions.excludedRecordIDs
    let laneIDs = studio.contextOptions.excludedLaneIDs
    if !recordIDs.isEmpty {
      Text("Excluded records").font(.studio(.captionStrong))
      ForEach(recordIDs, id: \.self) { id in
        let available = studio.records.first { $0.id == id }
        let retained = available ?? (try? studio.store.record(worldID: studio.worldID, id: id))
        exclusionSetting(
          title: retained?.title ?? "Unavailable record", archived: available == nil,
          id: id, path: \.excludedRecordIDs)
      }
    }
    if !laneIDs.isEmpty {
      let active = Set(studio.contextLanes.map(\.id))
      let groups =
        (try? studio.store.chronologyLanes(
          worldID: studio.worldID, includingArchived: true)) ?? []
      Text("Excluded history").font(.studio(.captionStrong))
      ForEach(laneIDs, id: \.self) { id in
        exclusionSetting(
          title: groups.first { $0.id == id }?.name ?? "Unavailable history group",
          archived: !active.contains(id), id: id, path: \.excludedLaneIDs)
      }
    }
  }

  private func exclusionSetting(
    title: String, archived: Bool, id: String,
    path: WritableKeyPath<AssistantContextOptions, [String]>
  ) -> some View {
    HStack(spacing: Space.sm) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.studio(.label)).lineLimit(1)
        if archived {
          Text("Archived").font(.studio(.caption)).foregroundStyle(studio.t.muted)
        }
      }.help(title)
      Spacer(minLength: 6)
      Button("Clear") {
        studio.updateContext { $0[keyPath: path].removeAll { $0 == id } }
      }
      .buttonStyle(QuietButton(t: studio.t))
      .accessibilityLabel("Clear explicit exclusion for \(title)")
    }
  }

  private var matchingRecords: [LoreRecord] {
    studio.records.filter {
      matches($0.title) || (!query.isEmpty && ($0.aliases ?? []).contains(where: matches))
    }
  }
  private var matchingLanes: [ChronologyLane] { studio.contextLanes.filter { matches($0.name) } }
  private var matchingBoards: [Board] {
    studio.contextBoards.filter {
      $0.kind == (section == "Atlas" ? "atlas" : "canvas") && matches($0.name)
    }
  }
  private func matches(_ value: String) -> Bool {
    query.isEmpty || value.localizedCaseInsensitiveContains(query)
  }
  private var empty: some View {
    Text(
      query.isEmpty
        ? "Nothing here yet. Create content in this workspace, then attach it." : "No matches."
    )
    .font(.studio(size: 13)).foregroundStyle(studio.t.secondary).padding(.vertical, 24)
  }
  private func recordRow(
    _ record: LoreRecord, effectiveExclusions: Set<String>, hasAcceptedVersion: Bool
  ) -> some View {
    let status = exclusion(
      record.id, explicit: studio.contextOptions.excludedRecordIDs,
      effective: hasAcceptedVersion ? effectiveExclusions : [])
    return HStack(spacing: 3) {
      attachRow(
        title: record.title, subtitle: Vocabulary.displayCategory(record.category),
        icon: categoryIcon(record.category), key: record.id, kind: .record,
        blockedReason: status?.reason ?? (hasAcceptedVersion ? nil : "No accepted version"))
      exclusionButton(
        title: record.title, id: record.id, status: status, kind: .record,
        path: \.excludedRecordIDs)
    }
  }

  private func historyRow(_ lane: ChronologyLane, effectiveExclusions: Set<String>) -> some View {
    let status = exclusion(
      lane.id, explicit: studio.contextOptions.excludedLaneIDs, effective: effectiveExclusions)
    return HStack(spacing: 3) {
      attachRow(
        title: lane.name,
        subtitle: [lane.kind.capitalized, lane.start, lane.end].filter { !$0.isEmpty }
          .joined(separator: " · "),
        icon: "calendar", key: lane.id, kind: .history,
        blockedReason: status == .inherited ? "Excluded by a parent history group" : status?.reason)
      exclusionButton(
        title: lane.name, id: lane.id, status: status, kind: .history,
        path: \.excludedLaneIDs)
    }
  }

  private func exclusion(_ id: String, explicit: [String], effective: Set<String>) -> Exclusion? {
    if explicit.contains(id) { return .explicit }
    if effective.contains(id) { return .inherited }
    return nil
  }

  private func exclusionButton(
    title: String, id: String, status: Exclusion?, kind: ComposerAttachment.Kind,
    path: WritableKeyPath<AssistantContextOptions, [String]>
  ) -> some View {
    let label =
      switch status {
      case .explicit: "Include \(title) again"
      case .inherited: "\(title): \(Exclusion.inherited.reason)"
      case nil: "Exclude \(title)"
      }
    return IconButton(
      icon: status == nil ? "minus.circle" : "eye.slash",
      label: label, t: studio.t, active: status != nil
    ) {
      studio.updateContext {
        if $0[keyPath: path].contains(id) {
          $0[keyPath: path].removeAll { $0 == id }
        } else {
          $0[keyPath: path].append(id)
          $0[keyPath: kind.saved].removeAll { $0 == id }
        }
      }
    }
    .disabled(status == .inherited)
  }

  private func attachRow(
    title: String, subtitle: String, icon: String, key: String, kind: ComposerAttachment.Kind,
    blockedReason: String? = nil
  ) -> some View {
    let saved = studio.contextOptions[keyPath: kind.saved].contains(key)
    let pinned = studio.activeRequestPins[keyPath: kind.temporary].contains(key)
    let selected = nextMessageOnly ? pinned : saved
    let blocked = blockedReason != nil && !selected
    let detail = [
      subtitle, blockedReason ?? (nextMessageOnly && saved ? "Saved attachment" : ""),
    ].filter { !$0.isEmpty }.joined(separator: " · ")
    let action = nextMessageOnly ? (selected ? "Unpin" : "Pin") : (selected ? "Remove" : "Attach")
    return Button {
      if nextMessageOnly {
        studio.updateRequestPins { toggle(key, in: &$0[keyPath: kind.temporary]) }
      } else {
        studio.updateContext { toggle(key, in: &$0[keyPath: kind.saved]) }
      }
    } label: {
      HStack(spacing: 9) {
        StudioIcon(icon, size: 16).foregroundStyle(studio.t.secondary)
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.studio(.label)).lineLimit(1)
          Text(detail).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(2)
        }
        Spacer(minLength: 6)
        StudioIcon(
          blockedReason == nil
            ? (selected ? "checkmark" : "plus") : (selected ? "minus.circle" : "eye.slash"),
          size: 12
        )
        .foregroundStyle(nextMessageOnly && pinned ? studio.t.accent : studio.t.secondary)
      }.padding(9).frame(maxWidth: .infinity, alignment: .leading).hoverFill(studio.t)
    }.buttonStyle(.plain).disabled(blocked)
      .accessibilityLabel(blocked ? "\(title), \(blockedReason ?? "")" : "\(action) \(title)")
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private func toggle(_ id: String, in values: inout [String]) {
    if values.contains(id) { values.removeAll { $0 == id } } else { values.append(id) }
  }
  private func refresh() {
    if attachments {
      acceptedRecordIDs =
        studio.contextOptions.canonOnly
        ? WorkspaceStore.assistantAcceptedRecordIDs(in: studio.records) : []
      return
    }
    do {
      preview = try studio.previewContext(prompt: prompt)
      failure = nil
    } catch {
      preview = nil
      failure = error.localizedDescription
    }
  }
}

extension Studio {
  func assistantContextBinding<Value>(
    _ path: WritableKeyPath<AssistantContextOptions, Value>
  ) -> Binding<Value> {
    let world = worldID
    let original = contextOptions[keyPath: path]
    return Binding(
      get: { self.worldID == world ? self.contextOptions[keyPath: path] : original },
      set: { value in
        guard self.worldID == world else { return }
        self.updateContext { $0[keyPath: path] = value }
      })
  }

  var assistantContextHistoryBinding: Binding<Bool> {
    let world = worldID
    return Binding(
      get: {
        self.worldID == world && self.contextOptions.includeHistory
          && !self.contextOptions.restricted
      },
      set: { value in
        guard self.worldID == world, !self.contextOptions.restricted else { return }
        self.updateContext { $0.includeHistory = value }
      })
  }
}
