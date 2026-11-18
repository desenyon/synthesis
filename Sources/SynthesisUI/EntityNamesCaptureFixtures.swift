import Foundation
import SynthesisCore

extension Studio {
  static let entityNamesCaptureStates = ["entity-names", "entity-name-edit"]

  func configureEntityNamesCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.entityNamesCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("library", board: board, conversation: conversation)
    perform {
      guard let entity = records.first(where: { $0.title == "Tidekeepers" && $0.kind == "entity" })
      else { throw SynthesisError.notFound }
      let existing = try store.entityNamePeriods(worldID: entity.worldID, recordID: entity.id)
      let drafts: [EntityNamePeriodDraft] = [
        .init(
          name: "Keepers of the First Tide", startLabel: "First tide-year",
          endLabel: "The harbour reforms"),
        .init(kind: .alias, name: "The Shoreward Watch", startLabel: "After the first crossing"),
      ]
      for draft in drafts where !existing.contains(where: { $0.draft == draft }) {
        try store.createEntityNamePeriod(worldID: entity.worldID, recordID: entity.id, draft: draft)
      }
      try reload()
      openRecord(entity)
      guard selectedRecord?.id == entity.id else { throw SynthesisError.notFound }
      openRecordTab(.overview, recordID: entity.id)
      inspector = false
      captureHint = state
    }
  }
}
