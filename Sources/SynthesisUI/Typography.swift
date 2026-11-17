import AppKit
import CoreText
import SwiftUI

/// Semantic type roles, shared by native pages and controls. Rich document text retains
/// the creator's saved font size; these roles describe application chrome and hierarchy.
enum TextRole {
  case title, section, cardTitle, body, control, label, caption, captionStrong, sectionLabel
  var size: CGFloat {
    switch self {
    case .title: 30
    case .section: 20
    case .cardTitle, .body: 16
    case .control: 14
    case .label: 13
    case .caption, .captionStrong: 12
    case .sectionLabel: 11
    }
  }
  var weight: Font.Weight {
    switch self {
    case .title, .section, .cardTitle, .sectionLabel: .semibold
    case .control, .label, .captionStrong: .medium
    case .body, .caption: .regular
    }
  }
}

/// One locally bundled type family in native controls and the offline canvas.
enum StudioTypography {
  static let registered: Void = {
    for weight in ["Regular", "Medium", "SemiBold", "Bold"] {
      let path = "Assets/Fonts/Inter-\(weight).otf"
      for bundle in [Bundle.main, Bundle.module] {
        if let url = bundle.resourceURL?.appendingPathComponent(path),
          FileManager.default.fileExists(atPath: url.path)
        {
          CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
          break
        }
      }
    }
  }()
  static func native(size: CGFloat, bold: Bool = false) -> NSFont {
    let _ = registered
    return NSFont(name: bold ? "Inter-SemiBold" : "Inter-Regular", size: size)
      ?? .systemFont(ofSize: size)
  }
  static func name(_ weight: Font.Weight) -> String {
    if weight == .bold || weight == .heavy || weight == .black { return "Inter-Bold" }
    if weight == .semibold { return "Inter-SemiBold" }
    if weight == .medium { return "Inter-Medium" }
    return "Inter-Regular"
  }
}
extension Font {
  static func studio(_ role: TextRole) -> Font {
    studio(size: role.size, weight: role.weight)
  }

  static func studio(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default)
    -> Font
  {
    if design == .monospaced { return .system(size: size, weight: weight, design: design) }
    let _ = StudioTypography.registered
    return .custom(StudioTypography.name(weight), fixedSize: size)
  }
}
