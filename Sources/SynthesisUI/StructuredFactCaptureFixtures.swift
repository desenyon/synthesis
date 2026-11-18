import Foundation
import SynthesisCore

extension Studio {
  static let structuredFactCaptureStates = [
    "structured-facts", "structured-fact-edit", "structured-fact-review",
    "structured-fact-evidence",
  ]

  func configureStructuredFactCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.structuredFactCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("library", board: board, conversation: conversation)
    perform {
      guard let subject = records.first(where: { $0.title == "Mira Vale" && $0.kind == "entity" }),
        let source = records.first(where: { $0.kind == "lore" })
      else { throw SynthesisError.notFound }
      if try store.structuredFacts(worldID: subject.worldID, subjectID: subject.id).isEmpty {
        let evidence = try store.structuredFactEvidence(
          worldID: subject.worldID, recordID: source.id)
        let title = try store.createStructuredFact(
          worldID: subject.worldID, subjectID: subject.id, predicate: "Title",
          draft: .init(value: .text("Keeper of the Breakwater"), evidence: evidence))
        let accepted = try store.approveStructuredFact(
          worldID: subject.worldID, expected: title, confirmation: title.working.id)
        try store.reviseStructuredFact(
          worldID: subject.worldID, expected: accepted,
          draft: .init(value: .text("Captain of the Outer Shoal"), disputed: true))
        try store.createStructuredFact(
          worldID: subject.worldID, subjectID: subject.id, predicate: "Home port",
          draft: .init(value: .text("Harbour of Bells"), evidence: evidence))
      }
      openRecord(subject)
      guard selectedRecord?.id == subject.id else { throw SynthesisError.notFound }
      openRecordTab(.overview, recordID: subject.id)
      inspector = false
      captureHint = state
    }
  }
}
