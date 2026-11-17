import Foundation

/// Creator-authored instructions. A recipe is portable world data, not an executable tool,
/// provider setting, model response or canon approval.
public struct PromptRecipe: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var worldID: String
  public var title: String
  public var instructions: String
  public var mode: String
  public var version: Int
  public var archived: Bool
  public var createdAt: String
  public var updatedAt: String
}

extension WorkspaceStore {
  public func promptRecipes(worldID: String, archived: Bool = false, query: String = "") throws
    -> [PromptRecipe]
  {
    _ = try world(worldID)
    let recipes = try db.rows(
      "SELECT * FROM prompt_recipes WHERE world_id=? AND archived=? ORDER BY updated_at DESC,rowid DESC",
      [worldID, archived ? "1" : "0"]
    ).map(decodePromptRecipe)
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty
      ? recipes
      : recipes.filter {
        $0.title.localizedStandardContains(query)
          || $0.instructions.localizedStandardContains(query)
          || $0.mode.localizedStandardContains(query)
      }
  }

  public func promptRecipe(worldID: String, id: String) throws -> PromptRecipe {
    _ = try world(worldID)
    guard
      let row = try db.rows(
        "SELECT * FROM prompt_recipes WHERE world_id=? AND id=?", [worldID, id]
      ).first
    else { throw SynthesisError.notFound }
    return decodePromptRecipe(row)
  }

  public func createPromptRecipe(worldID: String, title: String, instructions: String, mode: String)
    throws -> PromptRecipe
  {
    _ = try world(worldID)
    let title = try validateRecipe(title: title, instructions: instructions, mode: mode)
    let id = UUID().uuidString
    let now = timestamp()
    try db.execute(
      "INSERT INTO prompt_recipes(id,world_id,title,instructions,mode,version,archived,created_at,updated_at) VALUES(?,?,?,?,?,1,0,?,?)",
      [id, worldID, title, instructions, mode, now, now])
    return try promptRecipe(worldID: worldID, id: id)
  }

  @discardableResult public func updatePromptRecipe(
    worldID: String, id: String, version: Int, title: String, instructions: String, mode: String
  ) throws -> PromptRecipe {
    try db.transaction {
      let current = try promptRecipe(worldID: worldID, id: id)
      guard current.version == version else { throw SynthesisError.stale }
      guard !current.archived else {
        throw SynthesisError.invalid("Restore this recipe before editing it.")
      }
      let title = try validateRecipe(title: title, instructions: instructions, mode: mode)
      try db.execute(
        "UPDATE prompt_recipes SET title=?,instructions=?,mode=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
        [title, instructions, mode, timestamp(), worldID, id])
      return try promptRecipe(worldID: worldID, id: id)
    }
  }

  @discardableResult public func setPromptRecipeArchived(
    worldID: String, id: String, version: Int, archived: Bool
  ) throws -> PromptRecipe {
    try db.transaction {
      let current = try promptRecipe(worldID: worldID, id: id)
      guard current.version == version else { throw SynthesisError.stale }
      if current.archived != archived {
        try db.execute(
          "UPDATE prompt_recipes SET archived=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
          [archived ? "1" : "0", timestamp(), worldID, id])
      }
      return try promptRecipe(worldID: worldID, id: id)
    }
  }

  func validateRecipe(title: String, instructions: String, mode: String) throws -> String {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, title.count <= 120 else {
      throw SynthesisError.invalid("Give the recipe a title of 1–120 characters.")
    }
    guard !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      instructions.count <= 30_000
    else {
      throw SynthesisError.invalid("Recipe instructions must contain 1–30,000 characters.")
    }
    guard ["Create", "Develop", "Critique", "Simulate", "Canonize"].contains(mode) else {
      throw SynthesisError.invalid("Choose an available assistant mode.")
    }
    return title
  }

  private func decodePromptRecipe(_ row: [String: String]) -> PromptRecipe {
    PromptRecipe(
      id: row["id"]!, worldID: row["world_id"]!, title: row["title"]!,
      instructions: row["instructions"]!, mode: row["mode"]!, version: Int(row["version"]!)!,
      archived: row["archived"] == "1", createdAt: row["created_at"]!, updatedAt: row["updated_at"]!
    )
  }
}
