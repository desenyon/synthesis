import SwiftUI

struct SidebarCustomizationSheet: View {
  @ObservedObject var studio: Studio
  @State private var query = ""
  private enum Page: String, CaseIterable {
    case arrangement = "Arrangement"
    case categories = "Categories"
    case favorites = "Favorites"
  }
  @State private var page = Page.arrangement
  private func close() { studio.sheet = nil }
  var body: some View {
    SheetScaffold(
      title: "Customize navigation",
      subtitle:
        "For \(studio.world?.name ?? "this universe") on this Mac. Your content stays in Library.",
      t: studio.t, width: 560, close: close
    ) {
      if let error = studio.sidebarConfigurationError {
        Text(error).font(.studio(.label)).foregroundStyle(studio.t.warning)
      }
      SegmentedSwitch(
        choices: Page.allCases.map { .init(value: $0, title: $0.rawValue) },
        selected: page, label: "Navigation customization", t: studio.t
      ) { page = $0 }
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if page == .arrangement {
            VStack(alignment: .leading, spacing: 4) {
              SectionLabel(title: "Section order", t: studio.t)
              ForEach(Array(studio.sidebarConfiguration.sections.enumerated()), id: \.element.id) {
                index, section in
                HStack {
                  Text(section.title).font(.studio(.label))
                  if section == .favorites && !studio.hasSidebarFavorites {
                    Text("Appears when pinned").font(.studio(.caption)).foregroundStyle(
                      studio.t.muted)
                  }
                  Spacer()
                  moveControls(
                    section.title, index: index, count: studio.sidebarConfiguration.sections.count
                  ) {
                    studio.moveSidebarSection(section, by: $0)
                  }
                }.frame(height: 32)
              }
            }
          } else if page == .favorites {
            favoriteRecords
            if !studio.sidebarConfiguration.pinnedCategories.isEmpty {
              VStack(alignment: .leading, spacing: 4) {
                SectionLabel(title: "Pinned collections", t: studio.t)
                ForEach(
                  Array(studio.sidebarConfiguration.pinnedCategories.enumerated()), id: \.element
                ) { index, category in
                  HStack(spacing: 10) {
                    StudioIcon(categoryIcon(category), size: 15).foregroundStyle(studio.t.secondary)
                    Text(Vocabulary.displayCategory(category)).font(.studio(.label)).lineLimit(1)
                      .help(category)
                    Spacer(minLength: 8)
                    moveControls(
                      category, index: index,
                      count: studio.sidebarConfiguration.pinnedCategories.count
                    ) {
                      studio.movePinnedCategory(category, by: $0)
                    }
                    IconButton(icon: "xmark", label: "Unpin \(category)", t: studio.t, size: 24) {
                      studio.pinSidebarCategory(category, pinned: false)
                    }
                  }.frame(height: 32)
                }
              }
            }
          } else {
            VStack(alignment: .leading, spacing: 8) {
              SectionLabel(title: "World categories", t: studio.t)
              SearchField(text: $query, placeholder: "Find a category", t: studio.t)
              Text("Hide categories from World, or pin them for quick access in Favorites.")
                .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              ForEach(
                studio.sidebarCategories.filter {
                  query.isEmpty || $0.localizedStandardContains(query)
                }, id: \.self
              ) { category in
                categoryRow(category)
              }
              if !query.isEmpty
                && !studio.sidebarCategories.contains(where: {
                  $0.localizedStandardContains(query)
                })
              {
                Text("No matching categories").font(.studio(.label))
                  .foregroundStyle(studio.t.secondary).padding(.vertical, 12)
              }
            }
          }
        }.padding(.trailing, 4)
      }.frame(height: page == .favorites && !studio.hasSidebarFavorites ? 110 : 340)
        .disabled(studio.sidebarConfigurationError != nil)
        .onChange(of: studio.captureNonce, initial: true) {
          guard !studio.captureHint.isEmpty else { return }
          page =
            studio.captureHint.contains("navigation-categories")
            ? .categories
            : studio.captureHint.contains("favorites-options")
              || studio.captureHint.contains("favorites-empty") ? .favorites : .arrangement
        }
    } footer: {
      Button("Restore defaults") { studio.restoreSidebarDefaults() }.buttonStyle(
        QuietButton(t: studio.t, role: .ghost))
      Spacer()
      Button("Done") { studio.sheet = nil }.buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
  }
  private var favoriteRecords: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionLabel(title: "Favorite records", t: studio.t)
      if studio.favoriteRecords.isEmpty {
        Text(
          "Pin a character, place or document from its editor or Library menu. Favorites stay here when you close a document."
        )
        .font(.studio(.label)).foregroundStyle(studio.t.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      ForEach(Array(studio.favoriteRecords.enumerated()), id: \.element.id) { index, record in
        HStack(spacing: 10) {
          StudioIcon(recordIcon(record), size: 15).foregroundStyle(studio.t.secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text(record.title).font(.studio(.label)).lineLimit(1)
            Text(favoriteRecordDetail(record))
              .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(1)
          }.help(record.title)
          Spacer(minLength: 8)
          moveControls(record.title, index: index, count: studio.favoriteRecords.count) {
            studio.moveFavorite(record, by: $0)
          }
          IconButton(
            icon: "xmark", label: "Remove \(record.title) from favorites", t: studio.t, size: 24
          ) {
            studio.setFavorite(record, enabled: false)
          }
        }.frame(height: 44)
      }
    }
  }
  private func categoryRow(_ category: String) -> some View {
    let pinned = studio.sidebarConfiguration.isPinned(category)
    return HStack(spacing: 12) {
      StudioIcon(categoryIcon(category), size: 16).foregroundStyle(studio.t.secondary)
      Text(Vocabulary.displayCategory(category)).font(.studio(.label)).lineLimit(1).help(category)
      Spacer(minLength: 8)
      Button(pinned ? "Pinned" : "Pin") { studio.pinSidebarCategory(category, pinned: !pinned) }
        .buttonStyle(QuietButton(t: studio.t)).frame(width: 62)
        .accessibilityLabel("\(pinned ? "Unpin" : "Pin") \(category)")
      Toggle(
        "Show \(category) in World",
        isOn: Binding(
          get: { !studio.sidebarConfiguration.isHidden(category) },
          set: { studio.setSidebarCategory(category, visible: $0) })
      )
      .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(studio.t.accent)
    }.frame(height: 38)
  }
  private func moveControls(_ name: String, index: Int, count: Int, move: @escaping (Int) -> Void)
    -> some View
  {
    HStack(spacing: 2) {
      IconButton(icon: "chevron.down", label: "Move \(name) up", t: studio.t, size: 24) { move(-1) }
        .rotationEffect(.degrees(180)).disabled(index == 0)
      IconButton(icon: "chevron.down", label: "Move \(name) down", t: studio.t, size: 24) {
        move(1)
      }
      .disabled(index == count - 1)
    }
  }
}
