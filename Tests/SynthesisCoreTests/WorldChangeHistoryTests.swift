import Foundation
import Testing

@testable import SynthesisCore

struct WorldChangeHistoryTests {
  @Test func boardNavigationAndSerializationDoNotCrowdOutCreativeEdits() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Board history")
    let original =
      #"{"format":"excalidraw","scene":{"elements":[{"id":"a","x":10,"version":1}],"appState":{"zoom":1}}}"#
    let board = try store.saveBoard(
      worldID: world.id, name: "Research", kind: "canvas", content: original)
    let viewport =
      #"{"scene":{"appState":{"zoom":2,"scrollX":90},"elements":[{"version":2,"versionNonce":42,"updated":100,"x":10,"id":"a"}]},"format":"excalidraw"}"#
    _ = try store.saveBoard(
      worldID: world.id, id: board.id, name: board.name, kind: "canvas", content: viewport)
    #expect(try store.worldChangeHistory(worldID: world.id, kind: .board).count == 1)
    #expect(try store.boards(worldID: world.id, kind: "canvas").first?.content == viewport)
    _ = try store.saveBoard(
      worldID: world.id, id: board.id, name: board.name, kind: "canvas",
      content: viewport.replacingOccurrences(of: #""x":10"#, with: #""x":20"#))
    #expect(try store.worldChangeHistory(worldID: world.id, kind: .board).count == 2)
    #expect(
      !BoardActivity.changed(
        #"{"cards":[],"edges":[],"viewport":{"zoom":1}}"#,
        #"{"viewport":{"zoom":2},"edges":[],"cards":[]}"#))
    #expect(BoardActivity.changed("unreadable", "different"))
    #expect(BoardActivity.changed(#"{"markers":[]}"#, #"{"markers":[{"x":0.2}]}"#))
  }

  @Test func committedEditsApprovalsAndArchivesRetainTheirOwnHistory() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Private world")
    _ = try store.createRecord(worldID: other.id, title: "Not shared")
    let first = try store.createRecord(worldID: world.id, title: "The sea", body: "Original")
    let second = try store.saveRecord(
      worldID: world.id, id: first.id, version: first.version, title: "Glass Sea", body: "Revised",
      rtf: nil)
    let canon = try store.promote(
      worldID: world.id, id: first.id, version: second.version, confirmation: first.id)
    let before = try store.worldChangeHistory(worldID: world.id)
    #expect(
      before.filter { $0.objectID == first.id }.map(\.action) == [.approved, .updated, .created])
    #expect(
      before.first(where: { $0.action == .created && $0.kind == .record })?.title == "The sea")
    #expect(before.first?.revision == canon.version)
    #expect(before.allSatisfy { $0.worldID == world.id && $0.sourceAvailable && !$0.reconstructed })
    #expect(try store.worldChangeHistory(worldID: world.id, action: .approved).count == 1)
    #expect(try store.worldChangeHistory(worldID: world.id, query: "previously The sea").count == 1)
    try store.archiveRecord(worldID: world.id, id: first.id)
    try store.archiveRecord(worldID: world.id, id: first.id)
    let archived = try store.worldChangeHistory(worldID: world.id, kind: .record)
    #expect(archived.count == 4 && archived.first?.action == .archived)
    #expect(archived.allSatisfy { !$0.sourceAvailable })
    try store.restoreRecord(worldID: world.id, id: first.id)
    let restored = try store.worldChangeHistory(worldID: world.id, kind: .record)
    #expect(restored.count == 5 && restored.first?.action == .restored)
    #expect(restored.allSatisfy { $0.sourceAvailable })
    #expect(try store.record(worldID: world.id, id: first.id).canonical == canon.canonical)
    #expect(try store.worldChangeHistory(worldID: world.id, limit: 0).isEmpty)
    #expect(throws: SynthesisError.self) { try store.worldChangeHistory(worldID: "missing") }
  }

  @Test func connectedChangesAreLoggedWithoutProviderOrPreferenceNoise() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "World")
    let person = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let place = try store.createRecord(worldID: world.id, title: "Sea", kind: "entity")
    let relation = try store.addRelation(
      worldID: world.id, source: person.id, target: place.id, label: "crosses")
    try store.updateRelation(worldID: world.id, id: relation.id, label: "maps")
    let period = try store.createChronologyLane(worldID: world.id, name: "Ice age", kind: "period")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "First crossing", date: "Year 60", source: person.id,
      order: 60, laneID: period.id)
    let board = try store.createAtlasMap(worldID: world.id, name: "Coast", placeID: place.id)
    _ = try store.saveBoard(
      worldID: world.id, id: board.id, name: "Frozen coast", kind: "atlas", content: board.content)
    _ = try store.saveRule(
      worldID: world.id, systemID: person.id, existing: nil, kind: .limit, title: "Memory cost",
      body: "Lose a memory", requires: [])
    _ = try store.saveScenario(
      worldID: world.id, systemID: person.id, title: "Crossing test", situation: "Frozen sea",
      expectation: "unclear")
    let section = try store.createRecordSection(
      worldID: world.id, parentID: person.id, title: "History")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "New idea", "changes": [["action": "create_record", "title": "A harbour"]],
        ]))
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
      confirmation: proposal.id)
    let chat = try store.createConversation(worldID: world.id, title: "Brainstorm")
    let baseline = try store.worldChangeHistory(worldID: world.id, limit: 100)
    #expect(
      baseline.contains {
        $0.kind == .relationship && $0.action == .linked && $0.detail.contains("crosses")
      })
    #expect(baseline.contains { $0.objectID == relation.id && $0.detail.contains("maps") })
    #expect(baseline.contains { $0.objectID == event.id && $0.action == .moved })
    #expect(
      baseline.contains {
        $0.objectID == board.id && $0.boardKind == "atlas" && $0.title == "Coast"
      })
    #expect(baseline.contains { $0.objectID == person.id && $0.title == "Memory cost" })
    #expect(baseline.contains { $0.objectID == person.id && $0.title == section.record.title })
    #expect(baseline.contains { $0.kind == .proposal && $0.action == .approved })
    #expect(baseline.contains { $0.objectID == chat.id })
    try store.setPreference("provider", value: "Private provider configuration")
    try store.setPreference("navigation:\(world.id)", value: "Private arrangement")
    _ = try store.appendMessage(
      worldID: world.id, conversationID: chat.id, role: "user", body: "Private conversation text",
      state: "complete")
    #expect(try store.worldChangeHistory(worldID: world.id, limit: 100) == baseline)
    try store.updateWorldDetails(
      worldID: world.id, name: "Renamed world", description: "A universe")
    #expect(try store.worldChangeHistory(worldID: world.id).first?.kind == .world)
  }

  @Test func failedTransactionsAndStaleSavesDoNotLeaveActivity() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "World")
    let record = try store.createRecord(worldID: world.id, title: "Before")
    let history = try store.worldChangeHistory(worldID: world.id)
    #expect(throws: SynthesisError.self) {
      try store.db.transaction {
        _ = try store.saveRecord(
          worldID: world.id, id: record.id, version: record.version, title: "Rolled back", body: "",
          rtf: nil)
        throw SynthesisError.stale
      }
    }
    #expect(try store.worldChangeHistory(worldID: world.id) == history)
    #expect(try store.record(worldID: world.id, id: record.id) == record)
    #expect(throws: SynthesisError.self) {
      try store.saveRecord(
        worldID: world.id, id: record.id, version: 99, title: "Rejected", body: "", rtf: nil)
    }
    #expect(try store.worldChangeHistory(worldID: world.id) == history)
  }

  @Test func paginationRemainsStableWhileNewChangesArriveAndSearchEscapesWildcards() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "World")
    for index in 0..<65 { _ = try store.createRecord(worldID: world.id, title: "Journey \(index)") }
    let initial = try store.worldChangeHistory(worldID: world.id, kind: .record, limit: 100)
    let first = try store.worldChangeHistory(worldID: world.id, kind: .record, limit: 30)
    _ = try store.createRecord(worldID: world.id, title: "Newest")
    let second = try store.worldChangeHistory(
      worldID: world.id, kind: .record, before: first.last?.cursor, limit: 100)
    #expect((first + second).map(\.id) == initial.map(\.id))
    #expect(Set((first + second).map(\.id)).count == 65)
    let literal = try store.createRecord(worldID: world.id, title: "100%_certain")
    #expect(
      try store.worldChangeHistory(worldID: world.id, query: "%_").map(\.objectID) == [literal.id])
    #expect(throws: SynthesisError.self) {
      try store.worldChangeHistory(worldID: world.id, query: String(repeating: "x", count: 513))
    }
  }

  @Test func archivesPreserveHistoryWithNewReferencesAndRejectMixedTargetsAtomically() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "World")
    let record = try store.createRecord(worldID: world.id, title: "Mira")
    _ = try store.saveRecord(
      worldID: world.id, id: record.id, version: record.version, title: "Mira Vale", body: "",
      rtf: nil)
    try store.archiveRecord(worldID: world.id, id: record.id)
    let history = try store.worldChangeHistory(worldID: world.id)
    let archive = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchive(archive)
    let imported = try store.worldChangeHistory(worldID: copy.id)
    #expect(imported.count == history.count + 1)
    #expect(imported.first?.detail == "World imported")
    #expect(Set(imported.map(\.id)).isDisjoint(with: Set(history.map(\.id))))
    #expect(
      imported.allSatisfy {
        $0.worldID == copy.id && $0.objectID != record.id && $0.objectID != world.id
      })
    #expect(imported.filter { $0.kind == .record }.allSatisfy { !$0.sourceAvailable })
    #expect(try store.db.rows("SELECT * FROM activity_imports").isEmpty)
    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect((json["activityHistory"] as? [[String: String]])?.count == history.count)
    var tampered = try JSONDecoder().decode(WorldArchive.self, from: archive)
    let index = try #require(
      tampered.tables["world_activity"]?.firstIndex { $0["kind"] == "record" })
    tampered.tables["world_activity"]?[index]["object_id"] = world.id
    let count = try store.worlds().count
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(tampered))
    }
    #expect(
      try store.worlds().count == count && store.db.rows("SELECT * FROM activity_imports").isEmpty)
    #expect(try store.worldChangeHistory(worldID: world.id) == history)
    var old = try JSONDecoder().decode(WorldArchive.self, from: archive)
    old.version = 8
    old.tables.removeValue(forKey: "world_activity")
    let legacy = try store.importWorldArchive(JSONEncoder().encode(old))
    let recovered = try store.worldChangeHistory(worldID: legacy.id)
    #expect(
      recovered.filter { $0.kind == .record && $0.reconstructed }.map(\.revision).compactMap { $0 }
        .sorted() == [1, 2])
  }

  @Test func additiveMigrationReconstructsExistingRevisionsOnceWithoutChangingLore() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("world.sqlite").path
    let ids: (String, String) = try {
      let old = try WorkspaceStore(path: path)
      let world = try old.createWorld(name: "Existing world")
      let record = try old.createRecord(worldID: world.id, title: "Original")
      _ = try old.saveRecord(
        worldID: world.id, id: record.id, version: record.version, title: "Revised",
        body: "Preserve this", rtf: nil)
      // Earlier files may have revisions in the original table instead of native_revisions.
      try old.db.execute(
        "INSERT INTO revisions SELECT synthesis_uuid(),world_id,record_id,version,snapshot,'Saved',created_at,created_at FROM native_revisions WHERE record_id=? AND version=1",
        [record.id])
      try old.db.execute(
        "DELETE FROM native_revisions WHERE record_id=? AND version=1", [record.id])
      for row in try old.db.rows(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'activity_%'")
      {
        try old.db.execute("DROP TRIGGER \(row["name"]!)")
      }
      try old.db.execute("DROP TABLE world_activity")
      try old.db.execute("DROP TABLE activity_imports")
      try old.db.execute("DELETE FROM schema_migrations WHERE name='0015_world_activity.sql'")
      return (world.id, record.id)
    }()
    let store = try WorkspaceStore(path: path)
    let history = try store.worldChangeHistory(worldID: ids.0)
    #expect(history.filter { $0.kind == .record }.map(\.title) == ["Revised", "Original"])
    #expect(history.allSatisfy { $0.reconstructed })
    #expect(try store.record(worldID: ids.0, id: ids.1).body == "Preserve this")
    let reopened = try WorkspaceStore(path: path)
    #expect(try reopened.worldChangeHistory(worldID: ids.0) == history)
  }
}
