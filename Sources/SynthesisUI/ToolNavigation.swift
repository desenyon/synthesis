import SynthesisCore

extension Studio {
  func openSettings(_ section: SettingsSection, query: String = "") {
    withNavigation {
      guard flushEditor() else { return }
      navigate(.settings)
      settingsSection = section
      settingsQuery = query
    }
  }
  func openTimelineLane(_ id: String?) {
    withNavigation {
      guard flushEditor() else { return }
      perform {
        if let id {
          guard try store.chronologyLanes(worldID: worldID).contains(where: { $0.id == id })
          else { throw SynthesisError.notFound }
        }
        navigate(.timeline)
        timelineLaneID = id
      }
    }
  }
  func openReviewSection(_ section: ReviewSection) {
    withNavigation {
      guard flushEditor() else { return }
      navigate(.review)
      reviewSection = section
      reviewFocusID = nil
    }
  }
  func openRecordTab(_ tab: RecordPageTab, recordID: String) {
    withNavigation {
      guard selectedRecord?.id == recordID || splitRecord?.id == recordID,
        records.contains(where: { $0.id == recordID && $0.kind == "entity" }), flushEditor()
      else { return }
      recordTabs[recordID] = tab
    }
  }

  /// An optional inspector may disappear while its workspace remains navigable. Resolve the
  /// address in the target universe before changing any current view; DB failures still throw.
  func currentNavigationInspection(_ target: InspectionTarget?, in world: String) throws
    -> InspectionTarget?
  {
    guard let target else { return nil }
    let available: Bool
    switch target {
    case .world: available = true
    case .record(let id):
      do {
        _ = try store.record(worldID: world, id: id)
        available = try !store.isArchived(worldID: world, recordID: id)
      } catch SynthesisError.notFound { return nil }
    case .event(let id): available = try store.events(worldID: world).contains { $0.id == id }
    case .lane(let id):
      available = try store.chronologyLanes(worldID: world).contains { $0.id == id }
    case .board(let id, let kind):
      guard ["canvas", "atlas"].contains(kind) else { return nil }
      available = try store.boards(worldID: world, kind: kind).contains { $0.id == id }
    case .relationship(let id):
      available = try store.relations(worldID: world).contains { $0.id == id }
    case .conversation(let id):
      available = try store.conversations(worldID: world).contains { $0.id == id }
    case .proposal(let id):
      do {
        _ = try store.proposal(worldID: world, id: id)
        available = true
      } catch SynthesisError.notFound { return nil }
    }
    return available ? target : nil
  }
}
