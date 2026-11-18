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
}
