import Foundation
import SynthesisCore

enum RecordLinkKind: String, CaseIterable {
  case reference = "Reference"
  case relationship = "Relationship"
}

struct RecordLinkDraft: Equatable {
  let worldID: String
  var sourceID = ""
  var targetID = ""
  var label = ""
  var reverse = false
  var reverseLabel = ""
  var entitiesOnly = false
  var kind = RecordLinkKind.relationship

  func isValid(records: [LoreRecord]) -> Bool {
    let choices = records.filter {
      $0.worldID == worldID && (kind == .reference || $0.kind == "entity")
    }
    return sourceID != targetID && choices.contains { $0.id == sourceID }
      && choices.contains { $0.id == targetID }
      && (kind == .reference
        || (!label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && label.count <= 80
          && (!reverse
            || (!reverseLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && reverseLabel.count <= 80))))
  }
}

extension Studio {
  public var canBeginCreation: Bool { world != nil && sheet == nil }
  public var canBeginLinking: Bool { canBeginCreation && records.count >= 2 }

  public func beginRecordCreation(kind: String = "lore") {
    guard canBeginCreation, ["lore", "entity", "capture"].contains(kind), flushEditor() else {
      return
    }
    newRecordKind = kind
    sheet = .document
  }
  public func beginLinkRecords() {
    let selected = focusedEditorPlacement == .beside ? splitRecord?.id : selectedRecord?.id
    let spatial =
      destination == .knowledge ? graphSelectedID : (destination == .atlas ? atlasSelectedID : nil)
    guard canBeginLinking else { return }
    beginRelationship(sourceID: selected ?? spatial)
    if records.first(where: { $0.id == recordLinkDraft?.sourceID })?.kind != "entity"
      || records.filter({ $0.kind == "entity" }).count < 2
    {
      recordLinkDraft?.kind = .reference
    }
  }
  func beginRelationship(
    sourceID: String? = nil, targetID: String? = nil, entitiesOnly: Bool = false
  ) {
    guard canBeginLinking, flushEditor() else { return }
    let choices = records.filter { !entitiesOnly || $0.kind == "entity" }
    guard choices.count >= 2 else { return }
    let source = choices.first { $0.id == sourceID }?.id ?? ""
    let target = choices.first { $0.id == targetID && $0.id != source }?.id ?? ""
    recordLinkDraft = RecordLinkDraft(
      worldID: worldID, sourceID: source, targetID: target, entitiesOnly: entitiesOnly)
    sheet = .linkRecords
  }
  @discardableResult func saveRecordLink(_ draft: RecordLinkDraft) -> Bool {
    guard draft.worldID == worldID else {
      error = "The selected world changed. Reopen Link records in the intended world."
      return false
    }
    guard flushEditor() else { return false }
    do {
      guard draft.isValid(records: try store.records(worldID: worldID)) else {
        throw SynthesisError.invalid(
          "Choose two available records and describe their relationship.")
      }
      if draft.kind == .reference {
        try store.linkRecord(worldID: worldID, source: draft.sourceID, target: draft.targetID)
      } else {
        try store.addRelationshipPair(
          worldID: worldID, source: draft.sourceID, target: draft.targetID,
          label: draft.label.trimmingCharacters(in: .whitespacesAndNewlines),
          inverse: draft.reverse
            ? draft.reverseLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil)
      }
      try reload()
      recordLinkDraft = nil
      sheet = nil
      show(
        draft.kind == .reference
          ? "Linked reference"
          : (draft.reverse ? "Saved both relationship directions" : "Saved relationship"),
        icon: "link")
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
}
