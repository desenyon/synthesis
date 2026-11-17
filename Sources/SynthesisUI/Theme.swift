import SwiftUI
import SynthesisCore

/// Graphite design tokens. Every surface, text level and semantic accent in the app resolves here
/// so the light and dark themes stay complete counterparts.
public struct Theme {
  public let dark: Bool
  public var oled = false
  public var canvasTheme: String { dark ? (oled ? "oled" : "dark") : "light" }
  public var background: Color { Color(hex: dark ? (oled ? 0x000000 : 0x111315) : 0xF8F9FB) }
  public var sidebar: Color { navigation.background }
  var navigation: SidebarPalette { SidebarPalette(dark: dark) }
  public var surface: Color { Color(hex: dark ? (oled ? 0x111111 : 0x1A1D21) : 0xFFFFFF) }
  public var secondarySurface: Color { Color(hex: dark ? (oled ? 0x1B1B1B : 0x24282E) : 0xECEFF3) }
  public var text: Color { Color(hex: dark ? 0xE6E9EF : 0x20232B) }
  public var secondary: Color { Color(hex: dark ? 0xB6BBC5 : 0x5C6573) }
  public var muted: Color { Color(hex: dark ? 0x8F96A3 : 0x7D8593) }
  public var border: Color { Color(hex: dark ? (oled ? 0x2A2A2A : 0x353B43) : 0xDCE1E8) }
  public var accent: Color { Color(hex: dark ? 0xA9C7FF : 0x456B9D) }
  public var accentSoft: Color { Color(hex: dark ? 0x252D3B : 0xE3ECF3) }
  /// Text or icon colour placed on a filled accent control.
  public var onAccent: Color { dark ? Color(hex: 0x14181C) : .white }
  public var hover: Color { text.opacity(dark ? 0.06 : 0.05) }
  public var pressed: Color { text.opacity(dark ? 0.1 : 0.08) }
  public var hairline: Color { border.opacity(dark ? 0.6 : 0.8) }
  public var positive: Color { Color(hex: dark ? 0x8FC3A6 : 0x2F7653) }
  public var warning: Color { Color(hex: dark ? 0xDDB878 : 0x8F6312) }
  public var danger: Color { Color(hex: dark ? 0xE59A93 : 0xB3433B) }
  public var scrim: Color { Color.black.opacity(dark ? 0.45 : 0.22) }
  public var shadow: Color { Color.black.opacity(dark ? 0.32 : 0.1) }

  /// Muted semantic accent for a worldbuilding category.
  public func category(_ name: String) -> Color {
    switch Vocabulary.categoryKey(name) {
    case "characters": return Color(hex: dark ? 0xD7B899 : 0x866042)
    case "factions", "systems": return Color(hex: dark ? 0xB7B6E0 : 0x655A96)
    case "places": return Color(hex: dark ? 0x9CC7B5 : 0x3B7461)
    case "power systems": return Color(hex: dark ? 0xD4C48F : 0x7A6A2E)
    case "cosmology": return Color(hex: dark ? 0xC9A9D6 : 0x7B5391)
    case "events": return Color(hex: dark ? 0x9BBCCD : 0x46677A)
    default: return accent
    }
  }
  public func state(_ value: String) -> Color {
    switch value {
    case "canon": return positive
    case "hypothetical": return warning
    case "idea": return muted
    default: return accent
    }
  }
}
extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255, opacity: 1)
  }
}

/// Shared geometry. Radii and control heights are deliberately few.
enum Metric {
  static let bar: CGFloat = 56
  static let sidebar: CGFloat = 284
  static let rail: CGFloat = 72
  static let control: CGFloat = 30
  static let radius: CGFloat = 8
  static let cardRadius: CGFloat = 12
  static let panelRadius: CGFloat = 14
  static let smallRadius: CGFloat = 7
  static let floatingRadius: CGFloat = 10
  static let contentInset: CGFloat = 28
  static let contentWidth: CGFloat = 880
  /// Width reserved at the top-left for the window controls and navigation toggle.
  static let chrome: CGFloat = 124
}

/// Four-point rhythm for shared controls and page composition.
enum Space {
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let xl: CGFloat = 24
  static let xxl: CGFloat = 32
}

