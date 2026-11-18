import Foundation

/// Creator-authored properties of one connection. Fictional status and secrecy are
/// independent of canon approval and device privacy settings.
public struct RelationshipAttributes: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, CaseIterable, Sendable {
    case unknown, mentor, politicalSuperior, legalGuardian, formerAlly, rival, other
    public var title: String {
      switch self {
      case .politicalSuperior: "Political superior"
      case .legalGuardian: "Legal guardian"
      case .formerAlly: "Former ally"
      default: rawValue.capitalized
      }
    }
  }

  public enum Strength: String, Codable, CaseIterable, Sendable {
    case unknown, weak, moderate, strong
    public var title: String { rawValue.capitalized }
  }

  public enum Secrecy: String, Codable, CaseIterable, Sendable {
    case unknown, publicKnowledge, restricted, secret
    public var title: String {
      self == .publicKnowledge ? "Public knowledge" : rawValue.capitalized
    }
  }

  public enum Mutuality: String, Codable, CaseIterable, Sendable {
    case unknown, oneSided, mutual
    public var title: String { self == .oneSided ? "One-sided" : rawValue.capitalized }
  }

  public enum Status: String, Codable, CaseIterable, Sendable {
    case unknown, active, suspended, ended, disputed
    public var title: String { rawValue.capitalized }
  }

  public var kind: Kind = .unknown
  public var startLabel = ""
  public var endLabel = ""
  public var strength: Strength = .unknown
  public var secrecy: Secrecy = .unknown
  public var mutuality: Mutuality = .unknown
  public var status: Status = .unknown
  public var evidenceRecordIDs: [String] = []

  public static let dateLabelLimit = 160
  public static let evidenceLimit = 12
  public init() {}

  private enum CodingKeys: String, CodingKey {
    case kind, startLabel, endLabel, strength, secrecy, mutuality, status, evidenceRecordIDs
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    kind = try values.decodeIfPresent(Kind.self, forKey: .kind) ?? .unknown
    startLabel = try values.decodeIfPresent(String.self, forKey: .startLabel) ?? ""
    endLabel = try values.decodeIfPresent(String.self, forKey: .endLabel) ?? ""
    strength = try values.decodeIfPresent(Strength.self, forKey: .strength) ?? .unknown
    secrecy = try values.decodeIfPresent(Secrecy.self, forKey: .secrecy) ?? .unknown
    mutuality = try values.decodeIfPresent(Mutuality.self, forKey: .mutuality) ?? .unknown
    status = try values.decodeIfPresent(Status.self, forKey: .status) ?? .unknown
    evidenceRecordIDs = try values.decodeIfPresent([String].self, forKey: .evidenceRecordIDs) ?? []
  }

  func validated() throws -> Self {
    var value = self
    value.startLabel = startLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    value.endLabel = endLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      [value.startLabel, value.endLabel].allSatisfy({
        $0.count <= Self.dateLabelLimit && $0.utf8.count <= 2048 && !$0.contains("\0")
      })
    else {
      throw SynthesisError.invalid(
        "Enter start and end labels of up to \(Self.dateLabelLimit) characters.")
    }
    guard evidenceRecordIDs.count <= Self.evidenceLimit,
      Set(evidenceRecordIDs).count == evidenceRecordIDs.count,
      evidenceRecordIDs.allSatisfy({ UUID(uuidString: $0) != nil })
    else {
      throw SynthesisError.invalid("Choose up to \(Self.evidenceLimit) different evidence records.")
    }
    return value
  }

  static func decodeStored(_ raw: String) throws -> Self {
    if raw == "{}" { return .init() }
    guard raw.utf8.count <= 32_768 else {
      throw SynthesisError.invalid("The saved relationship attributes are too large.")
    }
    return try JSONDecoder().decode(Self.self, from: Data(raw.utf8)).validated()
  }

  func encodeStored() throws -> String {
    if self == .init() { return "{}" }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(self), as: UTF8.self)
  }
}
