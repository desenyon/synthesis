import Foundation
import Testing

@testable import SynthesisCore

struct PreferencesTests {
  @Test func localPreferencesSurviveRestartAndValidatePartialStoredData() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("preferences.sqlite").path
    let store = try WorkspaceStore(path: path)
    var preferences = StudioPreferences()
    preferences.darkPalette = .oled
    preferences.density = .immersive
    preferences.bodySize = 20
    preferences.readingWidth = 960
    preferences.spellCheck = true
    preferences.wordCount = false
    preferences.sendShortcut = .commandEnter
    try store.setStudioPreferences(preferences)
    #expect(try WorkspaceStore(path: path).studioPreferences() == preferences)
    try store.setPreference(
      "studio-preferences",
      value:
        #"{"bodySize":999,"readingWidth":-1,"smartQuotes":false,"recentChats":-2,"launchWorkspace":"Delete","sendShortcut":"future","density":"future"}"#
    )
    let repaired = try store.studioPreferences()
    #expect(repaired.darkPalette == .graphite && repaired.density == .comfortable)
    #expect(repaired.bodySize == 16 && repaired.readingWidth == 780 && repaired.recentChats == 12)
    #expect(
      !repaired.smartQuotes && repaired.launchWorkspace == "remember"
        && repaired.sendShortcut == .enter)
    try store.setPreference("studio-preferences", value: "invalid")
    #expect(try store.studioPreferences() == StudioPreferences())
  }

  @Test func worldDefaultsAreIsolatedPortableAndDoNotExportDevicePreferences() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Other")
    var defaults = WorldPreferences()
    defaults.entityCategory = "  Sects  "
    defaults.chatMode = "Critique"
    try store.setWorldPreferences(worldID: world.id, value: defaults)
    try store.setPreference("studio-preferences", value: "DEVICE-ONLY")
    try store.setPreference("provider", value: "PRIVATE-PROVIDER")
    #expect(try store.worldPreferences(worldID: other.id) == WorldPreferences())
    #expect(throws: SynthesisError.self) {
      try store.setWorldPreferences(worldID: "missing", value: defaults)
    }
    let data = try store.exportWorldArchive(worldID: world.id)
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.contains("DEVICE-ONLY") && !text.contains("PRIVATE-PROVIDER"))
    let imported = try store.importWorldArchive(data)
    #expect(imported.id != world.id)
    #expect(try store.worldPreferences(worldID: imported.id) == defaults.validated)
    var legacy = try JSONDecoder().decode(WorldArchive.self, from: data)
    legacy.version = 3
    legacy.preferences.removeValue(forKey: "world-defaults")
    let legacyWorld = try store.importWorldArchive(JSONEncoder().encode(legacy))
    #expect(try store.worldPreferences(worldID: legacyWorld.id) == WorldPreferences())
  }

  @Test func aNewerDatabaseIsRejectedWhileItsWorldDataRemainsIntact() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("workspace.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Preserve this world")
    let record = try store.createRecord(worldID: world.id, title: "Preserve this record")
    let future = "9999_future_settings.sql"
    try store.db.execute(
      "INSERT INTO schema_migrations VALUES(?,?)", [future, "2026-11-17"])
    let applied = try store.db.rows("SELECT * FROM schema_migrations ORDER BY name")

    do {
      _ = try WorkspaceStore(path: path)
      Issue.record("Opened a workspace with an unsupported migration.")
    } catch SynthesisError.invalid(let message) {
      #expect(message.contains("newer Synthesis version"))
    }
    #expect(try store.db.rows("SELECT * FROM schema_migrations ORDER BY name") == applied)
    #expect(try store.record(worldID: world.id, id: record.id) == record)

    try store.db.execute("DELETE FROM schema_migrations WHERE name=?", [future])
    #expect(try WorkspaceStore(path: path).record(worldID: world.id, id: record.id) == record)
  }

  @Test func invalidWorldDefaultsRollBackImport() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    var archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    archive.preferences["world-defaults"] = "not json"
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(JSONEncoder().encode(archive))
    }
    #expect(try store.worlds().count == 1)
  }

  @Test func worldIdentitySaveIsAtomic() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Original", description: "Before")
    #expect(throws: SynthesisError.self) {
      try store.updateWorldDetails(
        worldID: world.id, name: "Changed", description: String(repeating: "x", count: 4001))
    }
    #expect(try store.world(world.id).name == "Original")
    #expect(try store.world(world.id).description == "Before")
    try store.updateWorldDetails(
      worldID: world.id, name: "Aster", description: "  The drowned world  ")
    #expect(try store.world(world.id).description == "The drowned world")
  }
}
