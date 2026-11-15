import AppKit
import CoreText
import SwiftUI

/// Upstream Lucide 1.73.0 glyphs, bundled offline under ISC. No SF Symbols fallback.
/// Aliases retain stable accessibility identifiers while presentation uses one icon family.
enum StudioIcons {
  static let registered: Bool = {
    let base = Bundle.main.resourceURL?.appendingPathComponent("Assets/Icons/lucide.ttf")
    let fallback = Bundle.module.resourceURL?.appendingPathComponent("Assets/Icons/lucide.ttf")
    guard
      let url = [base, fallback].compactMap({ $0 }).first(where: {
        FileManager.default.fileExists(atPath: $0.path)
      })
    else { return false }
    return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }()
  static let glyphs: [String: String] = [
    "archivebox": "\u{e041}",
    "arrow.left": "\u{e048}",
    "arrow.right": "\u{e049}",
    "arrow.triangle.branch": "\u{e0e2}",
    "arrow.up": "\u{e04a}",
    "arrow.up.arrow.down": "\u{e046}",
    "arrow.up.forward": "\u{e04d}",
    "arrow.up.left.and.arrow.down.right": "\u{e11b}",
    "arrow.up.right.circle": "\u{e04d}",
    "at": "\u{e04e}",
    "bold": "\u{e05d}",
    "bolt": "\u{e1b4}",
    "bolt.slash": "\u{e1b5}",
    "books.vertical": "\u{e100}",
    "bubble.left": "\u{e40d}",
    "calendar": "\u{e063}",
    "calendar.badge.exclamationmark": "\u{e304}",
    "calendar.day.timeline.left": "\u{e1f5}",
    "checkmark": "\u{e06c}",
    "checkmark.circle": "\u{e226}",
    "checkmark.seal": "\u{e241}",
    "chevron.down": "\u{e06d}",
    "chevron.left": "\u{e06e}",
    "chevron.right": "\u{e06f}",
    "chevron.up.chevron.down": "\u{e211}",
    "circle": "\u{e076}",
    "circle.dashed": "\u{e4b0}",
    "circle.hexagongrid": "\u{e4b3}",
    "clock.arrow.circlepath": "\u{e1f5}",
    "command": "\u{e09a}",
    "doc.badge.plus": "\u{e0ca}",
    "doc.on.doc": "\u{e09e}",
    "doc.text": "\u{e0cc}",
    "ellipsis": "\u{e0b6}",
    "exclamationmark.circle": "\u{e077}",
    "exclamationmark.magnifyingglass": "\u{e537}",
    "exclamationmark.triangle": "\u{e193}",
    "eye.slash": "\u{e0bb}",
    "file-text": "\u{e0cc}",
    "flag": "\u{e0d1}",
    "folder": "\u{e0d7}",
    "gearshape": "\u{e245}",
    "globe": "\u{e0e8}",
    "hand.raised": "\u{e1d7}",
    "italic": "\u{e0fb}",
    "largecircle.fill.circle": "\u{e345}",
    "layers": "\u{e529}",
    "lightbulb": "\u{e1c2}",
    "link": "\u{e102}",
    "link.badge.plus": "\u{e103}",
    "lock.shield": "\u{e1ff}",
    "magnifyingglass": "\u{e151}",
    "map": "\u{e110}",
    "mappin.and.ellipse": "\u{e111}",
    "mappin.circle.fill": "\u{e111}",
    "messages-square": "\u{e40d}",
    "minus": "\u{e11c}",
    "minus.circle": "\u{e07e}",
    "moon": "\u{e11e}",
    "network": "\u{e125}",
    "palette": "\u{e1dd}",
    "panel-left": "\u{e12a}",
    "paperclip": "\u{e12d}",
    "pencil.line": "\u{e172}",
    "person": "\u{e468}",
    "person.2": "\u{e46e}",
    "photo": "\u{e0f6}",
    "play.circle": "\u{e080}",
    "plus": "\u{e13d}",
    "point.3.connected.trianglepath.dotted": "\u{e125}",
    "questionmark.circle": "\u{e082}",
    "rectangle.on.rectangle": "\u{e12c}",
    "search": "\u{e151}",
    "settings-2": "\u{e245}",
    "sidebar.left": "\u{e12a}",
    "sidebar.right": "\u{e431}",
    "sliders-horizontal": "\u{e29a}",
    "sparkles": "\u{e412}",
    "square.and.arrow.down": "\u{e0b2}",
    "square.and.arrow.up": "\u{e19e}",
    "square.and.pencil": "\u{e172}",
    "square.dashed": "\u{e1cb}",
    "square.stack.3d.up": "\u{e529}",
    "stop.fill": "\u{e167}",
    "sun": "\u{e178}",
    "sun.max": "\u{e178}",
    "textformat": "\u{e198}",
    "tray": "\u{e0f7}",
    "underline": "\u{e19a}",
    "viewfinder": "\u{e257}",
    "wand-sparkles": "\u{e357}",
    "xmark": "\u{e1b2}",
    "xmark.circle": "\u{e084}",
    "xmark.circle.fill": "\u{e084}",
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
      .font(.custom("lucide", size: size)).frame(width: size, height: size)
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
