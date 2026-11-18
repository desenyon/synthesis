import Foundation

/// The excluded chronology subtrees and the event and record addresses they depend on.
struct AssistantChronologyExclusions: Equatable, Sendable {
  var laneIDs: Set<String> = []
  var eventIDs: Set<String> = []
  var recordIDs: Set<String> = []
}

extension WorkspaceStore {
  func assistantChronologyExclusions(
    worldID: String, laneIDs: [String]
  ) throws -> AssistantChronologyExclusions {
    _ = try world(worldID)
    guard !laneIDs.isEmpty else { return .init() }

    // Archiving one lane leaves its children and placements in place. Keep that ancestry
    // for scope decisions so an archive operation cannot reintroduce excluded sources.
    let lanes = try db.rows("SELECT id,parent_id FROM chronology_lanes WHERE world_id=?", [worldID])
    let laneIDSet = Set(lanes.compactMap { $0["id"] })
    var excluded = AssistantChronologyExclusions(laneIDs: Set(laneIDs))
    guard excluded.laneIDs.isSubset(of: laneIDSet) else {
      throw SynthesisError.invalid("Choose history exclusions from this universe.")
    }
    let children = Dictionary(grouping: lanes) { $0["parent_id"] ?? "" }
    var pending = Array(excluded.laneIDs)
    while let parentID = pending.popLast() {
      for row in children[parentID, default: []] {
        if let id = row["id"], excluded.laneIDs.insert(id).inserted {
          pending.append(id)
        }
      }
    }

    let placements = try db.rows(
      """
      SELECT p.lane_id,e.id,e.source_id FROM chronology_placements p
      JOIN events e ON e.id=p.event_id AND e.world_id=p.world_id
      WHERE p.world_id=?
      """, [worldID])
    for placement in placements {
      guard let laneID = placement["lane_id"], excluded.laneIDs.contains(laneID),
        let eventID = placement["id"], let sourceID = placement["source_id"]
      else { continue }
      excluded.eventIDs.insert(eventID)
      excluded.recordIDs.insert(sourceID)
    }
    return excluded
  }

  /// A proposal can retain history text after an event or lane moves. Check both the
  /// staged before/after addresses and the current location of any event it touched.
  func isChronologyReferenceExcluded(
    _ reference: WorldReference, worldID: String, exclusions: AssistantChronologyExclusions
  ) throws -> Bool {
    try reference.validate()
    guard reference.worldID == worldID else {
      throw SynthesisError.invalid("References can only be used inside their own universe.")
    }
    guard !exclusions.laneIDs.isEmpty else { return false }
    switch reference.kind {
    case .event:
      return exclusions.eventIDs.contains(reference.id)
    case .proposal:
      let proposal = try proposal(worldID: worldID, id: reference.id)
      return proposal.changes.contains { change in
        let lanes = [change.laneID, change.workspaceBefore?["lane"]].compactMap { $0 }
        if !exclusions.laneIDs.isDisjoint(with: lanes) { return true }
        let targets = [change.recordID, change.resultID].compactMap { $0 }
        switch change.action {
        case "add_event", "revise_event":
          return !exclusions.eventIDs.isDisjoint(with: targets)
        case "create_branch", "create_period", "revise_lane":
          // An accepted lane's result ID is also the resolution of any intra-proposal
          // change reference to that lane. Checking the entire proposal covers both.
          return !exclusions.laneIDs.isDisjoint(with: targets)
        default:
          return false
        }
      }
    default:
      return false
    }
  }
}