/// Presentation density never resizes authored canvas geometry or reformats document text.
struct DensityMetric {
  let value: InformationDensity
  private func choose(_ compact: CGFloat, _ comfortable: CGFloat, _ immersive: CGFloat) -> CGFloat {
    switch value {
    case .compact: compact
    case .comfortable: comfortable
    case .immersive: immersive
    }
  }
  var navigationRow: CGFloat { choose(32, SidebarMetric.row, 44) }
  var historyRow: CGFloat { choose(28, SidebarMetric.history, 40) }
  var libraryRow: CGFloat { choose(46, 54, 72) }
  var thumbnail: CGFloat { choose(28, 34, 44) }
  var inset: CGFloat { choose(20, Metric.contentInset, 36) }
  var sectionGap: CGFloat { choose(8, 12, 16) }
  var contentGap: CGFloat { choose(16, 24, 32) }
  var cardGap: CGFloat { choose(8, 14, 20) }
  var cardInset: CGFloat { choose(14, 20, 28) }
  var cardWidth: CGFloat { choose(220, 260, 340) }
}

private struct StudioDensityKey: EnvironmentKey {
  static let defaultValue = DensityMetric(value: .comfortable)
}
extension EnvironmentValues {
  var studioDensity: DensityMetric {
    get { self[StudioDensityKey.self] }
    set { self[StudioDensityKey.self] = newValue }
  }
}

enum Motion {
  static let feedback = 0.15
  static let panel = 0.22
  static let workspace = 0.22
  static var feedbackAnimation: Animation { .easeOut(duration: feedback) }
  static var panelAnimation: Animation { .easeInOut(duration: panel) }
  static var workspaceAnimation: Animation { .easeInOut(duration: workspace) }
  static var panelTransition: AnyTransition { .opacity.combined(with: .offset(x: 8)) }
  static var companionTransition: AnyTransition {
    .opacity.combined(with: .scale(scale: 0.98, anchor: .bottomTrailing)).combined(
      with: .offset(y: 8))
  }
}

/// Shadow geometry belongs to the surface role, not an individual workspace.
enum Elevation {
  case floating, card, companion, composer, compactComposer
  var radius: CGFloat {
    switch self {
    case .floating: 14
    case .card: 12
    case .companion: 24
    case .composer, .compactComposer: 16
    }
  }
  var offset: CGFloat {
    switch self {
    case .card: 4
    case .companion: 8
    default: 6
    }
  }
  var opacity: Double {
    switch self {
    case .floating: 0.6
    case .card: 1
    case .companion: 0.7
    case .composer: 0.25
    case .compactComposer: 0.5
    }
  }
}

/// Navigation is neutral; artwork and the workspace retain their own semantic colour.
struct SidebarPalette {
  let dark: Bool
  var background: Color { Color(hex: dark ? 0x121416 : 0xEFF1F4) }
  var elevated: Color { Color(hex: dark ? 0x1C1F22 : 0xFAFBFC) }
  var selected: Color { Color(hex: dark ? 0x2B3035 : 0xDDE2E8) }
  var text: Color { Color(hex: dark ? 0xEBEDF0 : 0x20262E) }
  var secondary: Color { Color(hex: dark ? 0xB9BEC6 : 0x505B69) }
  var muted: Color { Color(hex: dark ? 0x929AA5 : 0x596575) }
  var hover: Color { text.opacity(dark ? 0.055 : 0.045) }
  var pressed: Color { text.opacity(0.10) }
  var edge: Color { (dark ? Color.white : .black).opacity(dark ? 0.07 : 0.08) }
  var focus: Color { Color(hex: dark ? 0xBDCBDD : 0x526A87) }
}

enum SidebarMetric {
  static let inset: CGFloat = 16
  static let row: CGFloat = 38
  static let action: CGFloat = 36
  static let history: CGFloat = 34
  static let icon: CGFloat = 17
  static let radius: CGFloat = 8
  static let section: CGFloat = 24
  static let transition: Double = 0.15
}

