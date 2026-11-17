import Foundation

public enum EntityFieldKind: String, Codable, CaseIterable, Sendable {
  case text, number, boolean, date, range, duration, selection, selections, entity, entities,
    coordinates, media, formula
  public var label: String {
    switch self {
    case .text: "Text"
    case .number: "Number"
    case .boolean: "Yes / No"
    case .date: "World date"
    case .range: "Range"
    case .duration: "Duration"
    case .selection: "Selection"
    case .selections: "Multiple choices"
    case .entity: "Linked entity"
    case .entities: "Linked entities"
    case .coordinates: "Coordinates"
    case .media: "Image"
    case .formula: "Computed number"
    }
  }
}

/// Values are data only. Formula evaluation is a bounded arithmetic parser, never executable code.
public enum EntityValue: Codable, Equatable, Sendable {
  case text(String)
  case number(Double)
  case boolean(Bool)
  case date(String)
  case range(Double, Double)
  case duration(Double, String)
  case selection(String)
  case selections([String])
  case entity(String)
  case entities([String])
  case coordinates(Double, Double, String)
  case media(name: String, mime: String, base64: String)
  case unknown

  public var summary: String {
    switch self {
    case .text(let value), .date(let value), .selection(let value): value
    case .number(let value): Self.format(value)
    case .boolean(let value): value ? "Yes" : "No"
    case .range(let low, let high): "\(Self.format(low)) – \(Self.format(high))"
    case .duration(let value, let unit): "\(Self.format(value)) \(unit)"
    case .entity(let id): id
    case .selections(let values), .entities(let values):
      values.isEmpty ? "None" : values.joined(separator: ", ")
    case .coordinates(let x, let y, let unit): "\(Self.format(x)), \(Self.format(y)) \(unit)"
    case .media(let name, _, _): name
    case .unknown: "Unknown"
    }
  }
  public static func format(_ value: Double) -> String {
    guard value != 0 else { return "0" }
    if abs(value) < 0.000001 || abs(value) >= 1_000_000_000_000 {
      return String(format: "%.15g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    return value.formatted(.number.precision(.significantDigits(1...15)))
  }
}
public struct EntityFieldCondition: Codable, Equatable, Sendable {
  public var field: String
  public var equals: EntityValue
  public init(field: String, equals: EntityValue) {
    self.field = field
    self.equals = equals
  }
}
public struct EntityField: Codable, Equatable, Identifiable, Sendable {
  public var id: String { key }
  public var key: String
  public var label: String
  public var kind: EntityFieldKind
  public var note: String
  public var options: [String]
  public var formula: String
  public var condition: EntityFieldCondition?
  public init(
    key: String, label: String, kind: EntityFieldKind = .text, note: String = "",
    options: [String] = [], formula: String = "", condition: EntityFieldCondition? = nil
  ) {
    self.key = key
    self.label = label
    self.kind = kind
    self.note = note
    self.options = options
    self.formula = formula
    self.condition = condition
  }
}
public struct EntityType: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var worldID: String
  public var name: String
  public var description: String
  public var parentTypeID: String?
  public var fields: [EntityField]
  public var defaults: [String: EntityValue]
  public var version: Int
  public var archived: Bool
  public var createdAt: String
  public var updatedAt: String
}
public struct EntityResolvedType: Equatable, Sendable {
  public var type: EntityType
  public var ancestors: [EntityType]
  public var fields: [EntityField]
  public var defaults: [String: EntityValue]
  public var sources: [String: String]
}
/// A frozen, reviewable view. Accepting it cannot be changed by a later schema/default edit.
public struct EntityPropertySnapshot: Codable, Equatable, Sendable {
  public var typeID: String
  public var typeName: String
  public var fields: [EntityField]
  public var values: [String: EntityValue]
  public var visibleKeys: [String]
}
public struct EntityProfile: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var worldID: String
  public var recordID: String
  public var typeID: String
  public var values: [String: EntityValue]
  public var canonical: EntityPropertySnapshot?
  public var version: Int
  public var createdAt: String
  public var updatedAt: String
}
public struct EntityProfileRevision: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var profile: EntityProfile
  public var createdAt: String
}
public struct EntityProfileReview: Equatable, Sendable {
  public var profile: EntityProfile
  public var snapshot: EntityPropertySnapshot
  public var issues: [String: String]
  /// Includes inherited schema versions as well as profile version: stale approvals cannot slip through.
  public var revision: String
  public var isCanon: Bool { profile.canonical == snapshot }
}
public struct EntityTemplate: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var worldID: String
  public var typeID: String
  public var name: String
  public var description: String
  public var body: String
  public var values: [String: EntityValue]
  public var version: Int
  public var archived: Bool
  public var createdAt: String
  public var updatedAt: String
}
