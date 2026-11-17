import Foundation
import SynthesisCore

extension Studio {
  func configureKeyboardCreationCapture(_ state: String, board: String, conversation: String) {
    configureConnectedCapture(
      state.hasSuffix("empty") ? "empty-library" : "library", board: board,
      conversation: conversation)
    sheet = nil
    recordLinkDraft = nil
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    if state.hasSuffix("reference"), let source = records.first(where: { $0.kind == "lore" }) {
      openRecord(source)
    } else if !state.hasSuffix("entity") && !state.hasSuffix("created")
      && !state.hasSuffix("empty"),
      let source = records.first(where: { $0.title == "Mira Vale" })
    {
      openRecord(source)
    }
    inspector = false
    captureHint = state
  }

  public func auditKeyboardCreationCapture(
    _ state: String, invoke: (String) throws -> Void, enabled: (String) throws -> Bool
  ) async throws -> [String] {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Creation audit requires isolated capture data.")
    }
    let originalMode = mode
    let originalRecords = try store.records(worldID: worldID)
    let originalLocation = navigationLocation
    navigate(.settings)
    try invoke("Back")
    guard navigationLocation == originalLocation else {
      throw SynthesisError.invalid("Back shortcut lost the current workspace.")
    }
    try invoke("Forward")
    guard destination == .settings else {
      throw SynthesisError.invalid("Forward shortcut did not revisit the tool.")
    }
    try invoke("Back")
    if state.hasSuffix("empty") {
      guard try !enabled("Link Records…"), try enabled("New Entity…") else {
        throw SynthesisError.invalid("Creation availability is wrong for an empty world.")
      }
    } else if state.hasSuffix("entity") || state.hasSuffix("created") {
      try invoke("New Entity…")
      guard sheet == .document, newRecordKind == "entity", try !enabled("New Entity…") else {
        throw SynthesisError.invalid("New Entity did not open the guarded native form.")
      }
      if state.hasSuffix("created") {
        createRecord(title: "The western cartographer", kind: "entity", category: "Characters")
        guard let record = selectedRecord, record.title == "The western cartographer",
          record.kind == "entity", record.state == "draft", record.canonical == nil,
          try store.record(worldID: worldID, id: record.id) == record
        else { throw SynthesisError.invalid("Created entity was not saved and opened.") }
      }
    } else if state.hasSuffix("inspector") {
      try invoke("Toggle Inspector")
      guard inspector else { throw SynthesisError.invalid("Inspector command did not open it.") }
    } else if state.hasSuffix("mode") {
      try invoke("Toggle AI Assisted / Manual")
      guard mode != originalMode, navigationLocation == originalLocation else {
        throw SynthesisError.invalid("Mode shortcut changed the workspace or failed.")
      }
    } else {
      try invoke("Link Records…")
      guard sheet == .linkRecords, var draft = recordLinkDraft,
        draft.sourceID == selectedRecord?.id,
        let target = records.first(where: { $0.title == "The Glass Sea" })
      else { throw SynthesisError.invalid("Link command lost the current source.") }
      draft.targetID = target.id
      if !state.hasSuffix("reference") {
        draft.kind = .relationship
        draft.label = "charts"
        draft.reverse = true
        draft.reverseLabel = "charted by"
      }
      recordLinkDraft = draft
    }
    try await Task.sleep(for: .milliseconds(350))
    let saved = try store.records(worldID: worldID)
    let originalIDs = Set(originalRecords.map(\.id))
    guard !busy, error == nil,
      state.hasSuffix("mode") || mode == originalMode,
      saved.filter({ originalIDs.contains($0.id) }) == originalRecords,
      saved.count == originalRecords.count + (state.hasSuffix("created") ? 1 : 0)
    else { throw SynthesisError.invalid("Creation shortcut changed unrelated lore or failed.") }
    return [
      "PASS \(state): Back/Forward key equivalents restore the current document/tool",
      "PASS \(state): native key-equivalent dispatch and expected command/form state",
      "PASS \(state): source world, saved drafts and assistance boundary preserved",
    ]
  }
}
