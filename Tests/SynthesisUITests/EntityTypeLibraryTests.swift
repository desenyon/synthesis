import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct EntityTypeLibraryTests {
  @Test func stableCollectionRoutesFollowRenameAndDiscardAnArchivedType() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let type = try store.saveEntityType(worldID: world, name: "Navigator", fields: [])
    let entity = try store.createTypedEntity(worldID: world, typeID: type.id, title: "Mira Vale")
    try studio.reload()
    studio.openEntityTypeLens(type.id)
    let address = studio.navigationLocation
    #expect(studio.destination == .library)
    #expect(studio.activeLibraryEntityType?.recordIDs == [entity.id])
    studio.libraryQuery = "Mira"
    studio.navigate(.knowledge)
    #expect(studio.libraryEntityTypeID == nil)
    let renamed = try store.saveEntityType(
      worldID: world, id: type.id, expectedVersion: type.version, name: "Wayfinder", fields: [])
    try studio.reload()
    studio.goBack()
    #expect(studio.activeLibraryEntityType?.id == type.id)
    #expect(studio.activeLibraryEntityType?.name == renamed.name)
    #expect(studio.libraryQuery == "Mira")

    try store.setEntityTypeArchived(
      worldID: world, id: type.id, archived: true, expectedVersion: renamed.version)
    try studio.reload()
    #expect(studio.libraryEntityTypeID == nil)
    #expect(studio.restoreNavigation(address))
    #expect(studio.destination == .library && studio.activeLibraryEntityType == nil)
    #expect(studio.records.contains { $0.id == entity.id })
  }

  @Test func typedLibraryReopensFromItsExistingDeviceSession() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let type = try store.saveEntityType(worldID: world, name: "Navigator", fields: [])
    try studio.reload()
    studio.updatePreferences { $0.launchWorkspace = "remember" }
    studio.openEntityTypeLens(type.id)
    #expect(studio.persistWorkspaceSession(force: true))
    let reopened = try Studio(store: store)
    #expect(reopened.destination == .library)
    #expect(reopened.activeLibraryEntityType?.id == type.id)
    #expect(reopened.libraryCategory == nil)
  }

  @Test func libraryWithoutATypeRemainsDecodable() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.openLens("Places")
    let address = studio.navigationLocation
    let encoded = try JSONEncoder().encode(address)
    let decoded = try JSONDecoder().decode(NavigationLocation.self, from: encoded)
    #expect(decoded.category == "Places" && decoded.context?.libraryEntityTypeID == nil)
    #expect(studio.restoreNavigation(decoded))
    #expect(studio.libraryCategory == "Places" && studio.activeLibraryEntityType == nil)
  }
}
