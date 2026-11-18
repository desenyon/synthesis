import CSQLite
import Foundation

final class Database {
  let path: String
  private var handle: OpaquePointer?
  init(path: String, openExisting: Bool = false) throws {
    self.path = path
    if !openExisting, path != ":memory:" {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: path).deletingLastPathComponent(),
        withIntermediateDirectories: true)
    }
    let flags =
      SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | (openExisting ? 0 : SQLITE_OPEN_CREATE)
    guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
      sqlite3_close(handle)
      handle = nil
      throw SynthesisError.database("Could not open the local database.")
    }
    sqlite3_busy_timeout(handle, 5000)
    // Match creator-authored names consistently, including accented/non-ASCII aliases.
    guard
      sqlite3_create_collation_v2(
        handle, "synthesis_search", SQLITE_UTF8, nil,
        { _, aCount, a, bCount, b in
          let locale = Locale(identifier: "en_US_POSIX")
          let left = String(
            decoding: UnsafeRawBufferPointer(start: a, count: Int(aCount)), as: UTF8.self
          ).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
          let right = String(
            decoding: UnsafeRawBufferPointer(start: b, count: Int(bCount)), as: UTF8.self
          ).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
          // Normalize before ordering: locale-aware compare can equate case variants while
          // ordering them differently against a third value, breaking SQLite's IN lookup.
          return left == right ? 0 : (left < right ? -1 : 1)
        }, nil) == SQLITE_OK
    else { throw failure() }
    // Durable activity triggers need portable UUIDs; generated once for each committed change.
    guard
      sqlite3_create_function_v2(
        handle, "synthesis_uuid", 0, SQLITE_UTF8, nil,
        { context, _, _ in
          UUID().uuidString.withCString {
            sqlite3_result_text(
              context, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
          }
        }, nil, nil, nil) == SQLITE_OK
    else { throw failure() }
    guard
      sqlite3_create_function_v2(
        handle, "synthesis_board_changed", 2, SQLITE_UTF8 | SQLITE_DETERMINISTIC, nil,
        { context, _, values in
          guard let values,
            let old = sqlite3_value_text(values[0]), let new = sqlite3_value_text(values[1])
          else {
            sqlite3_result_int(context, 1)
            return
          }
          sqlite3_result_int(
            context,
            BoardActivity.changed(String(cString: old), String(cString: new)) ? 1 : 0)
        }, nil, nil, nil) == SQLITE_OK
    else { throw failure() }
    let appFolder = Bundle.main.resourceURL?.appendingPathComponent("Migrations")
    let folder =
      appFolder.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? Bundle
      .module.url(forResource: "Migrations", withExtension: nil)!
    let migrations = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "sql" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    let knownMigrations = Set(migrations.map(\.lastPathComponent))
    if try !rows(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='schema_migrations'"
    ).isEmpty {
      let appliedMigrations = try rows("SELECT name FROM schema_migrations")
      guard appliedMigrations.allSatisfy({ $0["name"].map(knownMigrations.contains) == true })
      else {
        throw SynthesisError.invalid(
          "This workspace requires a newer Synthesis version. Open it with the version that last saved it or a later version."
        )
      }
    }
    try execute("PRAGMA foreign_keys=ON")
    if openExisting { return }
    try execute("PRAGMA journal_mode=WAL")
    try execute(
      "CREATE TABLE IF NOT EXISTS schema_migrations(name TEXT PRIMARY KEY,applied_at TEXT NOT NULL)"
    )
    for file in migrations {
      if try rows("SELECT name FROM schema_migrations WHERE name=?", [file.lastPathComponent])
        .isEmpty
      {
        try transaction {
          let sql = try String(contentsOf: file, encoding: .utf8)
          guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
          if file.lastPathComponent == "0015_world_activity.sql" {
            try ActivityHistoryMigration.backfill(self)
          }
          try execute(
            "INSERT INTO schema_migrations VALUES(?,?)", [file.lastPathComponent, timestamp()])
        }
      }
    }
  }
  deinit { sqlite3_close(handle) }
  private func failure() -> Error {
    SynthesisError.database(String(cString: sqlite3_errmsg(handle)))
  }
  private func prepare(_ sql: String, _ values: [String?]) throws -> OpaquePointer {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      throw failure()
    }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    for (i, value) in values.enumerated() {
      if let value {
        sqlite3_bind_text(statement, Int32(i + 1), value, -1, transient)
      } else {
        sqlite3_bind_null(statement, Int32(i + 1))
      }
    }
    return statement
  }
  func execute(_ sql: String, _ values: [String?] = []) throws {
    let statement = try prepare(sql, values)
    defer { sqlite3_finalize(statement) }
    let result = sqlite3_step(statement)
    guard result == SQLITE_DONE || result == SQLITE_ROW else { throw failure() }
  }
  func rows(_ sql: String, _ values: [String?] = []) throws -> [[String: String]] {
    var result: [[String: String]] = []
    try forEachRow(sql, values) { result.append($0) }
    return result
  }
  func forEachRow(
    _ sql: String, _ values: [String?], _ read: ([String: String]) throws -> Void
  ) throws {
    let statement = try prepare(sql, values)
    defer { sqlite3_finalize(statement) }
    while true {
      let step = sqlite3_step(statement)
      if step == SQLITE_DONE { break }
      guard step == SQLITE_ROW else { throw failure() }
      var row: [String: String] = [:]
      for column in 0..<sqlite3_column_count(statement) {
        if let value = sqlite3_column_text(statement, column) {
          row[String(cString: sqlite3_column_name(statement, column))] = String(cString: value)
        }
      }
      try read(row)
    }
  }
  private var depth = 0
  /// Atomic unit of work. Nested calls become savepoints, so a store operation can be composed
  /// from other transactional operations and still roll back as a whole.
  func transaction<T>(immediate: Bool = true, _ body: () throws -> T) throws -> T {
    let level = depth
    let begin = immediate ? "BEGIN IMMEDIATE" : "BEGIN DEFERRED"
    try execute(level == 0 ? begin : "SAVEPOINT nested_\(level)")
    depth += 1
    defer { depth -= 1 }
    do {
      let result = try body()
      try execute(level == 0 ? "COMMIT" : "RELEASE nested_\(level)")
      return result
    } catch {
      if level == 0 {
        try? execute("ROLLBACK")
      } else {
        try? execute("ROLLBACK TO nested_\(level)")
        try? execute("RELEASE nested_\(level)")
      }
      throw error
    }
  }
}
