import Foundation
import SynthesisCore

extension Studio {
  func configureFactionBatchCapture(board: String, conversation: String) {
    configureConnectedCapture("review", board: board, conversation: conversation)
    perform {
      guard let order = records.first(where: { $0.title == "Tidekeepers" }) else {
        throw SynthesisError.notFound
      }
      let summary = "Three coastal rivals for the Tidekeepers"
      let proposals = try store.proposals(worldID: worldID)
      let proposal: Proposal?
      if let saved = proposals.first(where: { $0.summary == summary }) {
        proposal = saved
      } else {
        let factions = [
          ("salt", "Salt League"), ("reef", "Reef Court"), ("shoal", "Shoal Assembly"),
        ]
        let creations = factions.map { key, title in
          [
            "action": "create_record", "ref": key, "kind": "entity", "title": title,
            "category": "Systems",
          ]
        }
        let connections = factions.map { key, _ in
          ["action": "relate", "source": "$\(key)", "target": order.id, "label": "competes with"]
        }
        proposal = try store.stageProposal(
          worldID: worldID, conversationID: nil, messageID: nil,
          payload: ["summary": summary, "changes": creations + connections])
      }
      guard let proposal, proposal.changes.count == 6 else {
        throw SynthesisError.invalid("The faction batch capture is incomplete.")
      }
      try reload()
      openProposalReview(proposal.id)
    }
  }
}
