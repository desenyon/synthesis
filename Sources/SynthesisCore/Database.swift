import CSQLite
import Foundation

final class Database {
  private var handle: OpaquePointer?
  init(path: String) throws {
    if path != ":memory:" {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: path).deletingLastPathComponent(),
        withIntermediateDirectories: true)
    }
    guard
      sqlite3_open_v2(
        path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        == SQLITE_OK
    else { throw SynthesisError.database("Could not open the local database.") }
    sqlite3_busy_timeout(handle, 5000)
    try execute("PRAGMA foreign_keys=ON")
    try execute("PRAGMA journal_mode=WAL")
    try execute(
      "CREATE TABLE IF NOT EXISTS schema_migrations(name TEXT PRIMARY KEY,applied_at TEXT NOT NULL)"
    )
    let appFolder = Bundle.main.resourceURL?.appendingPathComponent("Migrations")
    let folder =
      appFolder.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? Bundle
      .module.url(forResource: "Migrations", withExtension: nil)!
    for file in try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil
    ).filter({ $0.pathExtension == "sql" }).sorted(by: {
      $0.lastPathComponent < $1.lastPathComponent
    }) {
      if try rows("SELECT name FROM schema_migrations WHERE name=?", [file.lastPathComponent])
        .isEmpty
      {
        try transaction {
          let sql = try String(contentsOf: file, encoding: .utf8)
          guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
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
    let statement = try prepare(sql, values)
    defer { sqlite3_finalize(statement) }
    var result: [[String: String]] = []
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
      result.append(row)
    }
    return result
  }
  private var depth = 0
  /// Atomic unit of work. Nested calls become savepoints, so a store operation can be composed
  /// from other transactional operations and still roll back as a whole.
  func transaction<T>(_ body: () throws -> T) throws -> T {
    let level = depth
    try execute(level == 0 ? "BEGIN IMMEDIATE" : "SAVEPOINT nested_\(level)")
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
