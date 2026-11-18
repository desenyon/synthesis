import AppKit
import SwiftUI
import SynthesisCore

/// Every document, entity and loose idea in the selected world, with an archive that can be
/// restored. Search uses the world-scoped full-text index, so tags and aliases match too.
enum LibraryFilter: String, Codable, CaseIterable {
  case all = "All"
  case documents = "Documents"
  case entities = "Entities"
  case ideas = "Ideas"
  case canon = "Canon"
  case sections = "Sections"
  case archived = "Archived"
}
enum LibraryOrder: String, Codable, CaseIterable {
  case recent = "Recently updated"
  case title = "Title"
}

struct LibraryScreen: View {
  @ObservedObject var studio: Studio
  private var query: String { studio.libraryQuery }
  @State private var indexed = Set<String>()
  @State private var searchFailure: String?
  private var filter: LibraryFilter { studio.libraryFilter }
  private var entityType: EntityTypeCollection? { studio.activeLibraryEntityType }
  private var order: LibraryOrder { studio.libraryOrder }
  @State private var archived: [LoreRecord] = []

  private func belongs(_ record: LoreRecord, to filter: LibraryFilter) -> Bool {
    switch filter {
    case .all, .archived: return true
    case .sections: return studio.sectionParents[record.id] != nil
    case .documents: return record.kind == "lore"
    case .entities: return record.kind == "entity"
    case .ideas: return record.kind == "capture"
    case .canon: return record.state == "canon" || record.canonical != nil
    }
  }
  private var scoped: [LoreRecord] {
    let source =
      filter == .archived
      ? archived
      : (filter == .sections || !query.trimmingCharacters(in: .whitespaces).isEmpty
        ? studio.records : studio.topLevelRecords)
    return source.filter(isInLens)
  }
  private func isInLens(_ record: LoreRecord) -> Bool {
    if let entityType { return entityType.recordIDs.contains(record.id) }
    guard let category = studio.libraryCategory else { return true }
    return Vocabulary.categoryKey(record.category) == Vocabulary.categoryKey(category)
  }
  private var visible: [LoreRecord] {
    var result = scoped.filter { belongs($0, to: filter) }
    let text = query.trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      result = result.filter { indexed.contains($0.id) }
    }
    if order == .title {
      result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    return result
  }
  private func count(for item: LibraryFilter) -> Int? {
    if item == .all { return nil }
    let rows =
      item == .archived
      ? archived : (item == .sections ? studio.records : studio.topLevelRecords)
    return rows.lazy.filter { row in
      (entityType == nil || isInLens(row)) && belongs(row, to: item)
    }.count
  }
  var body: some View {
    let rows = visible
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: entityType == nil
            ? studio.libraryCategory.map(categoryIcon) ?? Destination.library.icon
            : "circle.hexagongrid",
          title: entityType?.name ?? studio.libraryCategory ?? "Library",
          detail: "\(rows.count) \(rows.count == 1 ? "item" : "items")", t: studio.t)
        if entityType != nil || studio.libraryCategory != nil {
          LibraryCategoryBack(studio: studio)
        }
      } trailing: {
        DocumentHistoryMenu(studio: studio)
        LibrarySearchControl(studio: studio)
        BarAction(title: "New", icon: "plus", t: studio.t, primary: true, help: "New record · ⌘N") {
          studio.beginContextualRecordCreation()
        }
      }
      ContentHeader {
        ScrollView(.horizontal) {
          HStack(spacing: Space.sm) {
            ForEach(LibraryFilter.allCases, id: \.self) { item in
              if item != .archived || count(for: .archived) != 0 || filter == .archived {
                FilterChip(
                  title: item.rawValue,
                  count: count(for: item),
                  selected: filter == item, t: studio.t
                ) { studio.libraryFilter = item }
              }
            }
          }
        }.scrollIndicators(.never)
        Spacer(minLength: 8)
        if !studio.entityTypeCollections.isEmpty { LibraryEntityTypeMenu(studio: studio) }
        PlainMenu {
          ForEach(LibraryOrder.allCases, id: \.self) { item in
            Button {
              studio.libraryOrder = item
            } label: {
              if order == item {
                StudioLabel(item.rawValue, icon: "checkmark")
              } else {
                Text(item.rawValue)
              }
            }
          }
        } label: {
          HStack(spacing: 5) {
            StudioIcon("arrow.up.arrow.down", size: 10.5)
            Text(order.rawValue).font(.studio(size: 12.5))
          }.foregroundStyle(studio.t.secondary).padding(.horizontal, 8).frame(height: 26)
            .hoverFill(studio.t)
        }.help("Sort order")
      }
      Rectangle().fill(studio.t.hairline).frame(height: 1)
      if let searchFailure {
        EmptyState(
          icon: "magnifyingglass", title: "Check your search", message: searchFailure, t: studio.t
        ) {
          Button("Clear search") { studio.libraryQuery = "" }.buttonStyle(QuietButton(t: studio.t))
          Button("Retry") { refreshSearch() }.buttonStyle(QuietButton(t: studio.t))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if rows.isEmpty {
        emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          ContentColumn {
            LazyVStack(spacing: 1) {
              ForEach(rows) { record in
                RecordRow(
                  studio: studio, record: record, typeName: entityType?.name,
                  archived: filter == .archived
                ) {
                  refreshArchive()
                }.padding(.horizontal, -10)
              }
            }.padding(.vertical, 8)
          }
        }
      }
    }
    .onAppear {
      refreshArchive()
      refreshSearch()
    }
    .onChange(of: studio.records) { _, _ in
      refreshArchive()
      refreshSearch()
    }
    .onChange(of: query) { _, _ in refreshSearch() }
    .onChange(of: filter) { _, _ in refreshSearch() }
    .onChange(of: studio.libraryCategory) { _, _ in refreshSearch() }
    .onChange(of: studio.libraryEntityTypeID) { _, _ in refreshSearch() }
    .onChange(of: studio.worldRevision) { _, _ in refreshSearch() }
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
  private func refreshSearch() {
    do {
      let kind: String? =
        switch filter {
        case .documents: "lore"
        case .entities: "entity"
        case .ideas: "capture"
        default: nil
        }
      indexed = Set(
        try studio.store.search(
          worldID: studio.worldID, query: query,
          archived: filter == .archived,
          scope: LoreSearchScope(
            kind: kind, category: studio.libraryCategory, entityTypeID: entityType?.id,
            hasCanon: filter == .canon, sectionsOnly: filter == .sections)
        ).map(\.id))
      searchFailure = nil

    } catch {
      indexed = []
      searchFailure = error.localizedDescription
    }
  }
  private func refreshArchive() {
    archived = (try? studio.store.archivedRecords(worldID: studio.worldID)) ?? []
    if archived.isEmpty && filter == .archived { studio.libraryFilter = .all }
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
          studio.libraryQuery = ""
          studio.libraryFilter = .all
        }.buttonStyle(QuietButton(t: studio.t))
      }
    } else if let entityType {
      EmptyState(
        icon: "circle.hexagongrid", title: "No entities of this type yet",
        message: "Entities assigned to \(entityType.name) collect here.", t: studio.t
      ) {
        Button("New entity") {
          studio.newRecordKind = "entity"
          studio.sheet = .document
        }.buttonStyle(QuietButton(t: studio.t, primary: true))
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
  @Environment(\.studioDensity) private var density
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var typeName: String?
  var archived = false
  var changed: () -> Void = {}
  private var categoryLabel: String {
    if let parentID = studio.sectionParents[record.id],
      let parent = studio.records.first(where: { $0.id == parentID })
    {
      return "Section of \(parent.title)"
    }
    if let typeName { return typeName }
    return record.category.isEmpty
      ? Vocabulary.kindLabel(record.kind) : Vocabulary.displayCategory(record.category)
  }
  var body: some View {
    Button {
      if !archived { studio.openRecord(record) }
    } label: {
      HStack(spacing: 12) {
        CategoryTile(record: record, t: studio.t, size: density.thumbnail)
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(record.title).font(.studio(.control))
              .foregroundStyle(studio.t.text).lineLimit(1)
            if studio.isFavorite(record.id) {
              StudioIcon("pin", size: 11).foregroundStyle(studio.t.secondary)
                .help("In sidebar Favorites").accessibilityLabel("Favorite")
            }
          }
          if studio.preferences.libraryPreviews {
            Text(
              record.body.isEmpty
                ? "Empty" : record.body.replacingOccurrences(of: "\n", with: " ")
            ).font(.studio(size: 12.5)).foregroundStyle(studio.t.muted).lineLimit(1)
          }
        }
        Spacer(minLength: 16)
        Text(categoryLabel)
          .font(.studio(.caption)).foregroundStyle(studio.t.muted).lineLimit(1)
          .frame(width: 150, alignment: .leading)
        if archived {
          Button("Restore") {
            studio.restore(recordID: record.id)
            changed()
          }.buttonStyle(QuietButton(t: studio.t))
        } else {
          Text(relativeDate(record.updatedAt)).font(.studio(.caption)).monospacedDigit()
            .foregroundStyle(studio.t.muted).frame(width: 72, alignment: .trailing)
        }
      }.padding(.horizontal, 10).frame(
        height: density.libraryRow - (studio.preferences.libraryPreviews ? 0 : 10)
      )
      .entitySurface(
        studio.t,
        selected: !archived && studio.workspaceInspector
          && studio.effectiveInspection == .record(record.id), radius: 9)
    }.buttonStyle(.plain)
      .recordDraggable(archived ? nil : record, studio: studio)
      .contextMenu {
        if archived {
          Button("Restore") {
            studio.restore(recordID: record.id)
            changed()
          }
        } else {
          Button("Open") { studio.openRecord(record) }
          SplitRecordAction(studio: studio, record: record)
          Button("Inspect") { studio.inspect(.record(record.id)) }
          RecordFavoriteAction(studio: studio, record: record)
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
