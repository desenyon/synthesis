import Foundation

extension WorkspaceStore {
  private static let searchIndexQueue = DispatchQueue(
    label: "dev.synthesis.search-index-maintenance", qos: .utility)

  /// Maintenance owns a second connection for file-backed stores. The live editor connection
  /// remains actor confined. SQLite serializes index writes with ordinary saves.
  @MainActor public func maintainSearchIndexes(
    worldID: String, rebuild: Bool
  ) async throws -> Set<SearchIndexComponent> {
    let path = db.path
    if path == ":memory:" {
      if rebuild { try rebuildSearchIndexes(worldID: worldID) }
      return try staleSearchIndexes(worldID: worldID)
    }
    return try await withCheckedThrowingContinuation { continuation in
      Self.searchIndexQueue.async {
        continuation.resume(
          with: Result {
            let store = WorkspaceStore(database: try Database(path: path, openExisting: true))
            if rebuild { try store.rebuildSearchIndexes(worldID: worldID) }
            return try store.staleSearchIndexes(worldID: worldID)
          })
      }
    }
  }
}
