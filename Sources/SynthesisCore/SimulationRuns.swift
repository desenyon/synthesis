import Foundation

/// An immutable calculated prefix and the exact inputs that produced it.
public struct SimulationResourceSnapshot: Codable, Equatable, Sendable {
  public let scenario: SimulationResourceScenario
  public let trace: [SimulationResourceStep]

  public var totalSteps: Int {
    guard scenario.horizonHours > 0, scenario.stepHours > 0 else { return 0 }
    return Int(scenario.horizonHours / scenario.stepHours)
  }
  public var finished: Bool { trace.count == totalSteps }

  public init(scenario: SimulationResourceScenario, through completedSteps: Int? = nil) throws {
    self.scenario = scenario
    trace = try scenario.trace(through: completedSteps)
  }

  public func replayed(through completedSteps: Int? = nil) throws -> Self {
    try Self(scenario: scenario, through: completedSteps ?? trace.count)
  }

  public func adding(_ actions: [SimulationResourceAction]) throws -> Self {
    try Self(
      scenario: scenario.adding(actions, after: trace.count),
      through: trace.count)
  }
}

public struct SimulationRunSummary: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let unit: String
  public let completedSteps: Int
  public let totalSteps: Int
  public let archived: Bool
  public let revision: Int
}

public struct SavedSimulationRun: Equatable, Sendable {
  public let summary: SimulationRunSummary
  public let snapshot: SimulationResourceSnapshot
}

extension WorkspaceStore {
  public func simulationRuns(worldID: String, archived: Bool = false) throws
    -> [SimulationRunSummary]
  {
    _ = try world(worldID)
    return try db.rows(
      """
      SELECT id,title,unit,completed_steps,total_steps,archived,revision
      FROM simulation_runs WHERE world_id=? AND archived=? ORDER BY created_at DESC,rowid DESC
      """, [worldID, archived ? "1" : "0"]
    ).map(Self.simulationSummary)
  }

  public func simulationRun(worldID: String, id: String) throws -> SavedSimulationRun {
    _ = try world(worldID)
    guard
      let row = try db.rows(
        "SELECT * FROM simulation_runs WHERE world_id=? AND id=?", [worldID, id]
      ).first
    else { throw SynthesisError.notFound }
    return try Self.decodeSimulationRun(row)
  }

  @discardableResult public func saveSimulationRun(
    worldID: String, title: String, unit: String, snapshot: SimulationResourceSnapshot
  ) throws -> SavedSimulationRun {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
    try Self.validateSimulationLabels(title: title, unit: unit)
    try Self.validateSimulationSnapshot(snapshot)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(snapshot)
    guard data.count <= 6_000_000 else {
      throw SynthesisError.invalid("The result is too large to save. Use a larger step interval.")
    }
    let id = UUID().uuidString
    let now = timestamp()
    try db.transaction {
      _ = try world(worldID)
      try db.execute(
        """
        INSERT INTO simulation_runs(
          id,world_id,title,unit,snapshot,completed_steps,total_steps,created_at,updated_at
        ) VALUES(?,?,?,?,?,?,?,?,?)
        """,
        [
          id, worldID, title, unit, String(decoding: data, as: UTF8.self),
          String(snapshot.trace.count), String(snapshot.totalSteps), now, now,
        ])
    }
    return SavedSimulationRun(
      summary: SimulationRunSummary(
        id: id, title: title, unit: unit, completedSteps: snapshot.trace.count,
        totalSteps: snapshot.totalSteps, archived: false, revision: 1),
      snapshot: snapshot)
  }

