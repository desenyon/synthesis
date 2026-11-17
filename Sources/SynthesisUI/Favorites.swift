import SwiftUI
import SynthesisCore

func favoriteRecordDetail(_ record: LoreRecord) -> String {
  let category = Vocabulary.displayCategory(record.category)
  let kind = Vocabulary.kindLabel(record.kind)
  return category.isEmpty ? kind : record.kind == "entity" ? category : "\(kind) · \(category)"
}

extension Studio {
  /// Resolve addresses from the current world, so renames update and archived records disappear.
  /// Keep unavailable IDs in preferences: restoring an archived record restores its favorite.
  var favoriteRecords: [LoreRecord] {
    let current = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    return sidebarConfiguration.favoriteRecordIDs.compactMap { current[$0] }
  }
  var hasSidebarFavorites: Bool {
    !favoriteRecords.isEmpty || !sidebarConfiguration.pinnedCategories.isEmpty
  }
  func isFavorite(_ id: String) -> Bool { sidebarConfiguration.favoriteRecordIDs.contains(id) }
  func setFavorite(_ record: LoreRecord, enabled: Bool) {
    guard record.worldID == worldID else { return }
    if enabled {
      guard (try? store.record(worldID: worldID, id: record.id)) != nil,
        (try? store.isArchived(worldID: worldID, recordID: record.id)) == false
      else {
        error = "This record is no longer available in this universe."
        return
      }
    }
    updateSidebarConfiguration { value in
      if enabled {
        if !value.favoriteRecordIDs.contains(record.id) {
          value.favoriteRecordIDs.append(record.id)
        }
      } else {
        value.favoriteRecordIDs.removeAll { $0 == record.id }
      }
    }
  }
  func moveFavorite(_ record: LoreRecord, by offset: Int) {
    guard record.worldID == worldID else { return }
    let available = Set(records.map(\.id))
    updateSidebarConfiguration { value in
      let visible = value.favoriteRecordIDs.filter { available.contains($0) }
      guard let index = visible.firstIndex(of: record.id), visible.indices.contains(index + offset),
        let from = value.favoriteRecordIDs.firstIndex(of: record.id),
        let to = value.favoriteRecordIDs.firstIndex(of: visible[index + offset])
      else { return }
      value.favoriteRecordIDs.swapAt(from, to)
    }
  }
}

/// The same action in Library, document tabs, the editor and record inspection.
struct RecordFavoriteAction: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var body: some View {
    Button(studio.isFavorite(record.id) ? "Remove from favorites" : "Add to favorites") {
      studio.setFavorite(record, enabled: !studio.isFavorite(record.id))
    }
  }
}

struct RecordFavoriteButton: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var body: some View {
    let favorite = studio.isFavorite(record.id)
    IconButton(
      icon: "pin", label: favorite ? "Remove from favorites" : "Add to favorites",
      t: studio.t, active: favorite
    ) { studio.setFavorite(record, enabled: !favorite) }
    .accessibilityValue(favorite ? "Favorite" : "Not a favorite")
    .help(
      "\(favorite ? "Remove" : "Pin") \(record.title) \(favorite ? "from" : "in") sidebar Favorites"
    )
  }
}
