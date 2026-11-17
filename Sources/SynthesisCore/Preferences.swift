import Foundation

public enum DarkPalette: String, Codable, CaseIterable, Sendable {
  case graphite, oled
}

public enum InformationDensity: String, Codable, CaseIterable, Sendable {
  case compact, comfortable, immersive
}

public enum SendShortcut: String, Codable, CaseIterable, Sendable {
  case enter, commandEnter
}

/// One catalog for validation and Settings. Keep the persisted strings compatible with older builds.
public enum StartupWorkspace: String, CaseIterable, Sendable {
  case remember
  case conversation = "Conversation"
  case atlas = "Atlas"
  case dashboard = "Dashboard"
  case canvas = "Canvas"
  case library = "Library"
  case worlds = "Worlds"

  public var title: String {
    switch self {
    case .remember: "Last workspace"
    case .worlds: "Your worlds"
    default: rawValue
    }
  }
}

/// Local presentation preferences. These never change lore or the canon approval boundary.
public struct StudioPreferences: Codable, Equatable, Sendable {
  public var darkPalette = DarkPalette.graphite
  public var density = InformationDensity.comfortable
  public var bodySize = 16
  public var readingWidth = 780
  public var spellCheck = false
  public var smartQuotes = true
  public var smartDashes = true
  public var automaticLinks = true
  public var wordCount = true
  public var libraryPreviews = true
  public var sidebarCounts = true
  public var recentChats = 12
  public var launchWorkspace = "remember"
  public var sendShortcut = SendShortcut.enter
  public init() {}

  enum CodingKeys: String, CodingKey {
    case darkPalette, density
    case bodySize, readingWidth, spellCheck, smartQuotes, smartDashes, automaticLinks, wordCount
    case libraryPreviews, sidebarCounts, recentChats, launchWorkspace, sendShortcut
  }
  public init(from decoder: Decoder) throws {
    self.init()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    darkPalette = (try? c.decode(DarkPalette.self, forKey: .darkPalette)) ?? .graphite
    density = (try? c.decode(InformationDensity.self, forKey: .density)) ?? .comfortable
    bodySize = (try? c.decode(Int.self, forKey: .bodySize)) ?? bodySize
    readingWidth = (try? c.decode(Int.self, forKey: .readingWidth)) ?? readingWidth
    spellCheck = (try? c.decode(Bool.self, forKey: .spellCheck)) ?? spellCheck
    smartQuotes = (try? c.decode(Bool.self, forKey: .smartQuotes)) ?? smartQuotes
    smartDashes = (try? c.decode(Bool.self, forKey: .smartDashes)) ?? smartDashes
    automaticLinks = (try? c.decode(Bool.self, forKey: .automaticLinks)) ?? automaticLinks
    wordCount = (try? c.decode(Bool.self, forKey: .wordCount)) ?? wordCount
    libraryPreviews = (try? c.decode(Bool.self, forKey: .libraryPreviews)) ?? libraryPreviews
    sidebarCounts = (try? c.decode(Bool.self, forKey: .sidebarCounts)) ?? sidebarCounts
    recentChats = (try? c.decode(Int.self, forKey: .recentChats)) ?? recentChats
    launchWorkspace = (try? c.decode(String.self, forKey: .launchWorkspace)) ?? launchWorkspace
    sendShortcut = (try? c.decode(SendShortcut.self, forKey: .sendShortcut)) ?? sendShortcut
    self = validated
  }
  public var validated: Self {
    var value = self
    if ![14, 16, 18, 20].contains(bodySize) { value.bodySize = 16 }
    if ![640, 780, 960].contains(readingWidth) { value.readingWidth = 780 }
    if ![0, 5, 12, 20].contains(recentChats) { value.recentChats = 12 }
    if StartupWorkspace(rawValue: launchWorkspace) == nil {
      value.launchWorkspace = "remember"
    }
    return value
  }
}

public struct WorldPreferences: Codable, Equatable, Sendable {
  public var entityCategory = ""
  public var chatMode = "Create"
  public init() {}
  enum CodingKeys: String, CodingKey { case entityCategory, chatMode }
  public init(from decoder: Decoder) throws {
    self.init()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    entityCategory = (try? c.decode(String.self, forKey: .entityCategory)) ?? ""
    chatMode = (try? c.decode(String.self, forKey: .chatMode)) ?? "Create"
    self = validated
  }
  public var validated: Self {
    var value = self
    value.entityCategory = String(
      entityCategory.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    if !["Create", "Develop", "Critique", "Simulate", "Canonize"].contains(chatMode) {
      value.chatMode = "Create"
    }
    return value
  }
}

extension WorkspaceStore {
  public func studioPreferences() throws -> StudioPreferences {
    guard let raw = try preference("studio-preferences") else { return .init() }
    return (try? JSONDecoder().decode(StudioPreferences.self, from: Data(raw.utf8))) ?? .init()
  }
  public func setStudioPreferences(_ value: StudioPreferences) throws {
    try setPreference(
      "studio-preferences",
      value: String(decoding: JSONEncoder().encode(value.validated), as: UTF8.self))
  }
  public func worldPreferences(worldID: String) throws -> WorldPreferences {
    _ = try world(worldID)
    guard let raw = try preference("world-defaults:\(worldID)") else { return .init() }
    return (try? JSONDecoder().decode(WorldPreferences.self, from: Data(raw.utf8))) ?? .init()
  }
  public func setWorldPreferences(worldID: String, value: WorldPreferences) throws {
    _ = try world(worldID)
    try setPreference(
      "world-defaults:\(worldID)",
      value: String(decoding: JSONEncoder().encode(value.validated), as: UTF8.self))
  }
  /// Save world identity together so a failed description validation cannot partly rename it.
  public func updateWorldDetails(worldID: String, name: String, description: String) throws {
    try db.transaction {
      _ = try renameWorld(worldID, name: name)
      try setWorldDescription(worldID: worldID, description: description)
    }
  }
}
