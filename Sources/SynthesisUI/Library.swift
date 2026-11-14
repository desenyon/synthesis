import AppKit
import SwiftUI
import SynthesisCore

/// Every document, entity and loose idea in the selected world, with an archive that can be
/// restored. Search uses the world-scoped full-text index, so tags and aliases match too.
struct LibraryScreen: View {
  enum Filter: String, CaseIterable {
    case all = "All"
    case documents = "Documents"
    case entities = "Entities"
    case ideas = "Ideas"
    case canon = "Canon"
    case archived = "Archived"
  }
  enum Order: String, CaseIterable {
    case recent = "Recently updated"
    case title = "Title"
  }
  @ObservedObject var studio: Studio
  @State private var query = ""
  @State private var filter = Filter.all
  @State private var order = Order.recent
  @State private var archived: [LoreRecord] = []

  private func belongs(_ record: LoreRecord, to filter: Filter) -> Bool {
    switch filter {
    case .all, .archived: return true
    case .documents: return record.kind == "lore"
    case .entities: return record.kind == "entity"
    case .ideas: return record.kind == "capture"
    case .canon: return record.state == "canon" || record.canonical != nil
    }
  }
  private var scoped: [LoreRecord] {
    let source = filter == .archived ? archived : studio.records
    return source.filter { studio.libraryCategory == nil || $0.category == studio.libraryCategory }
  }
  private var visible: [LoreRecord] {
    var result = scoped.filter { belongs($0, to: filter) }
    let text = query.trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      let indexed = Set(
        ((try? studio.store.search(worldID: studio.worldID, query: text)) ?? []).map(\.id))
      result = result.filter {
        indexed.contains($0.id) || $0.title.localizedCaseInsensitiveContains(text)
          || $0.category.localizedCaseInsensitiveContains(text)
      }
    }
    if order == .title {
      result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    return result
  }
  var body: some View {
    let rows = visible
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: studio.libraryCategory.map(categoryIcon) ?? Destination.library.icon,
          title: studio.libraryCategory ?? "Library",
          detail: "\(rows.count) \(rows.count == 1 ? "item" : "items")", t: studio.t)
        if studio.libraryCategory != nil {
          Button("Show all") { studio.openLens(nil) }.buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .medium)).foregroundStyle(studio.t.accent)
            .padding(.leading, 4)
        }
      } trailing: {
        SearchField(text: $query, placeholder: "Search titles, text, tags", t: studio.t)
          .frame(minWidth: 140, idealWidth: 240, maxWidth: 240)
        BarAction(title: "New", icon: "plus", t: studio.t, primary: true, help: "New record · ⌘N") {
          studio.newRecordKind = studio.libraryCategory == nil ? "lore" : "entity"
          studio.sheet = .document
        }
      }
      HStack(spacing: 6) {
        ForEach(Filter.allCases, id: \.self) { item in
          if item != .archived || !archived.isEmpty || filter == .archived {
            FilterChip(
              title: item.rawValue,
              count: item == .archived
                ? archived.count
                : (item == .all ? nil : studio.records.filter { belongs($0, to: item) }.count),
              selected: filter == item, t: studio.t
            ) { filter = item }
          }
        }
        Spacer(minLength: 8)
        PlainMenu {
          ForEach(Order.allCases, id: \.self) { item in
            Button {
              order = item
            } label: {
              if order == item {
                Label(item.rawValue, systemImage: "checkmark")
              } else {
                Text(item.rawValue)
              }
            }
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "arrow.up.arrow.down").font(.system(size: 10.5))
            Text(order.rawValue).font(.system(size: 12.5))
          }.foregroundStyle(studio.t.secondary).padding(.horizontal, 8).frame(height: 26)
            .hoverFill(studio.t)
        }.help("Sort order")
      }.padding(.horizontal, 20).padding(.bottom, 10)
      Rectangle().fill(studio.t.hairline).frame(height: 1)
      if rows.isEmpty {
        emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 1) {
            if filter == .all, studio.libraryCategory == nil, query.isEmpty {
              WorldComposition(studio: studio).padding(.horizontal, 8).padding(.top, 6)
                .padding(.bottom, 12)
            }
            ForEach(rows) { record in
              RecordRow(studio: studio, record: record, archived: filter == .archived) {
                refreshArchive()
              }
            }
          }.padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: 1040).frame(maxWidth: .infinity)
        }
      }
    }
    .onAppear { refreshArchive() }
    .onChange(of: studio.records) { _, _ in refreshArchive() }
    .dropDestination(for: URL.self) { urls, _ in
      // Dropped Markdown or text files become imported drafts.
      let files = urls.filter {
        ["md", "markdown", "txt", "text"].contains($0.pathExtension.lowercased())
      }
      guard !files.isEmpty else { return false }
      studio.importDocuments(files)
      return true
    }
  }
  private func refreshArchive() {
    archived = (try? studio.store.archivedRecords(worldID: studio.worldID)) ?? []
    if archived.isEmpty && filter == .archived { filter = .all }
  }
  @ViewBuilder private var emptyState: some View {
    if !query.isEmpty || filter != .all {
      EmptyState(
        icon: "magnifyingglass", title: "Nothing matches",
        message: query.isEmpty
          ? "No \(filter.rawValue.lowercased()) here yet."
          : "No records match “\(query)” in this view.", t: studio.t
      ) {
        Button("Clear filters") {
          query = ""
          filter = .all
        }.buttonStyle(QuietButton(t: studio.t))
      }
    } else if let category = studio.libraryCategory {
      EmptyState(
        icon: categoryIcon(category), title: "No \(category.lowercased()) yet",
        message: "Entities you file under \(category) collect here.", t: studio.t
      ) {
        Button("New entity") {
          studio.newRecordKind = "entity"
          studio.sheet = .document
        }.buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    } else {
      EmptyState(
        icon: Destination.library.icon, title: "Your library is empty",
        message:
          "Documents, entities and loose ideas share one library. Start with anything — structure can come later.",
        t: studio.t
      ) {
        Button("New document") {
          studio.newRecordKind = "lore"
          studio.sheet = .document
        }.buttonStyle(QuietButton(t: studio.t, primary: true))
        Button("Capture an idea") {
          studio.newRecordKind = "capture"
          studio.sheet = .document
        }.buttonStyle(QuietButton(t: studio.t))
        if !studio.worlds.contains(where: { $0.demo }) {
          Button("Open sample world") { studio.loadSample() }
            .buttonStyle(QuietButton(t: studio.t, role: .ghost))
        }
      }
    }
  }
}

