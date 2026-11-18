import Foundation
import Testing

@testable import SynthesisCore

struct SimulationRunStoreTests {
  private func paused() throws -> SimulationResourceSnapshot {
    try SimulationResourceSnapshot(
      scenario: .init(
        horizonHours: 4, seed: UInt64.max, initialStock: 5, capacity: 8,
        parameters: .init(replenishment: 0, demand: 2)),
      through: 2)
  }

  @Test func snapshotsReopenAndBranchWithoutChangingTheirLoreOrHistory() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("universe.sqlite").path
    let original = try WorkspaceStore(path: path)
    let world = try original.createWorld(name: "The crossing")
    let page = try original.createRecord(worldID: world.id, title: "Current stores", kind: "lore")
    let saved = try original.saveSimulationRun(
      worldID: world.id, title: "Winter supply", unit: "crates", snapshot: paused())

    let reopened = try WorkspaceStore(path: path)
    let opened = try reopened.simulationRun(worldID: world.id, id: saved.summary.id)
    #expect(opened == saved)
    #expect(try opened.snapshot.replayed() == opened.snapshot)
    let alternative = try opened.snapshot
      .adding([.setParameters(.init(replenishment: 4, demand: 2))])
      .replayed(through: 4)
    let continued = try reopened.saveSimulationRun(
      worldID: world.id, title: "After the delivery", unit: "crates", snapshot: alternative)
    #expect(continued.summary.id != saved.summary.id)
    #expect(continued.snapshot.trace.map(\.closingStock) == [3, 1, 3, 5])
    #expect(try reopened.simulationRun(worldID: world.id, id: saved.summary.id) == saved)
    #expect(try reopened.record(worldID: world.id, id: page.id) == page)
    #expect(try reopened.proposals(worldID: world.id).isEmpty)
  }

  @Test func archiveAndUndoAreScopedAndRejectStaleChanges() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "First")
    let other = try store.createWorld(name: "Second")
    let run = try store.saveSimulationRun(
      worldID: world.id, title: "Winter supply", unit: "crates", snapshot: paused())
    #expect(try store.simulationRuns(worldID: other.id).isEmpty)
    #expect(throws: SynthesisError.self) {
      try store.setSimulationRunArchived(
        worldID: other.id, id: run.summary.id, archived: true, expectedRevision: 1)
    }
    let archived = try store.setSimulationRunArchived(
      worldID: world.id, id: run.summary.id, archived: true, expectedRevision: 1)
    #expect(try store.simulationRuns(worldID: world.id).isEmpty)
    #expect(try store.simulationRuns(worldID: world.id, archived: true) == [archived])
    #expect(throws: SynthesisError.self) {
      try store.setSimulationRunArchived(
        worldID: world.id, id: run.summary.id, archived: false, expectedRevision: 1)
    }
    let restored = try store.setSimulationRunArchived(
      worldID: world.id, id: run.summary.id, archived: false, expectedRevision: archived.revision)
    #expect(restored.revision == 3)
    #expect(try store.simulationRun(worldID: world.id, id: restored.id).snapshot == run.snapshot)
  }

  @Test func portableSnapshotsKeepTraceAndLiteralLabelsAndRejectTampering() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Origin")
    let run = try store.saveSimulationRun(
      worldID: world.id, title: world.id, unit: "boxes", snapshot: paused())
    _ = try store.setSimulationRunArchived(
      worldID: world.id, id: run.summary.id, archived: true, expectedRevision: 1)
    let data = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchive(data)
    let copied = try #require(try store.simulationRuns(worldID: copy.id, archived: true).first)
    #expect(copied.id != run.summary.id)
    #expect(copied.title == world.id)
    #expect(try store.simulationRun(worldID: copy.id, id: copied.id).snapshot == run.snapshot)

    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect((json["simulationRuns"] as? [[String: String]])?.first?["id"] == run.summary.id)

    var tampered = try JSONDecoder().decode(WorldArchive.self, from: data)
    let original = try #require(tampered.tables["simulation_runs"]?.first?["snapshot"])
    tampered.tables["simulation_runs"]?[0]["snapshot"] = original.replacingOccurrences(
      of: "\"closingStock\":3", with: "\"closingStock\":4")
    let before = try store.worlds()
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(tampered))
    }
    #expect(try store.worlds() == before)

    var exhausted = try JSONDecoder().decode(WorldArchive.self, from: data)
    exhausted.tables["simulation_runs"]?[0]["revision"] = String(Int.max - 1)
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(exhausted))
    }
    #expect(try store.worlds() == before)
  }
}
