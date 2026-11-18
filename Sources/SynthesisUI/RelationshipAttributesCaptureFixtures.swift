import Foundation
import SynthesisCore

extension Studio {
  static let relationshipMetadataCaptureStates = [
    "relationship-metadata-editor", "relationship-metadata-inspector", "relationship-history",
  ]

  func relationshipMetadataCaptureRelation() throws -> Relation {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      let mentor = records.first(where: { $0.title == "Oren Ashe" }),
      let student = records.first(where: { $0.title == "Mira Vale" }),
      let edge = try store.relations(worldID: worldID, recordID: mentor.id).first(where: {
        $0.sourceID == mentor.id && $0.targetID == student.id && $0.label == "mentors"
      })
    else { throw SynthesisError.notFound }
    return edge
  }

  func configureRelationshipMetadataCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.relationshipMetadataCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("graph", board: board, conversation: conversation)
    perform {
      let edge = try relationshipMetadataCaptureRelation()
      guard let evidence = records.first(where: { $0.title == "Crossing the Glass Sea" }) else {
        throw SynthesisError.notFound
      }
      var attributes = RelationshipAttributes()
      attributes.kind = .mentor
      attributes.startLabel = "Before the first crossing"
      attributes.endLabel = "After the council vote"
      attributes.strength = .strong
      attributes.secrecy = .restricted
      attributes.mutuality = .mutual
      attributes.status = .ended
      attributes.evidenceRecordIDs = [evidence.id]
      if edge.attributes != attributes {
        _ = try store.updateRelation(
          worldID: worldID, expected: edge, label: edge.label, attributes: attributes)
        try reload()
      }
      if state != "relationship-metadata-editor" {
        inspectionTarget = .relationship(edge.id)
        workspaceInspector = true
      }
      captureHint = state
    }
  }
}
