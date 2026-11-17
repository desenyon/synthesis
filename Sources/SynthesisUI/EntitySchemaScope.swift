import SynthesisCore

/// Retained in sheet State, so a universe switch cannot retarget an unfinished creation form.
struct EntitySchemaScope: Equatable {
  let worldID: String
  func mismatchMessage(activeWorldID: String) -> String? {
    activeWorldID == worldID
      ? nil
      : "This draft belongs to the universe where you opened it. Return to that universe to save; your unfinished changes are preserved here."
  }
  func requireCurrentWorld(_ activeWorldID: String) throws {
    if let message = mismatchMessage(activeWorldID: activeWorldID) {
      throw SynthesisError.invalid(message)
    }
  }
  @MainActor func perform<T>(in studio: Studio, _ work: (WorkspaceStore, String) throws -> T) throws
    -> T
  {
    try requireCurrentWorld(studio.worldID)
    return try work(studio.store, worldID)
  }
}
