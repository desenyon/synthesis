import Foundation
import SynthesisCore

extension Studio {
  func configureSearchIndexCapture(stale: Bool) throws {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Search index fixtures require isolated capture.")
    }
    let name = "Harbour chartroom"
    let fixture = try store.worlds().first { $0.name == name } ?? store.createWorld(name: name)
    let original = "The harbour of glass"
    let changed = "The ultramarine harbour"
    let place =
      try store.records(worldID: fixture.id).first { [original, changed].contains($0.title) }
      ?? store.createRecord(worldID: fixture.id, title: original, kind: "entity")
    if try store.entityTypes(worldID: fixture.id).isEmpty {
      let type = try store.saveEntityType(
        worldID: fixture.id, name: "Navigator",
        fields: [.init(key: "home", label: "Home", kind: .entity)],
        defaults: ["home": .entity(place.id)])
      _ = try store.createTypedEntity(worldID: fixture.id, typeID: type.id, title: "Cartographer")
    }
    try store.rebuildSearchIndexes(worldID: fixture.id)
    if stale {
      _ = try store.saveRecord(
        worldID: fixture.id, id: place.id, version: place.version,
        title: place.title == original ? changed : original, body: place.body, rtf: place.rtf)
    }
    guard try store.staleSearchIndexes(worldID: fixture.id) == (stale ? [.entityProperties] : [])
    else { throw SynthesisError.invalid("The search index fixture did not reproduce its state.") }
    switchWorld(fixture.id)
    guard worldID == fixture.id else { throw SynthesisError.notFound }
    destination = .settings
    settingsSection = .data
    settingsQuery = "Search indexes"
  }
}