enum Vocabulary {
  static let categories = ["Characters", "Systems", "Places", "Power systems", "Cosmology"]
  static let modes: [(name: String, icon: String, summary: String)] = [
    ("Create", "sparkles", "Brainstorm freely. Everything stays a suggestion."),
    ("Develop", "arrow.up.right.circle", "Deepen an existing idea within its constraints."),
    ("Critique", "exclamationmark.magnifyingglass", "Find conflicts, gaps and consequences."),
    ("Simulate", "play.circle", "Explore a what-if with stated assumptions."),
    ("Canonize", "checkmark.seal", "Prepare a change for you to review and accept."),
  ]
  /// Display vocabulary only: imported and saved categories are never rewritten.
  static func displayCategory(_ value: String) -> String {
    value == "Factions" ? "Systems" : value
  }
  /// Visual aliases only. Original creator/imported category names remain untouched.
  static func categoryKey(_ value: String) -> String {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "character", "characters": "characters"
    case "faction", "factions", "system", "systems": "systems"
    case "place", "places", "location", "locations": "places"
    case "power system", "power systems", "magic system", "magic systems": "power systems"
    case "event", "events", "historical events", "history": "events"
    case "idea", "ideas": "ideas"
    default: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
  }
  static func matchesCategory(_ value: String, _ category: String) -> Bool {
    value == category || (category == "Systems" && value == "Factions")
  }
  static func kindLabel(_ kind: String) -> String {
    switch kind {
    case "entity": return "Entity"
    case "capture": return "Idea"
    default: return "Document"
    }
  }
  static func stateLabel(_ state: String) -> String {
    switch state {
    case "canon": return "Canon"
    case "idea": return "Idea"
    case "hypothetical": return "Hypothetical"
    default: return "Draft"
    }
  }
  static func originLabel(_ origin: String) -> String {
    switch origin {
    case "ai-proposed": return "AI-proposed"
    case "imported": return "Imported"
    case "inferred": return "Inferred"
    default: return "Written by you"
    }
  }
}

func categoryIcon(_ category: String) -> String {
  switch Vocabulary.categoryKey(category) {
  case "characters": return "person"
  case "factions", "systems": return "flag"
  case "places": return "mappin.and.ellipse"
  case "power systems": return "bolt"
  case "cosmology": return "sparkles"
  case "events": return "calendar"
  case "ideas": return "lightbulb"
  default: return "doc.text"
  }
}
func recordIcon(_ record: LoreRecord) -> String {
  if !record.category.isEmpty, categoryIcon(record.category) != "doc.text" {
    return categoryIcon(record.category)
  }
  switch record.kind {
  case "entity": return "circle.hexagongrid"
  case "capture": return "lightbulb"
  default: return "doc.text"
  }
}

private let isoParser: ISO8601DateFormatter = ISO8601DateFormatter()
/// Compact relative label for a stored ISO-8601 timestamp; empty when the value is unreadable.
func relativeDate(_ iso: String) -> String {
  guard let date = isoParser.date(from: iso) else { return "" }
  let seconds = Date().timeIntervalSince(date)
  if seconds < 60 { return "Just now" }
  if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
  if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
  if seconds < 86400 * 7 { return "\(Int(seconds / 86400))d ago" }
  let formatter = DateFormatter()
  formatter.dateFormat =
    Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
  return formatter.string(from: date)
}

/// Shared full/companion composer geometry. Compact workspace bars use the smaller radius.
enum ComposerMetric {
  static let radius: CGFloat = 20
  static let compactRadius: CGFloat = 16
  static let inset: CGFloat = 16
  static let control: CGFloat = 32
  static let bodySize: CGFloat = 16
  static let transition: Double = 0.16
}

private struct StudioThemeKey: EnvironmentKey {
  static let defaultValue: Theme? = nil
}
private struct OpaqueMaterialsKey: EnvironmentKey {
  static let defaultValue = false
}
extension EnvironmentValues {
  var studioTheme: Theme? {
    get { self[StudioThemeKey.self] }
    set { self[StudioThemeKey.self] = newValue }
  }
  var studioOpaqueMaterials: Bool {
    get { self[OpaqueMaterialsKey.self] }
    set { self[OpaqueMaterialsKey.self] = newValue }
  }
}
