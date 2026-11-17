import Foundation
import SynthesisCore

enum InspectionTarget: Hashable, Codable {
  case world
  case record(String)
  case event(String)
  case lane(String)
  case board(String, kind: String)
  case relationship(String)
  case conversation(String)
  case proposal(String)
}

struct InspectionProperty {
  var name: String
  var value: String
}
struct InspectionReference {
  var target: InspectionTarget
  var title: String
  var detail: String
  var icon: String
}
struct ObjectInspection {
  var title: String
  var kind: String
  var icon: String
  var state: String?
  var text = ""
  var artwork: String?
  var properties: [InspectionProperty] = []
  var references: [InspectionReference] = []
}

extension Studio {
  var effectiveInspection: InspectionTarget {
    if let selectedRecord { return .record(selectedRecord.id) }
    if let inspectionTarget { return inspectionTarget }
    switch destination {
    case .knowledge:
      return graphSelectedID.map(InspectionTarget.record) ?? .world
    case .atlas:
      return atlasSelectedID.map(InspectionTarget.record)
        ?? mapBoardID.map { .board($0, kind: "atlas") } ?? .world
    case .canvas:
      return canvasSession?.selection.first.map(InspectionTarget.record)
        ?? canvasBoardID.map { .board($0, kind: "canvas") } ?? .world
    case .timeline: return timelineLaneID.map(InspectionTarget.lane) ?? .world
    case .chat: return conversationID.map(InspectionTarget.conversation) ?? .world
    case .review: return pendingProposals.first.map { .proposal($0.id) } ?? .world
    default: return .world
    }
  }
  func inspect(_ target: InspectionTarget) {
    // Validate before publishing so a foreign or stale reference cannot leak a prior object.
    perform {
      _ = try inspectionData(for: target)
      focusMode = false
      inspectionTarget = target
      workspaceInspector = true
      try store.setPreference("workspace-inspector", value: "shown")
    }
  }
  func selectForInspection(_ target: InspectionTarget) {
    perform {
      _ = try inspectionData(for: target)
      inspectionTarget = target
    }
  }
  public func toggleWorkspaceInspector() {
    if focusMode {
      focusMode = false
      if workspaceInspector { return }
    }
    perform {
      try store.setPreference("workspace-inspector", value: workspaceInspector ? "hidden" : "shown")
      workspaceInspector.toggle()
    }
  }
  func followInspectionSelection() { inspectionTarget = nil }

