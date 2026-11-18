import SwiftUI
import SynthesisCore

/// An in-window browser stays mounted when the drag surface on the board takes over hit testing.
struct CanvasReferencePicker: View {
  static let captureStates = [
    "canvas-reference-events", "canvas-reference-proposals", "manual-canvas-reference-atlas",
    "canvas-reference-empty",
  ]

  enum Category: CaseIterable, Hashable {
    case events, proposals, atlas

    var title: String {
      switch self {
      case .events: "Events"
      case .proposals: "Proposals"
      case .atlas: "Atlas images"
      }
    }
    var kind: WorldReference.Kind {
      switch self {
      case .events: .event
      case .proposals: .proposal
      case .atlas: .atlasImage
      }
    }
    var icon: String {
      switch self {
      case .events: "calendar"
      case .proposals: "doc.text"
      case .atlas: "photo"
      }
    }
  }

  private struct Search: Hashable {
    let kind: WorldReference.Kind
    let query: String
    let page: Int
    let revision: Int
  }
  private struct Result {
    let search: Search
    let page: CanvasReferenceChoicePage?
    let failure: String?
  }

  @ObservedObject var studio: Studio
  let worldID: String
  let place: (WorldReference) -> Void
  let close: () -> Void
  @State private var category: Category
  @State private var query: String
  @State private var page = 0
  @State private var result: Result?

  init(
    studio: Studio, initialCategory: Category = .events, initialQuery: String = "",
    place: @escaping (WorldReference) -> Void, close: @escaping () -> Void
  ) {
    self.studio = studio
    worldID = studio.worldID
    self.place = place
    self.close = close
    _category = State(initialValue: initialCategory)
    _query = State(initialValue: initialQuery)
  }

  var body: some View {
    let search = Search(
      kind: category.kind, query: query.trimmingCharacters(in: .whitespacesAndNewlines),
      page: page, revision: studio.worldRevision)
    VStack(alignment: .leading, spacing: Space.sm) {
      HStack {
        Text("World references").font(.studio(.cardTitle))
        Spacer(minLength: 4)
        IconButton(icon: "xmark", label: "Close world references", t: studio.t, action: close)
      }
      SegmentedSwitch(
        choices: Category.allCases.map { .init(value: $0, title: $0.title) },
        selected: category, label: "Reference type", t: studio.t
      ) {
        category = $0
        page = 0
      }
      SearchField(
        text: $query, placeholder: "Find \(category.title.lowercased())", t: studio.t)
      results(search)
    }
    .foregroundStyle(studio.t.text)
    .padding(12)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .floatingPanel(studio.t)
    .onChange(of: query) { _, _ in page = 0 }
    .onExitCommand(perform: close)
    .task(id: search) {
      if !search.query.isEmpty {
        do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
      }
      guard !Task.isCancelled, studio.worldID == worldID else { return }
      do {
        let page = try studio.store.canvasReferenceChoices(
          worldID: worldID, kind: search.kind, query: search.query, page: search.page)
        result = Result(search: search, page: page, failure: nil)
      } catch {
        result = Result(search: search, page: nil, failure: error.localizedDescription)
      }
    }
  }

  @ViewBuilder private func results(_ search: Search) -> some View {
    if let result, result.search == search {
      if let failure = result.failure {
        Text(failure).font(.studio(.label)).foregroundStyle(studio.t.warning)
      } else if let choices = result.page {
        if choices.choices.isEmpty {
          Text(
            search.query.isEmpty ? "No \(category.title.lowercased()) on this page." : "No matches."
          )
          .font(.studio(.label)).foregroundStyle(studio.t.secondary)
        } else {
          ScrollView {
            LazyVStack(spacing: 2) {
              ForEach(choices.choices) { choice in row(choice) }
            }
          }
        }
        if page > 0 || choices.hasNextPage {
          HStack {
            Button("Previous") { page -= 1 }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost)).disabled(page == 0)
            Spacer()
            Button("Next") { page += 1 }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost)).disabled(!choices.hasNextPage)
          }
        }
      }
    } else {
      ProgressView().controlSize(.small).accessibilityLabel("Finding world references")
    }
  }

  private func row(_ choice: CanvasReferenceChoice) -> some View {
    Button {
      place(choice.reference)
    } label: {
      HStack(spacing: Space.sm) {
        StudioIcon(category.icon, size: 14)
          .foregroundStyle(studio.t.secondary).frame(width: 20)
        VStack(alignment: .leading, spacing: 2) {
          Text(choice.title).font(.studio(.control)).lineLimit(1)
          if !choice.detail.isEmpty {
            Text(choice.detail).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(8)
      .contentShape(Rectangle())
      .hoverFill(studio.t)
    }
    .buttonStyle(.plain)
    .help("Drag \(choice.title) onto the board or activate to place it in the center")
    .accessibilityHint("Places a reference at the center of the canvas")
    .workspaceReferenceDraggable(
      choice.reference, title: choice.title, icon: category.icon, studio: studio)
  }
}
