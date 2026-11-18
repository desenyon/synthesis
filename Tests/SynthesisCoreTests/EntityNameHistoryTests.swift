import Foundation
import Testing

@testable import SynthesisCore

struct EntityNameHistoryTests {
  @Test func temporalEditsAndUndoRetainTheEntityIdentityAndAcceptedCanon() throws {
    let (store, world, entity) = try Self.fixture()
    let accepted = try store.promote(
      worldID: world.id, id: entity.id, version: entity.version, confirmation: entity.id)
    let period = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id,
      draft: .init(name: "Old Tidekeepers", endLabel: "After the revolution"))
    #expect(period.kind == .name && period.startLabel.isEmpty)
    var revised = period.draft
    revised.startLabel = "The first spring"
    let updated = try store.updateEntityNamePeriod(
      worldID: world.id, expected: period, draft: revised)
    #expect(updated.id == period.id && updated.recordID == entity.id)
    #expect(updated.revision == period.revision + 1)
    #expect(throws: SynthesisError.self) {
      try store.updateEntityNamePeriod(worldID: world.id, expected: period, draft: period.draft)
    }

    let archived = try store.archiveEntityNamePeriod(worldID: world.id, expected: updated)
    #expect(archived.archived)
    #expect(try store.entityNamePeriods(worldID: world.id, recordID: entity.id).isEmpty)
    #expect(
      try store.entityNamePeriods(worldID: world.id, recordID: entity.id, archived: true)
        == [archived])
    let restored = try store.restoreEntityNamePeriod(
      worldID: world.id, recordID: entity.id, id: period.id, expectedRevision: archived.revision)
    #expect(restored.draft == revised && !restored.archived)
    let rearchived = try store.archiveEntityNamePeriod(worldID: world.id, expected: restored)
    #expect(throws: SynthesisError.self) {
      try store.restoreEntityNamePeriod(
        worldID: world.id, recordID: entity.id, id: period.id, expectedRevision: archived.revision)
    }
    #expect(
      try store.entityNamePeriods(worldID: world.id, recordID: entity.id, archived: true)
        == [rearchived])
    #expect(try store.record(worldID: world.id, id: entity.id) == accepted)

    let history = try store.db.rows(
      "SELECT * FROM entity_name_period_history WHERE world_id=? AND period_id=? ORDER BY revision",
      [world.id, period.id])
    #expect(history.map { $0["revision"] } == ["1", "2", "3", "4"])
    #expect(history.first?["start_label"] == "")
    #expect(history.last?["start_label"] == "The first spring")
  }

  @Test func localSearchFindsHistoricalNamesAndAliasesOnlyInTheirOwnWorld() throws {
    let (store, world, entity) = try Self.fixture()
    let other = try store.createWorld(name: "Other world")
    let otherEntity = try store.createRecord(worldID: other.id, title: "Unrelated", kind: "entity")
    try store.createEntityNamePeriod(
      worldID: other.id, recordID: otherEntity.id, draft: .init(name: "Café Guild"))
    let alias = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id, draft: .init(kind: .alias, name: "Café Guild"))
    let name = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id, draft: .init(name: "Café Guild"))

    #expect(try store.search(worldID: world.id, query: "Cafe Guil").map(\.id) == [entity.id])
    #expect(
      try store.search(worldID: world.id, query: #"alias:"CAFE GUILD""#).map(\.id) == [entity.id])
    #expect(try store.search(worldID: other.id, query: "Café Guild").map(\.id) == [otherEntity.id])
    #expect(try store.search(worldID: world.id, query: "Cafe", scope: .init(kind: "lore")).isEmpty)
    let context = try store.assistantContext(worldID: world.id, prompt: "Tell me about this world")
    #expect(!context.workspace.contains("Café Guild") && !context.lore.contains("Café Guild"))

    _ = try store.archiveEntityNamePeriod(worldID: world.id, expected: alias)
    #expect(try store.search(worldID: world.id, query: #"alias:"Cafe Guild""#).isEmpty)
    #expect(try store.search(worldID: world.id, query: "Cafe Guild").map(\.id) == [entity.id])
    var revised = name.draft
    revised.name = "River Concord"
    _ = try store.updateEntityNamePeriod(worldID: world.id, expected: name, draft: revised)
    #expect(try store.search(worldID: world.id, query: "Cafe Guild").isEmpty)
    #expect(try store.search(worldID: world.id, query: "River Concord").map(\.id) == [entity.id])
    try store.archiveRecord(worldID: world.id, id: entity.id)
    #expect(try store.search(worldID: world.id, query: "River Concord").isEmpty)
    #expect(
      try store.search(worldID: world.id, query: "River Concord", archived: true).map(\.id)
        == [entity.id])
  }

  @Test func explicitWorkingTitleChangeKeepsApprovedNameAndDraftBody() throws {
    let (store, world, entity) = try Self.fixture()
    let accepted = try store.promote(
      worldID: world.id, id: entity.id, version: entity.version, confirmation: entity.id)
    let period = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id,
      draft: .init(name: "The Concord", startLabel: "After the revolution"))
    #expect(
      try store.updateEntityWorkingTitle(
        worldID: world.id, expected: accepted, title: accepted.title) == accepted)
    let next = try store.updateEntityWorkingTitle(
      worldID: world.id, expected: accepted, title: period.name)
    #expect(next.id == accepted.id && next.body == accepted.body)
    #expect(next.title == period.name && next.state == "draft")
    #expect(next.canonical == accepted.canonical)
    #expect(try store.entityNamePeriods(worldID: world.id, recordID: entity.id) == [period])
    #expect(throws: SynthesisError.self) {
      try store.updateEntityWorkingTitle(worldID: world.id, expected: accepted, title: "Stale")
    }
    let undone = try store.updateEntityWorkingTitle(
      worldID: world.id, expected: next, title: accepted.title)
    #expect(undone.title == accepted.title && undone.canonical == accepted.canonical)
  }

  @Test func archivedAndForeignOwnersCannotBeUsedForPeriodMutations() throws {
    let (store, world, entity) = try Self.fixture()
    let other = try store.createWorld(name: "Other world")
    let document = try store.createRecord(worldID: world.id, title: "Ordinary document")
    let draft = EntityNamePeriodDraft(name: "Old title")
    #expect(throws: SynthesisError.self) {
      try store.createEntityNamePeriod(worldID: other.id, recordID: entity.id, draft: draft)
    }
    #expect(throws: SynthesisError.self) {
      try store.createEntityNamePeriod(worldID: world.id, recordID: document.id, draft: draft)
    }
    let period = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id, draft: draft)
    #expect(throws: SynthesisError.self) {
      try store.archiveEntityNamePeriod(worldID: other.id, expected: period)
    }
    try store.archiveRecord(worldID: world.id, id: entity.id)
    #expect(throws: SynthesisError.self) {
      try store.updateEntityNamePeriod(worldID: world.id, expected: period, draft: draft)
    }
    #expect(
      try store.entityNamePeriods(worldID: world.id, recordID: entity.id) == [period])
  }

  @Test func archiveRoundTripRemapsAddressesButPreservesAuthorLabelsAndAllRevisions() throws {
    let (store, world, entity) = try Self.fixture()
    let document = try store.createRecord(worldID: world.id, title: "Ordinary document")
    let first = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id,
      draft: .init(name: "First \(entity.id)", startLabel: "Period \(world.id)"))
    var draft = first.draft
    draft.name = "Known title \(world.id)"
    let revised = try store.updateEntityNamePeriod(worldID: world.id, expected: first, draft: draft)
    let second = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id, draft: .init(kind: .alias, name: "Archived alias"))
    _ = try store.archiveEntityNamePeriod(worldID: world.id, expected: second)
    let archive = try store.exportWorldArchive(worldID: world.id)
    let portable = try JSONDecoder().decode(WorldArchive.self, from: archive)
    #expect(portable.version == 15)
    let copy = try store.importWorldArchiveMapping(archive)
    let copyRecordID = try #require(copy.ids[entity.id])
    let names = try store.entityNamePeriods(worldID: copy.world.id, recordID: copyRecordID)
    let copied = try #require(names.first)
    #expect(copied.id != revised.id && copied.worldID == copy.world.id)
    #expect(copied.recordID == copyRecordID && copied.draft == draft)
    #expect(copied.revision == revised.revision)
    #expect(
      try store.entityNamePeriods(worldID: copy.world.id, recordID: copyRecordID, archived: true)
        .map(\.name) == ["Archived alias"])
    let previous = try store.db.rows(
      "SELECT name FROM entity_name_period_history WHERE world_id=? AND period_id=?",
      [copy.world.id, copied.id])
    #expect(previous.first?["name"] == first.name)
    #expect(
      try store.search(worldID: copy.world.id, query: "Known title").map(\.id) == [copyRecordID])

    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect(json["schemaVersion"] as? Int == 18)
    #expect((json["entityNamePeriods"] as? [[String: String]])?.count == 2)
    #expect((json["entityNamePeriodHistory"] as? [[String: String]])?.count == 2)
    let markdown = try store.exportRecordMarkdown(worldID: world.id, recordID: entity.id).content
    #expect(markdown.contains("Names through time") && markdown.contains(draft.name))
    #expect(!markdown.contains("Archived alias"))

    var legacy = portable
    legacy.version = 11
    legacy.tables.removeValue(forKey: "entity_name_periods")
    legacy.tables.removeValue(forKey: "entity_name_period_history")
    let older = try store.importWorldArchiveMapping(JSONEncoder().encode(legacy))
    let olderRecordID = try #require(older.ids[entity.id])
    #expect(try store.entityNamePeriods(worldID: older.world.id, recordID: olderRecordID).isEmpty)

    let count = try store.worlds().count
    for (table, field, value) in [
      ("entity_name_periods", "record_id", document.id),
      ("entity_name_periods", "name", String(repeating: " ", count: 3000) + "A"),
      ("entity_name_periods", "start_label", "A\0B"),
      ("entity_name_period_history", "revision", "999"),
    ] {
      var invalid = portable
      invalid.tables[table]?[0][field] = value
      #expect(throws: SynthesisError.self) {
        try store.importWorldArchive(JSONEncoder().encode(invalid))
      }
      #expect(try store.worlds().count == count)
    }
  }

  private static func fixture() throws -> (WorkspaceStore, World, LoreRecord) {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Name history")
    let entity = try store.createRecord(
      worldID: world.id, title: "Tidekeepers", body: "Guards the coast.", kind: "entity")
    return (store, world, entity)
  }
}
