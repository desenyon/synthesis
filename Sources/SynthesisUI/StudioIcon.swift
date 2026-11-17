import AppKit
import CoreText
import SwiftUI

/// Upstream Phosphor 2.1.2 regular glyphs, bundled offline under MIT. No SF Symbols fallback.
/// Aliases retain stable accessibility identifiers while presentation uses one icon family.
enum StudioIcons {
  static let registered: Bool = {
    let base = Bundle.main.resourceURL?.appendingPathComponent("Assets/Icons/Phosphor.ttf")
    let fallback = Bundle.module.resourceURL?.appendingPathComponent("Assets/Icons/Phosphor.ttf")
    guard
      let url = [base, fallback].compactMap({ $0 }).first(where: {
        FileManager.default.fileExists(atPath: $0.path)
      })
    else { return false }
    return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }()
  static let glyphs: [String: String] = [
    "rectangle.grid.2x2": "\u{e6d6}",
    "square": "\u{e45e}",
    "checkmark.square.fill": "\u{e186}",
    "tag": "\u{e478}",
    "arrow.left.arrow.right": "\u{e0a0}",
    "arrow.triangle.merge": "\u{e280}",
    "tuningfork": "\u{e27e}",
    "hexagon": "\u{e6d0}",
    "lifepreserver": "\u{e63a}",
    "arrow.counterclockwise": "\u{e038}",
    "square.on.square": "\u{e1ca}",
    "eye": "\u{e220}",
    "square.stack": "\u{e466}",
    "plus.magnifyingglass": "\u{e310}",
    "minus.magnifyingglass": "\u{e30e}",
    "archivebox": "\u{e00c}",
    "arrow.left": "\u{e058}",
    "arrow.right": "\u{e06c}",
    "arrow.triangle.branch": "\u{e278}",
    "arrow.up": "\u{e08e}",
    "arrow.up.arrow.down": "\u{e098}",
    "arrow.up.forward": "\u{e092}",
    "arrow.up.left.and.arrow.down.right": "\u{e0a2}",
    "arrow.up.right.circle": "\u{e034}",
    "at": "\u{e0ac}",
    "bold": "\u{e5be}",
    "bolt": "\u{e2de}",
    "bolt.slash": "\u{e2e0}",
    "books.vertical": "\u{e758}",
    "bubble.left": "\u{e168}",
    "calendar": "\u{e108}",
    "calendar.badge.exclamationmark": "\u{e10c}",
    "calendar.day.timeline.left": "\u{e19a}",
    "checkmark": "\u{e182}",
    "checkmark.circle": "\u{e184}",
    "checkmark.seal": "\u{e606}",
    "chevron.down": "\u{e136}",
    "chevron.left": "\u{e138}",
    "chevron.right": "\u{e13a}",
    "chevron.up.chevron.down": "\u{e140}",
    "circle": "\u{e18a}",
    "circle.dashed": "\u{e602}",
    "circle.hexagongrid": "\u{e2ae}",
    "clock.arrow.circlepath": "\u{e1a0}",
    "command": "\u{e1c4}",
    "doc.badge.plus": "\u{e236}",
    "doc.on.doc": "\u{e1ca}",
    "doc.text": "\u{e23a}",
    "ellipsis": "\u{e1fe}",
    "exclamationmark.circle": "\u{e4e2}",
    "exclamationmark.magnifyingglass": "\u{e30c}",
    "exclamationmark.triangle": "\u{e4e0}",
    "eye.slash": "\u{e224}",
    "file-text": "\u{e23a}",
    "flag": "\u{e244}",
    "folder": "\u{e24a}",
    "gearshape": "\u{e272}",
    "globe": "\u{e28c}",
    "hand.raised": "\u{e298}",
    "italic": "\u{e5c0}",
    "largecircle.fill.circle": "\u{eb08}",
    "layers": "\u{e466}",
    "lightbulb": "\u{e2dc}",
    "link": "\u{e2e2}",
    "link.badge.plus": "\u{e2e6}",
    "lock.shield": "\u{e40c}",
    "magnifyingglass": "\u{e30c}",
    "map": "\u{e31a}",
    "mappin.and.ellipse": "\u{e316}",
    "mappin.circle.fill": "\u{ee3a}",
    "messages-square": "\u{e17e}",
    "minus": "\u{e32a}",
    "minus.circle": "\u{e32c}",
    "moon": "\u{e330}",
    "network": "\u{eb58}",
    "palette": "\u{e6c8}",
    "panel-left": "\u{ec24}",
    "paperclip": "\u{e39a}",
    "pencil.line": "\u{e3b2}",
    "person": "\u{e4c2}",
    "person.2": "\u{e68e}",
    "photo": "\u{e2ca}",
    "play.circle": "\u{e3d2}",
    "plus": "\u{e3d4}",
    "point.3.connected.trianglepath.dotted": "\u{eb58}",
    "questionmark.circle": "\u{e3e8}",
    "rectangle.on.rectangle": "\u{e464}",
    "search": "\u{e30c}",
    "settings-2": "\u{e272}",
    "sidebar.left": "\u{ec24}",
    "sidebar.right": "\u{eab6}",
    "sliders-horizontal": "\u{e434}",
    "sparkles": "\u{e6a2}",
    "square.and.arrow.down": "\u{e20c}",
    "square.and.arrow.up": "\u{eaf0}",
    "square.and.pencil": "\u{e34c}",
    "square.dashed": "\u{e69a}",
    "square.stack.3d.up": "\u{e466}",
    "stop.fill": "\u{e46c}",
    "sun": "\u{e472}",
    "sun.max": "\u{e472}",
    "textformat": "\u{e6ee}",
    "tray": "\u{e4aa}",
    "underline": "\u{e5c4}",
    "viewfinder": "\u{e1d0}",
    "wand-sparkles": "\u{e6b6}",
    "xmark": "\u{e4f6}",
    "xmark.circle": "\u{e4f8}",
    "xmark.circle.fill": "\u{e4f8}",
  ]
}
struct StudioIcon: View {
  let name: String
  var size: CGFloat
  init(_ name: String, size: CGFloat = 16) {
    self.name = name
    self.size = size
  }
  var body: some View {
    let _ = StudioIcons.registered
    Text(StudioIcons.glyphs[name] ?? StudioIcons.glyphs["circle"]!)
      .font(.custom("Phosphor", size: size)).frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}
struct StudioLabel: View {
  let title: String
  let icon: String
  init(_ title: String, icon: String) {
    self.title = title
    self.icon = icon
  }
  var body: some View {
    Label {
      Text(title)
    } icon: {
      StudioIcon(icon)
    }
  }
}
