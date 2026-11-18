import Foundation
import SynthesisCore

extension Studio {
  static let bidirectionalRelationshipCaptureStates = [
    "relationship-outgoing", "relationship-incoming",
  ]

  func configureBidirectionalRelationshipCapture(
    _ state: String, board: String, conversation: String
  ) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.bidirectionalRelationshipCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("library", board: board, conversation: conversation)
    perform {
      guard let mira = records.first(where: { $0.title == "Mira Vale" }),
        let keepers = records.first(where: { $0.title == "Tidekeepers" })
      else { throw SynthesisError.notFound }
      let outgoing = try recordRelationships(for: mira).filter { $0.counterpart.id == keepers.id }
      let incoming = try recordRelationships(for: keepers).filter { $0.counterpart.id == mira.id }
      guard outgoing.count == 1, incoming.count == 1, let edge = outgoing.first,
        edge.relation.sourceID == mira.id, edge.relation.targetID == keepers.id,
        edge.relation.label == "guided by", incoming.first?.id == edge.id
      else {
        throw SynthesisError.invalid(
          "The capture requires one shared relationship in both profiles.")
      }
      let endpoint = state == "relationship-incoming" ? keepers : mira
      openRecord(endpoint)
      guard selectedRecord?.id == endpoint.id else { throw SynthesisError.notFound }
      inspector = true
      captureHint = state
    }
  }
}