struct RecordRow: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var archived = false
  var changed: () -> Void = {}
  var body: some View {
    Button {
      if !archived { studio.openRecord(record) }
    } label: {
      HStack(spacing: 12) {
        CategoryTile(record: record, t: studio.t, size: 34)
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 7) {
            Text(record.title).font(.system(size: 14, weight: .medium))
              .foregroundStyle(studio.t.text).lineLimit(1)
            if record.origin == "ai-proposed" {
              Text("AI-proposed").font(.system(size: 11, weight: .medium))
                .foregroundStyle(studio.t.muted).padding(.horizontal, 6).frame(height: 17)
                .overlay(Capsule().stroke(studio.t.hairline, lineWidth: 1))
            }
          }
          Text(
            record.body.isEmpty
              ? "Empty" : record.body.replacingOccurrences(of: "\n", with: " ")
          ).font(.system(size: 12.5)).foregroundStyle(studio.t.muted).lineLimit(1)
        }
        Spacer(minLength: 16)
        Text(record.category.isEmpty ? Vocabulary.kindLabel(record.kind) : record.category)
          .font(.system(size: 12)).foregroundStyle(studio.t.muted).lineLimit(1)
          .frame(width: 110, alignment: .leading)
        StateBadge(state: record.state, t: studio.t).frame(width: 96, alignment: .leading)
        if archived {
          Button("Restore") {
            studio.restore(recordID: record.id)
            changed()
          }.buttonStyle(QuietButton(t: studio.t))
        } else {
          Text(relativeDate(record.updatedAt)).font(.system(size: 12)).monospacedDigit()
            .foregroundStyle(studio.t.muted).frame(width: 72, alignment: .trailing)
        }
      }.padding(.horizontal, 10).frame(height: 54).hoverFill(studio.t, radius: 9)
    }.buttonStyle(.plain)
      .contextMenu {
        if archived {
          Button("Restore") {
            studio.restore(recordID: record.id)
            changed()
          }
        } else {
          Button("Open") { studio.openRecord(record) }
          if studio.mode == .assisted {
            Button("Reference in conversation") {
              studio.reference(record)
              studio.navigate(.chat)
            }
          }
          Button("Show on canvas") { studio.showOnCanvas(record) }
          Divider()
          Button("Archive") { studio.archive(record) }
        }
      }
      .accessibilityLabel(
        "\(record.title), \(Vocabulary.kindLabel(record.kind)), \(Vocabulary.stateLabel(record.state))"
      )
  }
}
