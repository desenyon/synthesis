import SwiftUI
import SynthesisCore

/// ⌘K: one keyboard-first surface for navigation, creation, search and settings.
struct CommandPalette: View {
  @ObservedObject var studio: Studio
  @State private var indexed: [LoreRecord] = []
  @State private var activity: [WorldActivity] = []
  @State private var searchFailure: String?
  @State private var activityFailure: String?
  @State private var index = 0
  @State private var contentHeight: CGFloat = 380
  @FocusState private var focused: Bool
  private var query: String { studio.paletteQuery }
  struct Item: Identifiable {
    let id: String
    var section: String
    var icon: String
    var title: String
    var detail: String = ""
    var tint: Color?
    var run: () -> Void
  }
  var body: some View {
    let items = Self.results(studio: studio, query: query, indexed: indexed, activity: activity)
    GeometryReader { geometry in
      let top: CGFloat = geometry.size.height >= 640 ? 96 : Metric.bar + 12
      ZStack(alignment: .top) {
        studio.t.scrim.ignoresSafeArea().onTapGesture { close() }
        VStack(spacing: 0) {
          HStack(spacing: 10) {
            StudioIcon("magnifyingglass", size: 15).foregroundStyle(studio.t.muted)
            TextField("Search your world or run a command", text: $studio.paletteQuery)
              .textFieldStyle(.plain).font(.studio(.body)).focused($focused)
              .accessibilityLabel("Search your world or run a command")
              .onSubmit { if items.indices.contains(index) { run(items[index]) } }
              .onKeyPress(.downArrow) {
                index = PaletteSelection.moved(index, by: 1, count: items.count)
                return .handled
              }
              .onKeyPress(.upArrow) {
                index = PaletteSelection.moved(index, by: -1, count: items.count)
                return .handled
              }
              .onKeyPress(.escape) {
                close()
                return .handled
              }
            Text("esc").font(.studio(size: 11, weight: .medium)).foregroundStyle(studio.t.muted)
              .padding(.horizontal, 6).padding(.vertical, 3)
              .background(studio.t.secondarySurface, in: RoundedRectangle(cornerRadius: 5))
          }.padding(.horizontal, 16).frame(height: 52)
          Rectangle().fill(studio.t.hairline).frame(height: 1)
          ScrollViewReader { proxy in
            ScrollView {
              VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                  if offset == 0 || items[offset - 1].section != item.section {
                    SectionLabel(title: item.section, t: studio.t).padding(.horizontal, 10)
                      .padding(.top, offset == 0 ? 4 : 12).padding(.bottom, 4)
                  }
                  Button {
                    run(item)
                  } label: {
                    row(item, selected: offset == index)
                  }
                  .buttonStyle(.plain).id(item.id)
                  .accessibilityAddTraits(offset == index ? .isSelected : [])
                  .help([item.title, item.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                }
                if items.isEmpty {
                  Text("Nothing matches “\(query)”.").font(.studio(size: 13))
                    .foregroundStyle(studio.t.secondary).frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
              }.padding(8).background {
                GeometryReader { size in
                  Color.clear
                    .onAppear { contentHeight = size.size.height }
                    .onChange(of: size.size.height) { _, height in contentHeight = height }
                }
              }
            }.frame(height: max(80, min(contentHeight, 380, geometry.size.height - top - 144)))
              .onChange(of: index) { _, value in
                if items.indices.contains(value) { proxy.scrollTo(items[value].id) }
              }
              .onChange(of: items.map(\.id)) { _, _ in
                index = 0
                if let first = items.first { proxy.scrollTo(first.id, anchor: .top) }
              }
          }
          if searchFailure != nil || activityFailure != nil {
            HStack {
              Text("Some results could not be loaded.").font(.studio(.caption))
                .foregroundStyle(studio.t.warning)
              Spacer()
              Button("Retry") { refresh(activity: true) }.buttonStyle(QuietButton(t: studio.t))
            }.padding(.horizontal, 14).padding(.vertical, 8)
          }
          Rectangle().fill(studio.t.hairline).frame(height: 1)
          HStack(spacing: 14) {
            hint("↑↓", "Navigate")
            hint("↵", "Open")
            Spacer(minLength: 8)
            Text(studio.world?.name ?? "").font(.studio(size: 11.5))
              .foregroundStyle(studio.t.muted).lineLimit(1)
          }.padding(.horizontal, 14).frame(height: 34)
        }
        .frame(width: max(280, min(600, geometry.size.width - 40)))
        .floatingPanel(studio.t, radius: Metric.panelRadius)
        .padding(.top, top)
        .accessibilityElement(children: .contain).accessibilityLabel("Search and commands")
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      focused = true
      refresh(activity: true)
    }
    .onChange(of: query) { _, _ in
      index = 0
      refresh(activity: false)
    }
    .onChange(of: studio.worldID) { _, _ in
      index = 0
      refresh(activity: true)
    }
    .onChange(of: studio.worldRevision) { _, _ in
      index = 0
      refresh(activity: true)
    }
  }
  private func refresh(activity includeActivity: Bool) {
    do {
      indexed = try studio.store.search(worldID: studio.worldID, query: query)
      searchFailure = nil
    } catch {
      indexed = []
      searchFailure = error.localizedDescription
    }
    if includeActivity {
      do {
        activity = try studio.store.recentWorldActivity(worldID: studio.worldID, limit: 100)
        activityFailure = nil
      } catch {
        activity = []
        activityFailure = error.localizedDescription
      }
    }
  }
  private func hint(_ key: String, _ label: String) -> some View {
    HStack(spacing: 5) {
      Text(key).font(.studio(size: 11, weight: .medium)).padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(studio.t.secondarySurface, in: RoundedRectangle(cornerRadius: 4))
      Text(label).font(.studio(size: 11.5))
    }.foregroundStyle(studio.t.muted)
  }
  private func row(_ item: Item, selected: Bool) -> some View {
    HStack(spacing: 11) {
      StudioIcon(item.icon, size: 14).foregroundStyle(item.tint ?? studio.t.secondary)
        .frame(width: 22)
      Text(item.title).font(.studio(size: 14)).lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(item.detail).font(.studio(.caption)).foregroundStyle(studio.t.muted)
        .lineLimit(1).frame(maxWidth: 180, alignment: .trailing)
    }.padding(.horizontal, 10).frame(height: 34)
      .entitySurface(studio.t, selected: selected, radius: Metric.smallRadius)
      .contentShape(Rectangle()).accessibilityElement(children: .combine)
  }
  private func close() { studio.palette = false }
  private func run(_ item: Item) {
    close()
    item.run()
  }
}

enum PaletteSelection {
  static func moved(_ index: Int, by offset: Int, count: Int) -> Int {
    max(0, min(max(0, count - 1), index + offset))
  }
}
