import Foundation
import SynthesisCore

extension Studio {
  func configureRequestPinsCapture(_ state: String, board: String, conversation: String) {
    configureConnectedCapture("conversation", board: board, conversation: conversation)
    perform {
      guard let mira = records.first(where: { $0.title == "Mira Vale" }),
        let keepers = records.first(where: { $0.title == "Tidekeepers" })
      else { throw SynthesisError.notFound }
      let period: ChronologyLane
      if let existing = contextLanes.first(where: { $0.name == "Early crossings" }) {
        period = existing
      } else {
        period = try store.createChronologyLane(
          worldID: worldID, name: "Early crossings", kind: "period")
        try reload()
      }
      updateRequestPins {
        $0.recordIDs = [mira.id, keepers.id]
        $0.laneIDs = [period.id]
      }
      draft = "How did these relationships change during the crossing?"
      captureHint = state
    }
  }
}
