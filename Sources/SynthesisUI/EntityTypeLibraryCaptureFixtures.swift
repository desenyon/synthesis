import Foundation
import SynthesisCore

extension Studio {
  static let entityTypeLibraryCaptureStates = [
    "entity-type-library", "light-entity-type-library", "entity-type-library-search",
  ]

  func configureEntityTypeLibraryCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.entityTypeLibraryCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("library", board: board, conversation: conversation)
    perform {
      let name = "Chart keepers"
      let type =
        try store.entityTypes(worldID: worldID).first { $0.name == name }
        ?? store.saveEntityType(worldID: worldID, name: name, fields: [])
      let member =
        try records.first { $0.title == "Harbor chart steward" }
        ?? store.createTypedEntity(worldID: worldID, typeID: type.id, title: "Harbor chart steward")
      if !records.contains(where: { $0.title == "Tide chart steward" }) {
        _ = try store.createTypedEntity(
          worldID: worldID, typeID: type.id, title: "Tide chart steward")
      }
      if !records.contains(where: { $0.title == "Harbor visitor" }) {
        _ = try store.createRecord(
          worldID: worldID, title: "Harbor visitor", kind: "entity", category: name)
      }
      try reload()
      openEntityTypeLens(type.id)
      guard activeLibraryEntityType?.recordIDs.count == 2 else {
        throw SynthesisError.invalid("The type capture requires two assigned entities.")
      }
      if state.hasSuffix("-search") {
        libraryQuery = "Harbor"
        let matches = try store.search(
          worldID: worldID, query: libraryQuery, scope: .init(entityTypeID: type.id))
        guard matches.map(\.id) == [member.id] else {
          throw SynthesisError.invalid("The typed search capture requires one assigned entity.")
        }
      }
      dark = !state.hasPrefix("light-")
      captureHint = state
    }
  }
}
