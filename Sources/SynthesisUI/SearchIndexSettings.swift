import SwiftUI
import SynthesisCore

@MainActor final class SearchIndexSettingsModel: ObservableObject {
  enum State: Equatable {
    case unchecked, checking, rebuilding
    case checked(Set<SearchIndexComponent>, rebuilt: Bool)
    case failed(String)

    var isWorking: Bool { self == .checking || self == .rebuilding }
  }

  let worldID: String
  private let store: WorkspaceStore
  @Published private(set) var state = State.unchecked

  init(store: WorkspaceStore, worldID: String) {
    self.store = store
    self.worldID = worldID
  }

  func run(rebuild: Bool) async {
    guard !state.isWorking else { return }
    state = rebuild ? .rebuilding : .checking
    do {
      let stale = try await store.maintainSearchIndexes(worldID: worldID, rebuild: rebuild)
      state = .checked(stale, rebuilt: rebuild)
    } catch {
      state = .failed(error.localizedDescription)
    }
  }
}

@MainActor struct SearchIndexSettings: View {
  let item: SettingsItem
  let t: Theme
  @StateObject private var model: SearchIndexSettingsModel

  init(item: SettingsItem, store: WorkspaceStore, worldID: String, t: Theme) {
    self.item = item
    self.t = t
    _model = StateObject(wrappedValue: SearchIndexSettingsModel(store: store, worldID: worldID))
  }

  var body: some View {
    PreferenceRow(title: item.title, detail: item.detail + "\n" + status, t: t) {
      HStack(spacing: Space.sm) {
        Button("Check") { Task { await model.run(rebuild: false) } }
          .buttonStyle(QuietButton(t: t))
          .accessibilityLabel("Check search indexes")
        Button("Rebuild") { Task { await model.run(rebuild: true) } }
          .buttonStyle(QuietButton(t: t))
          .accessibilityLabel("Rebuild search indexes")
      }.disabled(model.state.isWorking)
    }.task {
      if model.state == .unchecked { await model.run(rebuild: false) }
    }
  }

  private var status: String {
    switch model.state {
    case .unchecked: "Ready to check the current world."
    case .checking: "Checking search indexes for this world…"
    case .rebuilding: "Rebuilding search indexes for this world…"
    case .checked(let stale, let rebuilt):
      if stale.isEmpty {
        rebuilt
          ? "Rebuilt and checked against saved world data."
          : "Current as of the last check."
      } else {
        "The index for \(affected(stale)) is out of date. Rebuild to refresh search results."
      }
    case .failed(let message):
      "Search index maintenance failed. \(message)"
    }
  }

  private func affected(_ stale: Set<SearchIndexComponent>) -> String {
    SearchIndexComponent.allCases.filter { stale.contains($0) }.map { part in
      switch part {
      case .records: "lore records"
      case .entityProperties: "entity properties"
      case .historicalNames: "historical names"
      }
    }.joined(separator: ", ")
  }
}
