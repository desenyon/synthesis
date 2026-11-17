import Foundation

/// A small local query language. Every value becomes a bound SQL parameter, never SQL syntax.
public struct LoreSearchQuery: Equatable, Sendable {
  public enum Field: String, CaseIterable, Sendable {
    case type, category, status, tag, alias, faction, related, updated, created
  }
  public struct Filter: Equatable, Sendable {
    public let field: Field
    public let value: String
  }
  public let terms: [String]
  public let filters: [Filter]
  public var hasFilters: Bool { !filters.isEmpty }

  /// Also recognizes an unfinished filter, so UI fallbacks cannot bypass a malformed query.
  public static func usesFilters(_ input: String) -> Bool {
    if let parsed = try? parse(input) { return parsed.hasFilters }
    return input.split(whereSeparator: \.isWhitespace).contains { token in
      guard let colon = token.firstIndex(of: ":") else { return false }
      return Field(rawValue: token[..<colon].lowercased()) != nil
    }
  }

  public static func parse(_ input: String) throws -> Self {
    guard input.count <= 2048 else {
      throw SynthesisError.invalid("Keep search queries under 2,048 characters.")
    }
    var tokens: [(text: String, literal: Bool)] = []
    var token = ""
    var literal = false
    var quoted = false
    var escaped = false
    for character in input {
      if escaped {
        token.append(character)
        escaped = false
      } else if character == "\\", quoted {
        escaped = true
      } else if character == "\"" {
        if token.isEmpty { literal = true }
        quoted.toggle()
      } else if character.isWhitespace, !quoted {
        if !token.isEmpty { tokens.append((token, literal)) }
        token = ""
        literal = false
      } else {
        token.append(character)
      }
    }
    guard !quoted, !escaped else {
      throw SynthesisError.invalid("Close the double quote to finish this search.")
    }
    if !token.isEmpty { tokens.append((token, literal)) }
    guard tokens.count <= 64 else {
      throw SynthesisError.invalid("Use at most 64 search terms and filters.")
    }
    var terms: [String] = []
    var filters: [Filter] = []
    for entry in tokens {
      let token = entry.text
      guard !entry.literal, let colon = token.firstIndex(of: ":"),
        let field = Field(rawValue: token[..<colon].lowercased())
      else {
        terms.append(token)
        continue
      }
      let value = String(token[token.index(after: colon)...])
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !value.isEmpty else {
        throw SynthesisError.invalid("Add a value after \(field.rawValue):.")
      }
      if field == .status, !["idea", "draft", "canon", "hypothetical"].contains(value.lowercased())
      {
        throw SynthesisError.invalid(
          "Use status:idea, status:draft, status:canon or status:hypothetical.")
      }
      if field == .updated || field == .created { _ = try cutoff(value, now: Date()) }
      filters.append(Filter(field: field, value: value))
    }
    return Self(terms: terms, filters: filters)
  }

  /// Relative durations are rolling UTC hours/days/weeks, not fictional dates or calendar eras.
  static func cutoff(_ value: String, now: Date) throws -> String {
    let lower = value.lowercased()
    let units: [Character: Double] = ["h": 3600, "d": 86400, "w": 604800]
    if let unit = lower.last, let seconds = units[unit],
      let count = Int(lower.dropLast()), count > 0, count <= 36500
    {
      return ISO8601DateFormatter().string(from: now.addingTimeInterval(-Double(count) * seconds))
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    if let date = formatter.date(from: value), formatter.string(from: date) == value {
      return ISO8601DateFormatter().string(from: date)
    }
    throw SynthesisError.invalid(
      "Use a duration such as 24h, 7d or 2w, or a date such as 2026-11-01.")
  }

  static func categoryNames(_ value: String) -> [String] {
    let groups = [
      ["character", "characters"], ["faction", "factions", "system", "systems"],
      ["place", "places", "location", "locations"],
      ["power system", "power systems", "magic system", "magic systems"],
      ["event", "events", "historical events", "history"], ["scene", "scenes"],
    ]
    return groups.first { $0.contains(value.lowercased()) } ?? [value]
  }
}
