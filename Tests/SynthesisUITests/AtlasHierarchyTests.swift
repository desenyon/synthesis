import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct AtlasHierarchyTests {
  @Test func openingMappedPlaceVisitsOnlyItsActiveChildAndBackRestoresParent() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let world = studio.worldID
    let city = try studio.store.createRecord(worldID: world, title: "Harbour", kind: "entity")
    let root = try studio.store.createAtlasMap(worldID: world, name: "Coast")
    let child = try studio.store.createAtlasMap(
      worldID: world, name: "Harbour district", placeID: city.id, parentMapID: root.id)
    _ = try studio.store.createAtlasMap(
      worldID: world, name: "Unrelated map of Harbour", placeID: city.id)
    let retired = try studio.store.createAtlasMap(
      worldID: world, name: "Retired Harbour map", placeID: city.id, parentMapID: root.id)
    try studio.store.archiveAtlasMap(worldID: world, id: retired.id)
    try studio.reload()
    studio.setMode(.manual)
    studio.openBoard(root.id, kind: "atlas")
    studio.atlasView.value.zoom = 2.5

    studio.openAtlasPlace(city, parentID: root.id)
    #expect(studio.mapBoardID == child.id && studio.selectedRecord == nil)
    #expect(studio.atlasView.value.zoom == 1)

    studio.goBack()
    #expect(studio.mapBoardID == root.id && studio.selectedRecord == nil)
    #expect(studio.atlasView.value.zoom == 2.5)
    #expect(try studio.store.record(worldID: world, id: city.id) == city)
    #expect(!studio.busy && studio.mode == .manual)
  }

  @Test func multipleChildMapsKeepLoreOpeningAndRequireAnExplicitMapChoice() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let world = studio.worldID
    let city = try studio.store.createRecord(worldID: world, title: "Harbour", kind: "entity")
    let root = try studio.store.createAtlasMap(worldID: world, name: "Coast")
    let canal = try studio.store.createAtlasMap(
      worldID: world, name: "Canals", placeID: city.id, parentMapID: root.id)
    let streets = try studio.store.createAtlasMap(
      worldID: world, name: "Streets", placeID: city.id, parentMapID: root.id)
    try studio.reload()
    studio.openBoard(root.id, kind: "atlas")
    let children = AtlasLocalMaps(
      parentID: root.id, maps: try studio.store.boards(worldID: world, kind: "atlas"))
    #expect(children.byPlace[city.id]?.map(\.id) == [canal.id, streets.id])

    studio.openAtlasPlace(city, parentID: root.id)
    #expect(studio.mapBoardID == root.id && studio.selectedRecord?.id == city.id)
    studio.goBack()

    studio.editorSave = { false }
    studio.openAtlasChild(streets.id, parentID: root.id)
    #expect(studio.mapBoardID == root.id)
    studio.editorSave = nil

    try studio.store.archiveAtlasMap(worldID: world, id: streets.id)
    studio.openAtlasChild(streets.id, parentID: root.id)
    #expect(studio.mapBoardID == root.id)
    studio.openAtlasChild(canal.id, parentID: root.id)
    #expect(studio.mapBoardID == canal.id)
  }
}
