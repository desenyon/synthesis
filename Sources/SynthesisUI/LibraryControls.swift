import SwiftUI

/// Local search remains available when the shared bar collapses to its compact form.
struct LibrarySearchControl: View {
  @ObservedObject var studio: Studio
  @Environment(\.barCompact) private var compact
  @State private var expanded = false
  var body: some View {
    if compact {
      IconButton(
        icon: "sliders-horizontal", label: "Search this library", t: studio.t,
        active: !studio.libraryQuery.isEmpty
      ) { expanded.toggle() }
      .popover(isPresented: $expanded) {
        HStack(spacing: Space.sm) {
          search.frame(width: 250)
          SearchSyntaxMenu(query: $studio.libraryQuery, t: studio.t)
        }.padding(12).background(studio.t.surface)
      }
    } else {
      search.frame(minWidth: 140, idealWidth: 240, maxWidth: 240)
      SearchSyntaxMenu(query: $studio.libraryQuery, t: studio.t)
    }
  }
  private var search: some View {
    SearchField(
      text: $studio.libraryQuery, placeholder: "Search lore or type:character", t: studio.t,
      autofocus: compact)
  }
}

struct LibraryEntityTypeMenu: View {
  @ObservedObject var studio: Studio
  var body: some View {
    PlainMenu {
      Button("Show all library records") { studio.openLens(nil) }
      ForEach(studio.entityTypeCollections) { type in
        Button {
          studio.openEntityTypeLens(type.id, keepSearch: true)
        } label: {
          if studio.libraryEntityTypeID == type.id {
            StudioLabel(type.name, icon: "checkmark")
          } else {
            Text(type.name)
          }
        }
      }
    } label: {
      StudioLabel("Type", icon: "circle.hexagongrid")
        .font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
        .padding(.horizontal, 8).frame(height: 26).hoverFill(studio.t)
    }
    .accessibilityLabel("Filter by entity type")
    .help("Filter by entity type")
  }
}

struct LibraryCategoryBack: View {
  @ObservedObject var studio: Studio
  @Environment(\.barCompact) private var compact
  var body: some View {
    if compact {
      IconButton(icon: "rectangle.grid.2x2", label: "Show all library categories", t: studio.t) {
        studio.openLens(nil)
      }
    } else {
      Button("Show all") { studio.openLens(nil) }.buttonStyle(.plain)
        .font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.accent)
        .padding(.leading, 4)
    }
  }
}
