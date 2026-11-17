import Foundation
import Testing

@testable import SynthesisCore

/// Measurements on a large synthetic world. Bounds are generous so the suite stays reliable on a
/// busy machine; the printed timings are the evidence recorded in docs/PERFORMANCE.md.
struct ScaleTests {
  static func largeWorld() throws -> (WorkspaceStore, String) {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Large world")
    try store.db.transaction {
      var entities: [String] = []
      for i in 0..<600 {
        entities.append(
          try store.createRecord(
            worldID: world.id, title: "Harbour Warden \(i)",
            body: "Keeps the lamps of district \(i % 40) and answers to the tide council.",
            kind: "entity", category: i % 3 == 0 ? "Characters" : "Places"
          ).id)
      }
      for i in 0..<1400 {
        _ = try store.createRecord(
          worldID: world.id, title: "Chronicle \(i)",
          body:
            "A navigator from the northern archipelago keeps the winter records. Harbour Warden \(i % 600) is named here."
        )
      }
      for i in 0..<1500 {
        _ = try store.addRelation(
          worldID: world.id, source: entities[i % 600],
          target: entities[(i % 600 + 1 + i / 600) % 600],
          label: i % 2 == 0 ? "answers to" : "allied with")
      }
      let source = entities[0]
      for i in 0..<300 {
        _ = try store.addEvent(
          worldID: world.id, title: "Tide \(i)", date: "Year \(i) AE", source: source, order: i)
      }
    }
    return (store, world.id)
  }

  @Test func checksRecordsAndSummariesStayResponsiveAtTwoThousandRecords() throws {
    let (store, worldID) = try Self.largeWorld()
    var clock = ContinuousClock.now
    let records = try store.records(worldID: worldID)
    let load = clock.duration(to: .now)
    #expect(records.count == 2000)

    clock = .now
    let findings = try store.worldChecks(worldID: worldID)
    let checks = clock.duration(to: .now)
    #expect(!findings.isEmpty)

    clock = .now
    for _ in 0..<20 { _ = try store.search(worldID: worldID, query: "warden archipelago") }
    let search = clock.duration(to: .now)

    clock = .now
    _ = try store.relations(worldID: worldID)
    _ = try store.events(worldID: worldID)
    let reads = clock.duration(to: .now)

    print(
      "Scale benchmark (2,000 records, 1,500 relationships, 300 events): records \(load), checks \(checks), 20 searches \(search), relations+events \(reads)"
    )
    #expect(checks < .seconds(5))
    #expect(search < .seconds(2))
  }
}
