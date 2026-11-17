import Foundation
import Testing

@testable import SynthesisCore

struct LoreSearchTests {
  @Test func placeCategorySearchMatchesTitlesAndBodiesWithEveryAlias() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let sea = try store.createRecord(
      worldID: world.id, title: "The Glass Sea", kind: "entity", category: "Places")
    let city = try store.createRecord(
      worldID: world.id, title: "The Drowned City", body: "A capital beneath the sea.",
      kind: "entity", category: "Places")
    for category in ["Places", "place", "location", "locations"] {
      #expect(
        Set(
          try store.search(worldID: world.id, query: "sea", scope: .init(category: category)).map(
            \.id))
          == [sea.id, city.id])
    }
  }

  @Test func libraryScopeIsAppliedBeforeTheResultLimit() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    var entity = try store.createRecord(
      worldID: world.id, title: "Harbour", kind: "entity", category: "Characters")
    entity = try store.promote(
      worldID: world.id, id: entity.id, version: entity.version, confirmation: entity.id)
    entity = try store.saveRecord(
      worldID: world.id, id: entity.id, version: entity.version, title: entity.title, body: "",
      rtf: nil)
    let section = try store.createRecordSection(
      worldID: world.id, parentID: entity.id, title: "Harbour")
    for _ in 0..<60 { _ = try store.createRecord(worldID: world.id, title: "Harbour") }
    #expect(try store.search(worldID: world.id, query: "Harbour").count == 50)
    #expect(
      try store.search(worldID: world.id, query: "Harbour", scope: .init(kind: "entity")).map(\.id)
        == [entity.id])
    #expect(
      Set(
        try store.search(worldID: world.id, query: "Harbour", scope: .init(category: "character"))
          .map(\.id)) == [entity.id, section.record.id])
    #expect(
      try store.search(worldID: world.id, query: "Harbour", scope: .init(hasCanon: true)).map(\.id)
        == [entity.id])
    #expect(
      try store.search(worldID: world.id, query: "Harbour", scope: .init(sectionsOnly: true)).map(
        \.id) == [section.record.id])
    #expect(
      try store.search(
        worldID: world.id, query: "Harbour status:canon", scope: .init(hasCanon: true)
      ).isEmpty)
  }

  @Test func typedRelationshipsUseRealDataInEitherDirection() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let faction = try store.createRecord(
      worldID: world.id, title: "Tidekeepers", kind: "entity", category: "Factions")
    let mira = try store.createRecord(
      worldID: world.id, title: "Mira Vale", body: "A cartographer.", kind: "entity",
      category: "Characters")
    let oren = try store.createRecord(
      worldID: world.id, title: "Oren Ashe", kind: "entity", category: "character")
    _ = try store.createRecord(
      worldID: world.id, title: "Unlinked", body: "Mentions Tidekeepers in prose.", kind: "entity",
      category: "Characters")
    _ = try store.addRelation(
      worldID: world.id, source: mira.id, target: faction.id, label: "guided by")
    let reverse = try store.addRelation(
      worldID: world.id, source: faction.id, target: oren.id, label: "employs")
    _ = try store.saveMetadata(
      worldID: world.id, id: faction.id, version: faction.version, tags: [],
      aliases: ["Gardiens de la Marée"])
    #expect(
      Set(
        try store.search(worldID: world.id, query: "type:character faction:Tidekeepers").map(\.id))
        == [mira.id, oren.id])
    #expect(
      try store.search(worldID: world.id, query: "Mira type:character faction:Tidekeepers").map(
        \.id) == [mira.id])
    #expect(
      try store.search(worldID: world.id, query: "type:character faction:\"gardiens de la maree\"")
        .count == 2)
    #expect(
      try store.search(worldID: world.id, query: "related:\"Mira Vale\"").map(\.id) == [faction.id])
    try store.archiveRelation(worldID: world.id, id: reverse.id)
    #expect(
      try store.search(worldID: world.id, query: "faction:Tidekeepers").map(\.id) == [mira.id])
    try store.archiveRecord(worldID: world.id, id: faction.id)
    #expect(try store.search(worldID: world.id, query: "faction:Tidekeepers").isEmpty)
  }

  @Test func statusAndDatesApplyTogetherWithoutChangingCanon() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    var recent = try store.createRecord(worldID: world.id, title: "Recent rule")
    var old = try store.createRecord(worldID: world.id, title: "Old rule")
    recent = try store.promote(
      worldID: world.id, id: recent.id, version: recent.version, confirmation: recent.id)
    old = try store.promote(
      worldID: world.id, id: old.id, version: old.version, confirmation: old.id)
    let now = try #require(ISO8601DateFormatter().date(from: "2026-11-17T12:00:00Z"))
    try store.db.execute(
      "UPDATE records SET updated_at=?,created_at=? WHERE id=?",
      ["2026-11-10T12:00:00Z", "2026-11-01T00:00:00Z", recent.id])
    try store.db.execute(
      "UPDATE records SET updated_at=? WHERE id=?", ["2026-11-10T11:59:59Z", old.id])
    #expect(
      try store.search(worldID: world.id, query: "status:canon updated:7d", now: now).map(\.id) == [
        recent.id
      ])
    #expect(
      try store.search(
        worldID: world.id, query: "status:canon created:2026-11-01 updated:1w", now: now
      ).map(\.id) == [recent.id])
    #expect(
      try store.search(worldID: world.id, query: "status:canon updated:24h", now: now).isEmpty)
    let changed = try store.saveRecord(
      worldID: world.id, id: recent.id, version: recent.version, title: recent.title,
      body: "New draft", rtf: nil)
    #expect(changed.canonical != nil && changed.state == "draft")
    #expect(
      !((try store.search(worldID: world.id, query: "status:canon")).contains {
        $0.id == changed.id
      }))
    #expect(try store.search(worldID: world.id, query: "status:draft").map(\.id) == [changed.id])
  }

  @Test func filtersRemainWorldScopedArchivedAndInjectionSafe() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Other")
    var local = try store.createRecord(
      worldID: world.id, title: "Éloise", body: "A luminous sea", kind: "entity",
      category: "Characters")
    _ = try store.createRecord(
      worldID: other.id, title: "Éloise", kind: "entity", category: "Characters")
    local = try store.saveMetadata(
      worldID: world.id, id: local.id, version: local.version, tags: ["Story arc", "Secret"],
      aliases: ["La Gardienne"])
    #expect(
      try store.search(
        worldID: world.id,
        query: "type:character tag:\"story arc\" tag:secret alias:\"la gardienne\""
      ).map(\.id) == [local.id])
    #expect(
      try store.search(worldID: world.id, query: "\"luminous sea\" type:entity").map(\.id) == [
        local.id
      ])
    #expect(
      try store.search(worldID: world.id, query: "Eloise type:character").map(\.id) == [local.id])
    #expect(try store.search(worldID: world.id, query: "tag:\"' OR 1=1 --\"").isEmpty)
    #expect(throws: Error.self) { try store.search(worldID: "missing", query: "type:entity") }
    try store.archiveRecord(worldID: world.id, id: local.id)
    #expect(try store.search(worldID: world.id, query: "type:character").isEmpty)
    #expect(
      try store.search(worldID: world.id, query: "type:character tag:secret", archived: true).map(
        \.id) == [local.id])
    #expect(try store.records(worldID: other.id).count == 1)
  }

  @Test func queryValidationDoesNotSilentlyIgnoreBrokenFilters() throws {
    for query in [
      "status:", "status:approved", "updated:0d", "updated:forever", "updated:2026-02-30",
      "faction:\"Unfinished", "tag:\"\"",
    ] {
      #expect(throws: Error.self) { try LoreSearchQuery.parse(query) }
      #expect(LoreSearchQuery.usesFilters(query))
    }
    let parsed = try LoreSearchQuery.parse(
      "  type:character faction:\"The Sea \\\"Guard\\\"\" Mira  ")
    #expect(parsed.terms == ["Mira"])
    #expect(parsed.filters.last?.value == "The Sea \"Guard\"")
    #expect(
      try LoreSearchQuery.parse("Mira's return unknown:value").terms == [
        "Mira's", "return", "unknown:value",
      ])
    #expect(!LoreSearchQuery.usesFilters("\"type:character\""))
  }

  @Test func advancedSearchRemainsBoundedAtScale() throws {
    let (store, worldID) = try ScaleTests.largeWorld()
    let start = ContinuousClock.now
    for _ in 0..<20 {
      let results = try store.search(
        worldID: worldID, query: "type:character status:draft updated:7d")
      #expect(results.count == 50 && results.allSatisfy { $0.category == "Characters" })
    }
    let elapsed = start.duration(to: .now)
    print("Advanced search (2,000 records, 20 filtered queries): \(elapsed)")
    #expect(elapsed < .seconds(2))
  }
}
