import Foundation

extension WorkspaceStore {
  func workspaceSnapshot(worldID: String, action: String, id: String) throws -> [String: String] {
    switch action {
    case "revise_event":
      guard let event = try events(worldID: worldID).first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      return [
        "title": event.title, "date": event.dateLabel, "source": event.sourceID,
        "order": event.order.map(String.init) ?? "",
        "lane": try chronologyPlacements(worldID: worldID)[id] ?? "",
      ]
    case "revise_lane":
      guard let lane = try chronologyLanes(worldID: worldID).first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      return [
        "title": lane.name, "date": lane.start, "endDate": lane.end, "body": lane.notes,
        "kind": lane.kind, "lane": lane.parentID ?? "",
      ]
    case "revise_map":
      let map = try board(worldID: worldID, id: id, kind: "atlas")
      let links = try AtlasLinks(content: map.content)
      return [
        "title": map.name, "source": links.placeID ?? "", "parentMap": links.parentMapID ?? "",
      ]
    case "revise_relationship":
      guard let relation = try relations(worldID: worldID).first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      return ["label": relation.label, "source": relation.sourceID, "target": relation.targetID]
    default: throw SynthesisError.invalid("Unknown workspace revision.")
    }
  }

  func prepareWorkspaceRevision(worldID: String, item: [String: Any], change: inout ProposedChange)
    -> Bool
  {
    guard let id = item["id"] as? String,
      let before = try? workspaceSnapshot(worldID: worldID, action: change.action, id: id)
    else { return false }
    for key in ["title", "date", "endDate", "body", "source", "lane", "parentMap", "label"] {
      if let value = item[key], !(value is String) { return false }
    }
    func value(_ key: String) -> String {
      (item[key] as? String ?? before[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let title = value("title")
    let date = value("date")
    let end = value("endDate")
    let body = value("body")
    guard title.count <= (change.action == "revise_map" ? 120 : 160), date.count <= 160,
      end.count <= 160, body.count <= 30_000
    else { return false }
    if change.action != "revise_relationship" && title.isEmpty { return false }
    let source = value("source")
    let parent = value("lane")
    let mapParent = value("parentMap")
    if !source.isEmpty {
      guard let record = try? record(worldID: worldID, id: source),
        (try? isArchived(worldID: worldID, recordID: source)) == false,
        change.action != "revise_map" || record.kind == "entity"
      else { return false }
    } else if change.action == "revise_event" {
      return false
    }
    if ["revise_event", "revise_lane"].contains(change.action), !parent.isEmpty {
      guard (try? chronologyLanes(worldID: worldID).contains { $0.id == parent }) == true else {
        return false
      }
    }
    if change.action == "revise_map", !mapParent.isEmpty {
      guard (try? board(worldID: worldID, id: mapParent, kind: "atlas")) != nil else {
        return false
      }
    }
    if change.action == "revise_relationship" {
      let label = value("label")
      guard !label.isEmpty, label.count <= 80 else { return false }
      change.label = label
      change.source = before["source"]
      change.target = before["target"]
    } else {
      change.title = title
      change.date = date
      change.endDate = end
      change.body = body
      change.source = source.isEmpty ? nil : source
      change.laneID = parent
      change.parentMapID = mapParent
    }
    change.recordID = id
    change.workspaceBefore = before
    return true
  }

  func applyWorkspaceRevision(worldID: String, change: ProposedChange) throws -> String {
    guard let id = change.recordID, let before = change.workspaceBefore,
      try workspaceSnapshot(worldID: worldID, action: change.action, id: id) == before
    else { throw SynthesisError.stale }
    switch change.action {
    case "revise_event":
      _ = try saveChronologyEvent(
        worldID: worldID, id: id, title: change.title ?? before["title"]!,
        date: change.date ?? before["date"]!, source: change.source,
        order: before["order"].flatMap(Int.init),
        laneID: change.laneID.flatMap { $0.isEmpty ? nil : $0 })
    case "revise_lane":
      guard let lane = try chronologyLanes(worldID: worldID).first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      try updateChronologyLane(
        worldID: worldID, expected: lane, name: change.title ?? lane.name,
        parentID: change.laneID.flatMap { $0.isEmpty ? nil : $0 }, start: change.date ?? lane.start,
        end: change.endDate ?? lane.end, notes: change.body ?? lane.notes)
    case "revise_map":
      let current = try board(worldID: worldID, id: id, kind: "atlas")
      guard
        var object = try JSONSerialization.jsonObject(with: Data(current.content.utf8))
          as? [String: Any]
      else { throw SynthesisError.notFound }
      object["placeID"] = change.source
      object["parentMapID"] = change.parentMapID.flatMap { $0.isEmpty ? nil : $0 }
      _ = try saveAtlasMap(
        worldID: worldID, id: id, name: change.title ?? current.name,
        content: String(
          decoding: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          as: UTF8.self), expected: current)
    case "revise_relationship":
      try updateRelation(worldID: worldID, id: id, label: change.label ?? before["label"]!)
    default: throw SynthesisError.invalid("Unknown workspace revision.")
    }
    return id
  }
}
