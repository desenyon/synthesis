import SwiftUI
import SynthesisCore

/// Graphite design tokens. Every surface, text level and semantic accent in the app resolves here
/// so the light and dark themes stay complete counterparts.
public struct Theme {
  public let dark: Bool
  public var background: Color { Color(hex: dark ? 0x141617 : 0xF8F9FB) }
  public var sidebar: Color { Color(hex: dark ? 0x1B1D1E : 0xF0F2F5) }
  public var surface: Color { Color(hex: dark ? 0x232525 : 0xFFFFFF) }
  public var secondarySurface: Color { Color(hex: dark ? 0x2D302F : 0xECEFF3) }
  public var text: Color { Color(hex: dark ? 0xECEBED : 0x20232B) }
  public var secondary: Color { Color(hex: dark ? 0xBEC5CE : 0x5C6573) }
  public var muted: Color { Color(hex: dark ? 0x929CAA : 0x7D8593) }
  public var border: Color { Color(hex: dark ? 0x3A3E3D : 0xDCE1E8) }
  public var accent: Color { Color(hex: dark ? 0xB7D4C1 : 0x3B637F) }
  public var accentSoft: Color { Color(hex: dark ? 0x29362F : 0xE3ECF3) }
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
    switch name.lowercased() {
    case "characters": return Color(hex: dark ? 0xD7B899 : 0x866042)
    case "factions": return Color(hex: dark ? 0xB7B6E0 : 0x655A96)
    case "places": return Color(hex: dark ? 0x9CC7B5 : 0x3B7461)
    case "power systems": return Color(hex: dark ? 0xD4C48F : 0x7A6A2E)
    case "cosmology": return Color(hex: dark ? 0xC9A9D6 : 0x7B5391)
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
  static let sidebar: CGFloat = 220
  static let rail: CGFloat = 56
  static let control: CGFloat = 30
  static let radius: CGFloat = 8
  static let cardRadius: CGFloat = 12
  static let panelRadius: CGFloat = 14
  /// Width reserved at the top-left for the window controls and navigation toggle.
  static let chrome: CGFloat = 124
}

enum Vocabulary {
  static let categories = ["Characters", "Factions", "Places", "Power systems", "Cosmology"]
  static let modes: [(name: String, icon: String, summary: String)] = [
    ("Create", "sparkles", "Brainstorm freely. Everything stays a suggestion."),
    ("Develop", "arrow.up.right.circle", "Deepen an existing idea within its constraints."),
    ("Critique", "exclamationmark.magnifyingglass", "Find conflicts, gaps and consequences."),
    ("Simulate", "play.circle", "Explore a what-if with stated assumptions."),
    ("Canonize", "checkmark.seal", "Prepare a change for you to review and accept."),
  ]
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
  switch category.lowercased() {
  case "characters": return "person"
  case "factions": return "flag"
  case "places": return "mappin.and.ellipse"
  case "power systems": return "bolt"
  case "cosmology": return "sparkles"
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
