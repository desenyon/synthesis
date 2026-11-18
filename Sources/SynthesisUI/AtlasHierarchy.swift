import SynthesisCore

/// Direct child maps use the place's stable record ID, independent of a map or record rename.
struct AtlasLocalMaps {
  private(set) var all: [Board] = []
  private(set) var byPlace: [String: [Board]] = [:]

  init(parentID: String? = nil, maps: [Board] = []) {
    guard let parentID, maps.contains(where: { $0.id == parentID }) else { return }
    for map in maps where map.id != parentID {
      guard let links = try? AtlasLinks(content: map.content), links.parentMapID == parentID
      else { continue }
      all.append(map)
      if let placeID = links.placeID { byPlace[placeID, default: []].append(map) }
    }
  }
}

extension Studio {
  func openAtlasPlace(_ record: LoreRecord, parentID: String) {
    guard destination == .atlas, selectedRecord == nil, mapBoardID == parentID,
      record.worldID == worldID
    else { return }
    perform {
      let current = try store.record(worldID: worldID, id: record.id)
      guard try !store.isArchived(worldID: worldID, recordID: current.id)
      else { throw SynthesisError.notFound }
      let children = try currentAtlasChildren(parentID: parentID).byPlace[current.id] ?? []
      if children.count == 1, let child = children.first {
        openBoard(child.id, kind: "atlas")
      } else {
        openRecord(current)
      }
    }
  }

  func openAtlasChild(_ id: String, parentID: String, placeID: String? = nil) {
    guard destination == .atlas, selectedRecord == nil, mapBoardID == parentID else { return }
    perform {
      let current = try currentAtlasChildren(parentID: parentID)
      let children = placeID.map { current.byPlace[$0] ?? [] } ?? current.all
      guard children.contains(where: { $0.id == id }) else { throw SynthesisError.notFound }
      openBoard(id, kind: "atlas")
    }
  }

  private func currentAtlasChildren(parentID: String) throws -> AtlasLocalMaps {
    AtlasLocalMaps(parentID: parentID, maps: try store.boards(worldID: worldID, kind: "atlas"))
  }
}
