import SynthesisCore

extension Studio {
  func configureContextExclusionCapture(board: String, conversation: String) {
    configureConnectedCapture("conversation", board: board, conversation: conversation)
    perform {
      let name = "A different crossing"
      let branch =
        try contextLanes.first { $0.name == name }
        ?? store.createChronologyLane(worldID: worldID, name: name, kind: "branch")
      guard let source = records.first(where: { $0.title == "Crossing the Glass Sea" }) else {
        throw SynthesisError.notFound
      }
      try reload()
      updateContext {
        $0.canonOnly = true
        $0.excludedLaneIDs = [branch.id]
        $0.excludedRecordIDs = [source.id]
      }
      draft = "What is established about the crossing?"
      captureHint = "context-exclusions"
    }
  }

  func configureSubmittedContextCapture(board: String, conversation: String) {
    configureConnectedCapture("conversation", board: board, conversation: conversation)
    perform {
      guard let mira = records.first(where: { $0.title == "Mira Vale" }) else {
        throw SynthesisError.notFound
      }
      updateRequestPins { $0.recordIDs = [mira.id] }
      let snapshot = try previewContext(prompt: "Describe Mira's crossing.")
      guard snapshot.sources.first?.id == mira.id else {
        throw SynthesisError.invalid("The submitted context did not include the pinned source.")
      }
      clearRequestPins()
      submittedAssistantContext = snapshot
      busy = true
      draft = "What did the council decide afterward?"
      captureHint = "context-submitted"
    }
  }
}