  /// Local, read-only projections. Every lookup is scoped by the selected universe.
  /// A missing reference throws; it never falls back to a similarly named object elsewhere.
  func inspectionData(for target: InspectionTarget) throws -> ObjectInspection {
    func property(_ name: String, _ value: String) -> InspectionProperty {
      InspectionProperty(name: name, value: value.isEmpty ? "Not specified" : value)
    }
    func reference(_ id: String, _ detail: String) -> InspectionReference? {
      guard let record = records.first(where: { $0.id == id && $0.worldID == worldID }) else {
        return nil
      }
      return InspectionReference(
        target: .record(id), title: record.title, detail: detail, icon: recordIcon(record))
    }
    switch target {
    case .world:
      let world = try store.world(worldID)
      return ObjectInspection(
        title: world.name, kind: "Universe", icon: "globe", text: world.description,
        properties: [
          property("Content", world.demo ? "Sample universe" : "Your universe"),
          property("Records", "\(topLevelRecords.count)"),
          property("Relationships", "\(try store.relations(worldID: worldID).count)"),
          property("Events", "\(try store.events(worldID: worldID).count)"),
          property("Conversations", "\(conversations.count)"),
        ])
    case .record(let id):
      guard records.contains(where: { $0.id == id && $0.worldID == worldID }) else {
        throw SynthesisError.notFound
      }
      let record = try store.record(worldID: worldID, id: id)
      var result = ObjectInspection(
        title: record.title, kind: Vocabulary.displayCategory(record.category),
        icon: recordIcon(record), state: record.state, text: record.body,
        artwork: try store.recordArtwork(worldID: worldID, recordID: id)?.image,
        properties: [
          property("Type", Vocabulary.kindLabel(record.kind)),
          property("Revision", "\(record.version)"), property("Updated", record.updatedAt),
          property("Origin", record.origin),
          property("Tags", (record.tags ?? []).joined(separator: ", ")),
          property("Aliases", (record.aliases ?? []).joined(separator: ", ")),
          property(
            "Canon", record.canonical == nil ? "Not established" : "Accepted version preserved"),
        ])
      for relation in try store.relations(worldID: worldID)
      where relation.sourceID == id || relation.targetID == id {
        let outward = relation.sourceID == id
        if let link = reference(
          outward ? relation.targetID : relation.sourceID,
          outward ? relation.label : "Incoming · \(relation.label)")
        {
          result.references.append(link)
        }
      }
      for event in try store.events(worldID: worldID) where event.sourceID == id {
        result.references.append(
          InspectionReference(
            target: .event(event.id), title: event.title, detail: event.dateLabel,
            icon: "calendar"))
      }
      for section in try store.recordSections(worldID: worldID, parentID: id) {
        if let link = reference(section.record.id, "Section") { result.references.append(link) }
      }
      return result
    case .event(let id):
      guard let event = try store.events(worldID: worldID).first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      let placements = try store.chronologyPlacements(worldID: worldID)
      let lane = try store.chronologyLanes(worldID: worldID).first { $0.id == placements[id] }
      var result = ObjectInspection(
        title: event.title, kind: "Historical event", icon: "calendar",
        properties: [
          property("Date", event.dateLabel == "unknown" ? "Unknown" : event.dateLabel),
          property("Order", event.order.map(String.init) ?? "Unspecified"),
        ], references: reference(event.sourceID, "Source").map { [$0] } ?? [])
      if let lane {
        result.references.append(
          InspectionReference(
            target: .lane(lane.id), title: lane.name, detail: lane.kind.capitalized,
            icon: "arrow.triangle.branch"))
      }
      return result
    case .lane(let id):
      let lanes = try store.chronologyLanes(worldID: worldID)
      guard let lane = lanes.first(where: { $0.id == id }) else { throw SynthesisError.notFound }
      var result = ObjectInspection(
        title: lane.name, kind: lane.kind.capitalized, icon: "arrow.triangle.branch",
        text: lane.notes,
        properties: [property("Begins", lane.start), property("Ends", lane.end)])
      for relative in lanes where relative.id == lane.parentID || relative.parentID == id {
        result.references.append(
          InspectionReference(
            target: .lane(relative.id), title: relative.name,
            detail: relative.id == lane.parentID ? "Parent" : "Contains",
            icon: "arrow.triangle.branch"))
      }
      let placements = try store.chronologyPlacements(worldID: worldID)
      for event in try store.events(worldID: worldID) where placements[event.id] == id {
        result.references.append(
          InspectionReference(
            target: .event(event.id), title: event.title,
            detail: event.dateLabel, icon: "calendar"))
      }
      return result
    case .board(let id, let kind):
      guard ["atlas", "canvas"].contains(kind) else { throw SynthesisError.notFound }
      let board = try store.board(worldID: worldID, id: id, kind: kind)
      var result = ObjectInspection(
        title: board.name, kind: kind == "atlas" ? "Map" : "Canvas",
        icon: kind == "atlas" ? "map" : "rectangle.on.rectangle")
      if kind == "atlas" {
        let map = try JSONDecoder().decode(AtlasDocument.self, from: Data(board.content.utf8))
        result.artwork = map.image
        result.properties = [
          property("Markers", "\(map.markers.count)"), property("Regions", "\(map.regions.count)"),
        ]
        result.references =
          map.markers.compactMap {
            reference(
              $0.recordID, String(format: "Marker · %.1f%%, %.1f%%", $0.x * 100, $0.y * 100))
          }
          + map.regions.compactMap {
            reference($0.recordID, "Region · \($0.points.count) vertices")
          }
        if let place = map.placeID, let link = reference(place, "Map of") {
          result.references.insert(link, at: 0)
        }
        if let parent = map.parentMapID {
          let containing = try store.board(worldID: worldID, id: parent, kind: "atlas")
          result.references.insert(
            InspectionReference(
              target: .board(parent, kind: "atlas"), title: containing.name, detail: "Parent map",
              icon: "map"), at: 0)
        }
      } else {
        let content = try CanvasBoardContent.decode(board.content)
        let elements = (content.scene?["elements"] as? [[String: Any]] ?? []).filter {
          $0["isDeleted"] as? Bool != true
        }
        let ids = Set(
          elements.compactMap { ($0["customData"] as? [String: Any])?["recordID"] as? String }
            + (content.legacy?.cards.compactMap(\.recordID) ?? []))
        result.properties = [
          property("Placed records", "\(ids.count)"), property("Arrangement", "Manually curated"),
        ]
        result.references = ids.sorted().compactMap { reference($0, "On this canvas") }
      }
      return result
    case .relationship(let id):
      guard let edge = try store.relations(worldID: worldID).first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      return ObjectInspection(
        title: edge.label, kind: "Relationship", icon: "arrow.triangle.branch",
        references: [reference(edge.sourceID, "From"), reference(edge.targetID, "To")].compactMap {
          $0
        })
    case .conversation(let id):
      guard let chat = try store.conversations(worldID: worldID).first(where: { $0.id == id })
      else { throw SynthesisError.notFound }
      let messages = try store.messages(worldID: worldID, conversationID: id)
      let context = try store.messageContext(worldID: worldID, conversationID: id)
      let referenced = Set(context.values.flatMap { $0.map(\.id) })
      return ObjectInspection(
        title: chat.title, kind: "Conversation", icon: "bubble.left",
        properties: [
          property("Messages", "\(messages.count)"), property("Updated", chat.updatedAt),
        ],
        references: referenced.sorted().compactMap {
          reference($0, "Referenced in this conversation")
        })
    case .proposal(let id):
      let proposal = try store.proposal(worldID: worldID, id: id)
      let referenced = Set(
        proposal.changes.flatMap {
          $0.evidence + [$0.recordID, $0.source, $0.target].compactMap { $0 }
        })
      return ObjectInspection(
        title: proposal.summary, kind: "Proposal", icon: "square.stack.3d.up",
        properties: [
          property("Origin", proposal.isBranchMerge ? "What-if branch" : "Assistant"),
          property("Created", proposal.createdAt), property("Changes", "\(proposal.changes.count)"),
          property("Pending", "\(proposal.pending)"),
          property("Canon", "Requires separate explicit approval"),
        ],
        references: referenced.sorted().compactMap { reference($0, "Change or evidence") })
    }
  }
}