  @discardableResult public func setSimulationRunArchived(
    worldID: String, id: String, archived: Bool, expectedRevision: Int
  ) throws -> SimulationRunSummary {
    try db.transaction {
      _ = try world(worldID)
      guard
        let row = try db.rows(
          """
          SELECT id,title,unit,completed_steps,total_steps,archived,revision
          FROM simulation_runs WHERE world_id=? AND id=?
          """, [worldID, id]
        ).first
      else { throw SynthesisError.notFound }
      let summary = try Self.simulationSummary(row)
      guard summary.revision == expectedRevision else { throw SynthesisError.stale }
      guard summary.archived != archived else { return summary }
      guard summary.revision < Int.max else { throw SynthesisError.stale }
      try db.execute(
        "UPDATE simulation_runs SET archived=?,revision=revision+1,updated_at=? WHERE world_id=? AND id=?",
        [archived ? "1" : "0", timestamp(), worldID, id])
      return SimulationRunSummary(
        id: id, title: summary.title, unit: summary.unit, completedSteps: summary.completedSteps,
        totalSteps: summary.totalSteps, archived: archived, revision: summary.revision + 1)
    }
  }

  /// Called inside portable import after all rows are inserted in the new world.
  func validateSimulationArchive(worldID: String) throws {
    for row in try db.rows("SELECT * FROM simulation_runs WHERE world_id=?", [worldID]) {
      let run = try Self.decodeSimulationRun(row)
      guard run.summary.revision <= 1_000_000_000 else {
        throw SynthesisError.invalid("The imported simulation has an invalid archive revision.")
      }
      try Self.validateSimulationSnapshot(run.snapshot)
    }
  }

  private static func simulationSummary(_ row: [String: String]) throws -> SimulationRunSummary {
    guard let id = row["id"], let title = row["title"], let unit = row["unit"],
      let completed = row["completed_steps"].flatMap(Int.init), (1...10_000).contains(completed),
      let total = row["total_steps"].flatMap(Int.init), (completed...10_000).contains(total),
      let revision = row["revision"].flatMap(Int.init), revision > 0,
      let archive = row["archived"], archive == "0" || archive == "1"
    else { throw SynthesisError.invalid("The saved simulation metadata is invalid.") }
    try validateSimulationLabels(title: title, unit: unit)
    return SimulationRunSummary(
      id: id, title: title, unit: unit, completedSteps: completed, totalSteps: total,
      archived: archive == "1", revision: revision)
  }

  private static func decodeSimulationRun(_ row: [String: String]) throws -> SavedSimulationRun {
    let summary = try simulationSummary(row)
    guard let payload = row["snapshot"], payload.utf8.count <= 6_000_000 else {
      throw SynthesisError.invalid("The saved simulation is missing or too large.")
    }
    let snapshot = try JSONDecoder().decode(
      SimulationResourceSnapshot.self, from: Data(payload.utf8))
    // Validate the interval before dividing or presenting counts from untrusted JSON.
    let scenario = snapshot.scenario
    guard scenario.stepHours > 0, scenario.horizonHours > 0,
      scenario.horizonHours % scenario.stepHours == 0,
      scenario.horizonHours / scenario.stepHours == Int64(summary.totalSteps),
      snapshot.trace.count == summary.completedSteps
    else { throw SynthesisError.invalid("The saved simulation interval does not match its trace.") }
    return SavedSimulationRun(summary: summary, snapshot: snapshot)
  }

  private static func validateSimulationSnapshot(_ snapshot: SimulationResourceSnapshot) throws {
    guard (1...10_000).contains(snapshot.trace.count),
      try snapshot.replayed() == snapshot
    else { throw SynthesisError.invalid("The saved trace does not match its scenario inputs.") }
  }

  private static func validateSimulationLabels(title: String, unit: String) throws {
    guard (1...120).contains(title.unicodeScalars.count), title.utf8.count <= 480,
      (1...40).contains(unit.unicodeScalars.count), unit.utf8.count <= 160,
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !title.contains("\u{0000}"), !unit.contains("\u{0000}")
    else {
      throw SynthesisError.invalid(
        "Give the run a name (up to 120 characters) and a unit (up to 40).")
    }
  }
}
