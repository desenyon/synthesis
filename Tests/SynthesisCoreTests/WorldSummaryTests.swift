import Testing

@testable import SynthesisCore

struct WorldSummaryTests {
  @Test func summariesAreScopedAndReflectArchiveAndDescription() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let first = try store.createWorld(name: "First")
    let other = try store.createWorld(name: "Other")
    let page = try store.createRecord(worldID: first.id, title: "Page")
    _ = try store.createConversation(worldID: first.id)
    let summaries = try store.worldSummaries()
    #expect(summaries[first.id]?.records == 1 && summaries[first.id]?.conversations == 1)
    #expect(summaries[other.id]?.records == 0 && summaries[other.id]?.conversations == 0)
    #expect(try #require(summaries[first.id]).updatedAt >= page.updatedAt)
    try store.archiveRecord(worldID: first.id, id: page.id)
    #expect(try store.worldSummaries()[first.id]?.records == 0)
    try store.setWorldDescription(worldID: first.id, description: "  A sea of memory.  ")
    #expect(try store.world(first.id).description == "A sea of memory.")
    #expect(try store.world(other.id).description.isEmpty)
  }
}
