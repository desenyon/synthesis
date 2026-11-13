import SwiftUI
import SynthesisCore

/// ⌘K: one keyboard-first surface for navigation, creation, search and settings.
struct CommandPalette: View {
  @ObservedObject var studio: Studio
  @State private var query = ""
  @State private var index = 0
  @FocusState private var focused: Bool
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
    let items = results
    ZStack(alignment: .top) {
      studio.t.scrim.ignoresSafeArea().onTapGesture { close() }
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass").font(.system(size: 15))
            .foregroundStyle(studio.t.muted)
          TextField("Search your world or run a command", text: $query)
            .textFieldStyle(.plain).font(.system(size: 16)).focused($focused)
            .onSubmit { run(items) }
            .onKeyPress(.downArrow) {
              index = min(items.count - 1, index + 1)
              return .handled
            }
            .onKeyPress(.upArrow) {
              index = max(0, index - 1)
              return .handled
            }
            .onKeyPress(.escape) {
              close()
              return .handled
            }
          Text("esc").font(.system(size: 11, weight: .medium)).foregroundStyle(studio.t.muted)
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
                row(item, selected: offset == index).id(item.id)
                  .onHover { if $0 { index = offset } }
                  .onTapGesture {
                    index = offset
                    run(items)
                  }
              }
              if items.isEmpty {
                Text("Nothing matches “\(query)”.").font(.system(size: 13))
                  .foregroundStyle(studio.t.secondary).frame(maxWidth: .infinity)
                  .padding(.vertical, 28)
              }
            }.padding(8)
          }.frame(maxHeight: 380)
            .onChange(of: index) { _, value in
              if items.indices.contains(value) { proxy.scrollTo(items[value].id) }
            }
        }
        Rectangle().fill(studio.t.hairline).frame(height: 1)
        HStack(spacing: 14) {
          hint("↑↓", "Navigate")
          hint("↵", "Open")
          Spacer()
          Text(studio.world?.name ?? "").font(.system(size: 11.5)).foregroundStyle(studio.t.muted)
        }.padding(.horizontal, 14).frame(height: 34)
      }
      .frame(width: 600).floatingPanel(studio.t, radius: Metric.panelRadius)
      .padding(.top, 96).padding(.horizontal, 20)
      .accessibilityElement(children: .contain).accessibilityLabel("Search and commands")
    }
    .onAppear { focused = true }
    .onChange(of: query) { _, _ in index = 0 }
  }
  private func hint(_ key: String, _ label: String) -> some View {
    HStack(spacing: 5) {
      Text(key).font(.system(size: 11, weight: .medium)).padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(studio.t.secondarySurface, in: RoundedRectangle(cornerRadius: 4))
      Text(label).font(.system(size: 11.5))
    }.foregroundStyle(studio.t.muted)
  }
  private func row(_ item: Item, selected: Bool) -> some View {
    HStack(spacing: 11) {
      Image(systemName: item.icon).font(.system(size: 13.5))
        .foregroundStyle(item.tint ?? studio.t.secondary).frame(width: 22)
      Text(item.title).font(.system(size: 14)).lineLimit(1)
      Spacer(minLength: 12)
      Text(item.detail).font(.system(size: 12)).foregroundStyle(studio.t.muted).lineLimit(1)
    }.padding(.horizontal, 10).frame(height: 34)
      .background(
        selected ? studio.t.secondarySurface : .clear, in: RoundedRectangle(cornerRadius: 7)
      )
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
  }
  private func close() { studio.palette = false }
  private func run(_ items: [Item]) {
    guard items.indices.contains(index) else { return }
    let item = items[index]
    close()
    item.run()
  }
  private func matches(_ text: String) -> Bool {
    query.isEmpty || text.localizedCaseInsensitiveContains(query)
  }
  private var results: [Item] {
    var items: [Item] = []
    let t = studio.t
    for (offset, destination) in Destination.allCases.enumerated()
    where matches(destination.rawValue) {
      items.append(
        Item(
          id: "go-\(destination.rawValue)", section: "Go to", icon: destination.icon,
          title: destination.rawValue, detail: "⌘\(offset + 1)"
        ) { studio.navigate(destination) })
    }
    let create: [(String, String, String, String, () -> Void)] = [
      (
        "New document", "doc.badge.plus", "⌘N", "lore",
        {
          studio.newRecordKind = "lore"
          studio.sheet = .document
        }
      ),
      (
        "New entity", "circle.hexagongrid", "", "entity",
        {
          studio.newRecordKind = "entity"
          studio.sheet = .document
        }
      ),
      (
        "Capture an idea", "lightbulb", "", "capture",
        {
          studio.newRecordKind = "capture"
          studio.sheet = .document
        }
      ),
      ("New conversation", "square.and.pencil", "⇧⌘N", "chat", { studio.newChat() }),
      ("New world…", "globe", "", "world", { studio.sheet = .world }),
    ]
    for entry in create where matches(entry.0) {
      items.append(
        Item(
          id: "new-\(entry.3)", section: "Create", icon: entry.1, title: entry.0, detail: entry.2,
          run: entry.4))
    }
    let found: [LoreRecord]
    if query.trimmingCharacters(in: .whitespaces).isEmpty {
      found = Array(studio.records.prefix(5))
    } else {
      let indexed = (try? studio.store.search(worldID: studio.worldID, query: query)) ?? []
      let titled = studio.records.filter { $0.title.localizedCaseInsensitiveContains(query) }
      found = Array((titled + indexed.filter { r in !titled.contains { $0.id == r.id } }).prefix(8))
    }
    for record in found {
      items.append(
        Item(
          id: "record-\(record.id)", section: query.isEmpty ? "Recent" : "Lore",
          icon: recordIcon(record), title: record.title,
          detail: [record.category, Vocabulary.stateLabel(record.state)].filter { !$0.isEmpty }
            .joined(separator: " · "), tint: t.category(record.category)
        ) { studio.openRecord(record) })
    }
    if !query.isEmpty {
      for chat in studio.conversations where matches(chat.title) {
        items.append(
          Item(
            id: "chat-\(chat.id)", section: "Conversations", icon: "bubble.left",
            title: chat.title, detail: relativeDate(chat.updatedAt)
          ) { studio.openChat(chat) })
      }
      for world in studio.worlds where world.id != studio.worldID && matches(world.name) {
        items.append(
          Item(
            id: "world-\(world.id)", section: "Worlds", icon: "globe", title: world.name,
            detail: world.demo ? "Sample" : "Switch world"
          ) { studio.switchWorld(world.id) })
      }
    }
    let assisted = studio.mode == .assisted
    let settings: [(String, String, String, () -> Void)] = [
      (
        assisted ? "Switch to Manual — no model requests" : "Switch to AI Assisted",
        assisted ? "hand.raised" : "sparkles", "⇧⌘M",
        { studio.setMode(assisted ? .manual : .assisted) }
      ),
      (
        studio.dark ? "Use light appearance" : "Use dark appearance",
        studio.dark ? "sun.max" : "moon", "", { studio.toggleTheme() }
      ),
      ("Open settings", "gearshape", "⌘,", { studio.sheet = .settings }),
      ("Export this world…", "square.and.arrow.up", "", { studio.exportWorld() }),
    ]
    for entry in settings where matches(entry.0) {
      items.append(
        Item(
          id: "set-\(entry.0)", section: "Preferences", icon: entry.1, title: entry.0,
          detail: entry.2, run: entry.3))
    }
    return items
  }
}
