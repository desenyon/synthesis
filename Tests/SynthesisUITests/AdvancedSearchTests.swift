import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct AdvancedSearchTests {
  @Test func structuredQueriesNeverFallBackToNamesCommandsOrCapture() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let matching = try store.createRecord(
      worldID: studio.worldID, title: "Mira", kind: "entity", category: "Characters")
    // A title that looks exactly like syntax must not bypass its filters.
    _ = try store.createRecord(
      worldID: studio.worldID, title: "type:character status:canon", kind: "lore")
    try studio.reload()
    let query = "type:character"
    let indexed = try store.search(worldID: studio.worldID, query: query)
    let results = CommandPalette.results(studio: studio, query: query, indexed: indexed)
    #expect(!results.isEmpty && results.allSatisfy { $0.id.hasPrefix("record-") })
    try #require(results.first { $0.id == "record-\(matching.id)" }).run()
    #expect(studio.selectedRecord?.id == matching.id && studio.mode == .manual && !studio.busy)
    #expect(
      CommandPalette.results(studio: studio, query: "type:character status:canon", indexed: [])
        .isEmpty)
    #expect(
      CommandPalette.results(studio: studio, query: "type:character status:typo", indexed: [])
        .isEmpty)
  }

  @Test func searchExamplesParseAndWorldSwitchClearsLibraryScope() throws {
    for example in SearchSyntaxMenu.examples {
      #expect(try LoreSearchQuery.parse(example.query).hasFilters)
    }
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.libraryQuery = "type:character faction:Tidekeepers"
    let next = try store.createWorld(name: "Next")
    studio.switchWorld(next.id)
    #expect(studio.libraryQuery.isEmpty)
  }
}
