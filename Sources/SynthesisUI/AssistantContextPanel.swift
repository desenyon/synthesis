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
    let excluded = Set(contextOptions.excludedRecordIDs)
    func joined(_ kind: ComposerAttachment.Kind) -> [(id: String, pinned: Bool)] {
      let temporarilyPinned = Set(pins[keyPath: kind.temporary])
      var seen = Set<String>()
      return (contextOptions[keyPath: kind.saved] + pins[keyPath: kind.temporary]).compactMap {
        guard seen.insert($0).inserted, kind != .record || !excluded.contains($0) else {
          return nil
        }
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
  @ObservedObject var studio: Studio
  let prompt: String
  let attachments: Bool
  @State private var nextMessageOnly: Bool
  @State private var section = "Records"
  @State private var query = ""
  @State private var preview: AssistantContext?
  @State private var failure: String?

  init(studio: Studio, prompt: String, attachments: Bool = false, nextMessageOnly: Bool = false) {
    self.studio = studio
    self.prompt = prompt
    self.attachments = attachments
    _nextMessageOnly = State(initialValue: nextMessageOnly)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        StudioIcon(attachments ? "paperclip" : "eye", size: 16)
        Text(attachments ? "Attach world context" : "Context for this message")
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
  }

  private var attachmentBrowser: some View {
    VStack(alignment: .leading, spacing: 10) {
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
              recordRow(record)
            }
            if matchingRecords.isEmpty { empty }
          } else if section == "History" {
            ForEach(matchingLanes) { lane in
              attachRow(
                title: lane.name,
                subtitle: [lane.kind.capitalized, lane.start, lane.end].filter { !$0.isEmpty }
                  .joined(separator: " · "), icon: "calendar",
                key: lane.id, kind: .history)
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
        ChoiceField(
          title: "Read from", selection: option(\.scope),
          choices: AssistantContextScope.allCases.map { ($0, $0.title) }, t: studio.t)
        ChoiceField(
          title: "Context size", selection: option(\.budget),
          choices: AssistantContextBudget.allCases.map { ($0, $0.title) }, t: studio.t
        )
        .help("Limits direct references and the number of full record excerpts.")
        if !studio.activeRequestPins.isEmpty {
          let count = studio.composerAttachments.filter(\.pinned).count
          StudioLabel("\(count) pinned for the next message", icon: "pin")
            .font(.studio(.caption)).foregroundStyle(studio.t.accent)
        }
        Toggle("Include workspace selection", isOn: option(\.includeSelection)).font(
          .studio(size: 13)
        )
        .help("Includes selected lore and the active canvas, map or history branch.")
        Toggle(
          "Include recent conversation",
          isOn: Binding(
            get: { studio.contextOptions.includeHistory && !studio.contextOptions.restricted },
            set: { value in studio.updateContext { $0.includeHistory = value } }
          )
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
          HStack {
            Text("\(preview.sources.count) records to read").font(
              .studio(size: 13, weight: .semibold))
            Spacer()
            Text("of \(preview.eligibleCount) eligible").font(.studio(size: 11.5)).foregroundStyle(
              studio.t.muted)
          }
          if preview.sources.isEmpty {
            Text(
              "No lore excerpts. Attach records or broaden the scope to give the assistant more context."
            )
            .font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
          }
          ForEach(preview.sources) { source in
            DisclosureGroup {
              Text(String(source.record.body.prefix(3000))).font(.studio(size: 12.5))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
              Button("Exclude from context") {
                studio.updateContext {
                  if !$0.excludedRecordIDs.contains(source.id) {
                    $0.excludedRecordIDs.append(source.id)
                  }
                }
              }.buttonStyle(QuietButton(t: studio.t))
            } label: {
              VStack(alignment: .leading, spacing: 3) {
                Text(source.record.title).font(.studio(.label)).lineLimit(1)
                Text(source.reason).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
              }
            }.tint(studio.t.secondary)
          }
          DisclosureGroup("Exact lore excerpts") {
            Text(preview.lore.isEmpty ? "No excerpts." : preview.lore)
              .font(.studio(.caption)).textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }.font(.studio(size: 12.5)).tint(studio.t.secondary)
          DisclosureGroup("Structured workspace index") {
            Text(preview.workspace).font(.system(size: 11, design: .monospaced))
              .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
          }.font(.studio(size: 12.5)).tint(studio.t.secondary)
        }
        if !studio.contextOptions.excludedRecordIDs.isEmpty {
          Text("Excluded records").font(.studio(size: 12, weight: .semibold))
          ForEach(excludedRecords) { record in
            HStack {
              Text(record.title).font(.studio(size: 12.5)).lineLimit(1)
              Spacer()
              Button("Include") {
                studio.updateContext { $0.excludedRecordIDs.removeAll { $0 == record.id } }
              }
              .buttonStyle(QuietButton(t: studio.t))
            }
          }
        }
        Text(
          "Preview is local and refreshed at Send. Exclusions filter records and their indexed data, not mentions inside allowed text or your message. Images are not sent."
        )
        .font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
      }
    }
  }

  private var matchingRecords: [LoreRecord] {
    studio.records.filter {
      matches($0.title) || (!query.isEmpty && ($0.aliases ?? []).contains(where: matches))
    }
  }
  private var excludedRecords: [LoreRecord] {
    studio.contextOptions.excludedRecordIDs.compactMap {
      try? studio.store.record(worldID: studio.worldID, id: $0)
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
  private func recordRow(_ record: LoreRecord) -> some View {
    let excluded = studio.contextOptions.excludedRecordIDs.contains(record.id)
    return HStack(spacing: 3) {
      attachRow(
        title: record.title, subtitle: Vocabulary.displayCategory(record.category),
        icon: categoryIcon(record.category), key: record.id, kind: .record, excluded: excluded)
      IconButton(
        icon: excluded ? "eye.slash" : "minus.circle",
        label: excluded ? "Include \(record.title) again" : "Exclude \(record.title)", t: studio.t,
        active: excluded
      ) {
        studio.updateContext {
          toggle(record.id, in: &$0.excludedRecordIDs)
          $0.recordIDs.removeAll { $0 == record.id }
        }
      }
    }
  }
  private func attachRow(
    title: String, subtitle: String, icon: String, key: String, kind: ComposerAttachment.Kind,
    excluded: Bool = false
  ) -> some View {
    let saved = studio.contextOptions[keyPath: kind.saved].contains(key)
    let pinned = studio.activeRequestPins[keyPath: kind.temporary].contains(key)
    let selected = nextMessageOnly ? pinned : saved
    let blocked = nextMessageOnly && excluded && !pinned
    let detail = [
      subtitle, excluded ? "Excluded" : (nextMessageOnly && saved ? "Saved attachment" : ""),
    ].filter { !$0.isEmpty }.joined(separator: " · ")
    let action = nextMessageOnly ? (selected ? "Unpin" : "Pin") : (selected ? "Remove" : "Attach")
    return Button {
      if nextMessageOnly {
        studio.updateRequestPins { toggle(key, in: &$0[keyPath: kind.temporary]) }
      } else {
        studio.updateContext {
          toggle(key, in: &$0[keyPath: kind.saved])
          if kind == .record { $0.excludedRecordIDs.removeAll { $0 == key } }
        }
      }
    } label: {
      HStack(spacing: 9) {
        StudioIcon(icon, size: 16).foregroundStyle(studio.t.secondary)
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.studio(.label)).lineLimit(1)
          Text(detail).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(2)
        }
        Spacer(minLength: 6)
        StudioIcon(blocked ? "eye.slash" : (selected ? "checkmark" : "plus"), size: 12)
          .foregroundStyle(nextMessageOnly && pinned ? studio.t.accent : studio.t.secondary)
      }.padding(9).frame(maxWidth: .infinity, alignment: .leading).hoverFill(studio.t)
    }.buttonStyle(.plain).disabled(blocked)
      .accessibilityLabel(blocked ? "\(title), excluded from context" : "\(action) \(title)")
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private func toggle(_ id: String, in values: inout [String]) {
    if values.contains(id) { values.removeAll { $0 == id } } else { values.append(id) }
  }
  private func option<Value>(_ path: WritableKeyPath<AssistantContextOptions, Value>) -> Binding<
    Value
  > {
    Binding(
      get: { studio.contextOptions[keyPath: path] },
      set: { value in studio.updateContext { $0[keyPath: path] = value } })
  }
  private func refresh() {
    do {
      preview = try studio.previewContext(prompt: prompt)
      failure = nil
    } catch {
      preview = nil
      failure = error.localizedDescription
    }
  }
}
