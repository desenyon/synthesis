import Foundation
import Testing

@testable import SynthesisCore

struct WorldCheckTests {
  @Test func mutualOneWayRelationshipsAreFlaggedButSymmetricOnesAreNot() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Checks")
    let a = try store.createRecord(worldID: world.id, title: "Oren", kind: "entity")
    let b = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    _ = try store.addRelation(worldID: world.id, source: a.id, target: b.id, label: "mentors")
    _ = try store.addRelation(worldID: world.id, source: b.id, target: a.id, label: "Mentors")
    _ = try store.addRelation(worldID: world.id, source: a.id, target: b.id, label: "allied with")
    _ = try store.addRelation(worldID: world.id, source: b.id, target: a.id, label: "allied with")
    let found = try store.worldChecks(worldID: world.id).filter {
      $0.kind == .conflictingRelationship
    }
    #expect(found.count == 1)
    #expect(found[0].title.contains("mentors"))
    #expect(Set(found[0].recordIDs) == [a.id, b.id])
  }

  @Test func timelineOrderConflictsOnlyCompareTheSameEra() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Dates")
    let source = try store.createRecord(worldID: world.id, title: "Annals")
    _ = try store.addEvent(
      worldID: world.id, title: "Founding", date: "Year 120 AE", source: source.id, order: 1)
    _ = try store.addEvent(
      worldID: world.id, title: "Drowning", date: "Year 40 AE", source: source.id, order: 2)
    _ = try store.addEvent(
      worldID: world.id, title: "Old age", date: "12 of the second moon", source: source.id,
      order: 3)
    _ = try store.addEvent(
      worldID: world.id, title: "Unknown", date: "unknown", source: source.id, order: 4)
    let found = try store.worldChecks(worldID: world.id).filter { $0.kind == .timelineOrder }
    #expect(found.count == 1)
    #expect(found[0].title.contains("Drowning"))
    #expect(WorkspaceStore.comparableDate("300 BCE")?.value == -300)
    #expect(WorkspaceStore.comparableDate("unknown") == nil)
  }

  @Test func timelineOrderFindingsStayWithinEachHistoryIncludingArchivedAncestors() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Alternate histories")
    let source = try store.createRecord(worldID: world.id, title: "Annals")
    let first = try store.createChronologyLane(
      worldID: world.id, name: "First path", kind: "branch")
    let second = try store.createChronologyLane(
      worldID: world.id, name: "Second path", kind: "branch")
    let period = try store.createChronologyLane(
      worldID: world.id, name: "Period", kind: "period", parentID: first.id)

    func add(_ title: String, year: Int, order: Int, laneID: String? = nil) throws -> WorldEvent {
      try store.saveChronologyEvent(
        worldID: world.id, id: nil, title: title, date: "Year \(year) AE", source: source.id,
        order: order, laneID: laneID)
    }

    _ = try add("Opening", year: 1, order: 1)
    let later = try add("Founding", year: 120, order: 2, laneID: first.id)
    _ = try add("Second path's opening", year: 40, order: 3, laneID: second.id)
    let earlier = try add("Drowning", year: 30, order: 4, laneID: period.id)
    _ = try add("Second path's end", year: 90, order: 5, laneID: second.id)
    _ = try add("Closing", year: 2, order: 6)

    func findingIDs() throws -> [String] {
      try store.worldChecks(worldID: world.id).filter { $0.kind == .timelineOrder }.map(\.id)
    }

    let expected = ["timeline-order:\(later.id):\(earlier.id)"]
    #expect(try findingIDs() == expected)
    try store.setChronologyLaneArchived(worldID: world.id, id: first.id, archived: true)
    #expect(try findingIDs() == expected)
  }

  @Test func tagVariantsMergeAsRevisionsAndUndoRestoresThem() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tags")
    let other = try store.createWorld(name: "Elsewhere")
    var first = try store.createRecord(worldID: world.id, title: "One")
    first = try store.saveMetadata(
      worldID: world.id, id: first.id, version: first.version, tags: ["Sea-faring", "Old"],
      aliases: [])
    var second = try store.createRecord(worldID: world.id, title: "Two")
    second = try store.saveMetadata(
      worldID: world.id, id: second.id, version: second.version, tags: ["seafaring"], aliases: [])
    var third = try store.createRecord(worldID: world.id, title: "Three")
    third = try store.saveMetadata(
      worldID: world.id, id: third.id, version: third.version, tags: ["seafaring"], aliases: [])
    var foreign = try store.createRecord(worldID: other.id, title: "Foreign")
    foreign = try store.saveMetadata(
      worldID: other.id, id: foreign.id, version: foreign.version, tags: ["Sea-faring"],
      aliases: [])

    let finding = try #require(
      try store.worldChecks(worldID: world.id).first { $0.kind == .tagVariant })
    #expect(finding.value == "seafaring")
    let previous = try store.mergeTagVariants(worldID: world.id, preferred: "seafaring")
    #expect(previous.map(\.id) == [first.id])
    let merged = try store.record(worldID: world.id, id: first.id)
    #expect(merged.tags == ["seafaring", "Old"])
    #expect(merged.version == first.version + 1)
    #expect(try store.record(worldID: other.id, id: foreign.id).tags == ["Sea-faring"])
    #expect(try store.worldChecks(worldID: world.id).allSatisfy { $0.kind != .tagVariant })

    try store.restoreTags(worldID: world.id, previous: previous)
    #expect(try store.record(worldID: world.id, id: first.id).tags == ["Sea-faring", "Old"])
  }
}
