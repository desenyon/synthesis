import Foundation
import Testing
@testable import SynthesisCore
struct StoreTests {
    func fixture() throws -> WorkspaceStore { try WorkspaceStore(path: ":memory:") }
    @Test func persistenceAcrossReopen() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var s: WorkspaceStore? = try WorkspaceStore(path: path)
        let w = try s!.createWorld(name: "Aster"), c = try s!.createConversation(worldID: w.id)
        _ = try s!.appendMessage(worldID: w.id, conversationID: c.id, role: "user", body: "Build a sea", state: "complete")
        _ = try s!.createRecord(worldID: w.id, title: "Sea", body: "The water turns to glass")
        try s!.setPreference("mode", value: "manual"); s = nil
        let reopened = try WorkspaceStore(path: path)
        #expect(try reopened.messages(worldID: w.id, conversationID: c.id).first?.body == "Build a sea")
        #expect(try reopened.records(worldID: w.id).first?.body == "The water turns to glass")
        #expect(try reopened.preference("mode") == "manual")
    }
    @Test func worldIsolation() throws {
        let s = try fixture(), a = try s.createWorld(name: "A"), b = try s.createWorld(name: "B")
        let r = try s.createRecord(worldID: a.id, title: "Secret moon", body: "hidden"), c = try s.createConversation(worldID: a.id)
        #expect(throws: Error.self) { try s.record(worldID: b.id, id: r.id) }
        #expect(throws: Error.self) { try s.messages(worldID: b.id, conversationID: c.id) }
        #expect(try s.search(worldID: b.id, query: "moon").isEmpty)
        #expect(try s.search(worldID: a.id, query: "moon").count == 1)
    }
    @Test func canonAndStaleSaveBoundary() throws {
        let s = try fixture(), w = try s.createWorld(name: "A")
        var r = try s.createRecord(worldID: w.id, title: "Rule", body: "One moon")
        #expect(throws: Error.self) { try s.promote(worldID: w.id, id: r.id, version: r.version, confirmation: "") }
        r = try s.promote(worldID: w.id, id: r.id, version: r.version, confirmation: r.id)
        let old = r.version
        r = try s.saveRecord(worldID: w.id, id: r.id, version: r.version, title: r.title, body: "Two moons", rtf: nil)
        #expect(r.canonical?.contains("One moon") == true); #expect(r.state == "draft")
        #expect(throws: Error.self) { try s.saveRecord(worldID: w.id, id: r.id, version: old, title: "Rule", body: "Stale", rtf: nil) }
        #expect(try s.history(worldID: w.id, id: r.id).count == 3)
    }
    @Test func relationshipIsolationAndUnknownDates() throws {
        let s = try fixture(), a = try s.createWorld(name: "A"), b = try s.createWorld(name: "B")
        let x = try s.createRecord(worldID: a.id, title: "X", body: "", kind: "entity"), y = try s.createRecord(worldID: b.id, title: "Y", body: "", kind: "entity")
        #expect(throws: Error.self) { try s.addRelation(worldID: a.id, source: x.id, target: y.id, label: "knows") }
        #expect(try s.addEvent(worldID: a.id, title: "Arrival", date: "", source: x.id).dateLabel == "unknown")
    }
    @Test func richTextAndCanvasPersistence() throws {
        let s = try fixture(), w = try s.createWorld(name: "A")
        var r = try s.createRecord(worldID: w.id, title: "Page", body: "First")
        r = try s.saveRecord(worldID: w.id, id: r.id, version: r.version, title: "Page", body: "Bold", rtf: "encoded-rtf")
        #expect(try s.record(worldID: w.id, id: r.id).rtf == "encoded-rtf")
        let b = try s.saveBoard(worldID: w.id, name: "Ideas", kind: "canvas", content: "[{\"text\":\"A thought\"}]")
        #expect(try s.boards(worldID: w.id, kind: "canvas").first?.id == b.id)
    }
}
