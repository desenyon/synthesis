import AppKit
import CoreText
import SwiftUI

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
  static func studio(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default)
    -> Font
  {
    if design == .monospaced { return .system(size: size, weight: weight, design: design) }
    let _ = StudioTypography.registered
    return .custom(StudioTypography.name(weight), fixedSize: size)
  }
}

/// Deterministic sidebar surface. Native adaptive glass can invert against desktop content.
struct NavigationGlass: View {
  let theme: Theme
  var body: some View {
    theme.sidebar
      .overlay(alignment: .trailing) { theme.hairline.frame(width: 1) }
  }
}
