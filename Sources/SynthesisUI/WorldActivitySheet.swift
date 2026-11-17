import SwiftUI
import SynthesisCore

extension WorldActivity.Kind {
  var label: String {
    switch self {
    case .record: "Records and rules"
    case .relationship: "Relationships"
    case .event: "Events"
    case .board: "Maps and canvases"
    case .proposal: "Review"
    case .lane: "Branches and periods"
    case .world: "World"
    case .conversation: "Conversations"
    }
  }
  var icon: String {
    switch self {
    case .record: "doc.text"
    case .relationship: Destination.knowledge.icon
    case .event, .lane: "calendar"
    case .board: "map"
    case .proposal: "checkmark.seal"
    case .world: "globe"
    case .conversation: "bubble.left"
    }
  }
}

extension Studio {
  func openChangeSource(_ change: WorldChange) {
    guard change.worldID == worldID, change.sourceAvailable, flushEditor() else { return }
    sheet = nil
    openActivity(change.source)
  }
}

struct WorldActivitySheet: View {
  @ObservedObject var studio: Studio
  @State private var query = ""
  @State private var kind: WorldActivity.Kind?
  @State private var action: WorldChange.Action?
  @State private var entries: [WorldChange] = []
  @State private var more = false
  @State private var failure: String?
  private func close() { studio.sheet = nil }
  var body: some View {
    SheetScaffold(
      title: "World activity",
      subtitle: "\(studio.world?.name ?? "This universe") · Editing history",
      t: studio.t, width: 680, close: close
    ) {
      SearchField(text: $query, placeholder: "Find a change, source or relationship", t: studio.t)
      HStack(spacing: 12) {
        ChoiceField(
          title: "Sources", selection: $kind,
          choices: [(nil, "All sources")]
            + WorldActivity.Kind.allCases.map { (Optional($0), $0.label) },
          t: studio.t)
        ChoiceField(
          title: "Changes", selection: $action,
          choices: [(nil, "All changes")]
            + WorldChange.Action.allCases.map { (Optional($0), actionLabel($0)) },
          t: studio.t)
      }
      ScrollViewReader { scroll in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 2) {
            Color.clear.frame(height: 1).id("activity-top")
            if let failure {
              Text(failure).font(.studio(.label)).foregroundStyle(studio.t.warning)
              Button("Retry") { load() }.buttonStyle(QuietButton(t: studio.t))
            } else if entries.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                Text("No matching activity").font(.studio(.cardTitle))
                Text(
                  "Saved edits, review decisions and connections appear here. Try a different search or filter."
                )
                .font(.studio(.label)).foregroundStyle(studio.t.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Button("Clear filters") {
                  query = ""
                  kind = nil
                  action = nil
                }
                .buttonStyle(QuietButton(t: studio.t))
              }.padding(.vertical, 16)
            } else {
              ForEach(entries) { entry in row(entry) }
            }
          }
        }.frame(height: 240)
          .onChange(of: query) { _, _ in
            load()
            scroll.scrollTo("activity-top")
          }
          .onChange(of: kind) { _, _ in
            load()
            scroll.scrollTo("activity-top")
          }
          .onChange(of: action) { _, _ in
            load()
            scroll.scrollTo("activity-top")
          }
      }
      Text(
        entries.contains(where: \.reconstructed)
          ? "Earlier entries come from saved revisions or the last saved state. Some older changes were not recorded."
          : "These are local editing times. Your world's chronology stays in Timeline."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      .fixedSize(horizontal: false, vertical: true)
    } footer: {
      if more {
        Button("Load earlier changes") { load(earlier: true) }.buttonStyle(QuietButton(t: studio.t))
      }
      IconButton(icon: "arrow.counterclockwise", label: "Refresh activity", t: studio.t) { load() }
      Spacer()
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
    .onAppear { load() }
    .onChange(of: studio.worldRevision) { _, _ in load() }
    .onChange(of: studio.worldID) { _, _ in
      query = ""
      kind = nil
      action = nil
      load()
    }
    .onChange(of: studio.captureNonce, initial: true) {
      guard studio.captureHint.contains("changes-") else { return }
      query = studio.captureHint.contains("empty") ? "No such expedition" : ""
      if studio.captureHint.contains("search") { query = "Mira" }
      action =
        studio.captureHint.contains("approvals")
        ? .approved
        : studio.captureHint.contains("archived") ? .archived : nil
      kind = studio.captureHint.contains("relations") ? .relationship : nil
      load()
    }
  }
  private func row(_ entry: WorldChange) -> some View {
    HStack(alignment: .top, spacing: 12) {
      StudioIcon(entry.kind.icon, size: 16).foregroundStyle(studio.t.secondary).frame(width: 20)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.title.isEmpty ? "World change" : entry.title).font(.studio(.control))
          .lineLimit(2).help(entry.title)
        Text(entry.detail).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
          .lineLimit(2).help(entry.detail)
        if !entry.sourceAvailable {
          Text("Source unavailable · History retained").font(.studio(.caption))
            .foregroundStyle(studio.t.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .trailing, spacing: 5) {
        Text(relativeDate(entry.createdAt)).font(.studio(.caption)).foregroundStyle(
          studio.t.secondary
        )
        .help(entry.createdAt)
        Button("Open source") { studio.openChangeSource(entry) }
          .buttonStyle(QuietButton(t: studio.t, role: .ghost)).disabled(!entry.sourceAvailable)
          .accessibilityLabel("Open current source for \(entry.title)")
      }
    }.padding(.horizontal, 4).padding(.vertical, 10)
      .overlay(alignment: .bottom) { studio.t.hairline.frame(height: 1) }
  }
  private func actionLabel(_ action: WorldChange.Action) -> String {
    switch action {
    case .created: "Created"
    case .updated: "Edited"
    case .approved: "Approved"
    case .rejected: "Dismissed"
    case .archived: "Archived"
    case .restored: "Restored"
    case .linked: "Linked"
    case .unlinked: "Unlinked"
    case .moved: "Moved"
    case .recorded: "Earlier saved state"
    }
  }
  private func load(earlier: Bool = false) {
    do {
      let next = try studio.store.worldChangeHistory(
        worldID: studio.worldID, query: query, kind: kind, action: action,
        before: earlier ? entries.last?.cursor : nil)
      entries = earlier ? entries + next : next
      more = next.count == 50
      failure = nil
    } catch {
      failure = error.localizedDescription
      more = false
    }
  }
}
