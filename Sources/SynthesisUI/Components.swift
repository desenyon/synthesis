import AppKit
import SwiftUI
import SynthesisCore

/// One shared reading edge for content browsers, their filters and section headings.
struct ContentColumn<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 0, content: content)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 28)
      .frame(maxWidth: 880)
      .frame(maxWidth: .infinity)
  }
}

struct ContentHeader<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    ContentColumn { HStack(spacing: 8, content: content) }
      .padding(.vertical, 10)
  }
}

/// A scroll cue that disappears once the remaining content is visible.
struct BottomOverflowFade: ViewModifier {
  let active: Bool
  func body(content: Content) -> some View {
    content.mask {
      VStack(spacing: 0) {
        Rectangle().fill(.black)
        if active {
          LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: 16)
        }
      }
    }
  }
}

// MARK: Buttons

/// Text button used across bars, sheets and empty states.
struct QuietButton: ButtonStyle {
  enum Role { case secondary, primary, ghost, danger }
  let t: Theme
  var role: Role = .secondary
  init(t: Theme, primary: Bool = false) {
    self.t = t
    role = primary ? .primary : .secondary
  }
  init(t: Theme, role: Role) {
    self.t = t
    self.role = role
  }
  func makeBody(configuration: Configuration) -> some View {
    Surface(t: t, role: role, configuration: configuration)
  }
  struct Surface: View {
    let t: Theme
    let role: Role
    let configuration: Configuration
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled
    var body: some View {
      configuration.label.font(.studio(size: 13, weight: .medium)).lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 12).frame(height: Metric.control)
        .foregroundStyle(foreground)
        .background(fill, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(
          RoundedRectangle(cornerRadius: Metric.radius).stroke(
            role == .secondary ? t.hairline : .clear, lineWidth: 1)
        )
        .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
        .contentShape(RoundedRectangle(cornerRadius: Metric.radius))
        .onHover { hover = $0 }
    }
    private var foreground: Color {
      switch role {
      case .primary: return t.onAccent
      case .danger: return t.danger
      default: return t.text
      }
    }
    private var fill: Color {
      switch role {
      case .primary: return t.accent.opacity(hover && enabled ? 0.9 : 1)
      case .secondary: return hover && enabled ? t.secondarySurface : t.surface
      case .ghost, .danger: return hover && enabled ? t.hover : .clear
      }
    }
  }
}

struct IconButton: View {
  var icon: String
  var label: String
  var t: Theme
  var active = false
  var size: CGFloat = 28
  var action: () -> Void
  @State private var hover = false
  @Environment(\.isEnabled) private var enabled
  var body: some View {
    Button(action: action) {
      StudioIcon(icon, size: size * 0.5)
        .foregroundStyle(active ? t.accent : (hover ? t.text : t.secondary))
        .frame(width: size, height: size)
        .background(
          active ? t.accentSoft : (hover && enabled ? t.hover : .clear),
          in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .opacity(enabled ? 1 : 0.35)
    }.buttonStyle(.plain).onHover { hover = $0 }.help(label).accessibilityLabel(label)
  }
}

/// Custom-drawn label that opens a native menu.
struct PlainMenu<Label: View, Items: View>: View {
  /// Flexible menus may shrink so a long title truncates instead of widening its bar.
  var flexible = false
  @ViewBuilder var items: () -> Items
  @ViewBuilder var label: () -> Label
  var body: some View {
    Menu(content: items, label: label).menuStyle(.button).buttonStyle(.plain)
      .menuIndicator(.hidden).fixedSize(horizontal: !flexible, vertical: true)
  }
}

/// Icon-sized menu trigger that matches `IconButton`.
struct IconMenu<Items: View>: View {
  var icon: String
  var label: String
  var t: Theme
  var size: CGFloat = 28
  @ViewBuilder var items: () -> Items
  @State private var hover = false
  var body: some View {
    PlainMenu(items: items) {
      StudioIcon(icon, size: size * 0.5)
        .foregroundStyle(hover ? t.text : t.secondary).frame(width: size, height: size)
        .background(hover ? t.hover : .clear, in: RoundedRectangle(cornerRadius: 7))
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }.onHover { hover = $0 }.help(label).accessibilityLabel(label)
  }
}

/// Adds the standard row hover fill.
struct HoverFill: ViewModifier {
  let t: Theme
  var radius: CGFloat = 7
  var selected = false
  @State private var hover = false
  func body(content: Content) -> some View {
    content.background(
      selected ? t.secondarySurface : (hover ? t.hover : .clear),
      in: RoundedRectangle(cornerRadius: radius)
    ).contentShape(RoundedRectangle(cornerRadius: radius)).onHover { hover = $0 }
  }
}
extension View {
  func hoverFill(_ t: Theme, radius: CGFloat = 7, selected: Bool = false) -> some View {
    modifier(HoverFill(t: t, radius: radius, selected: selected))
  }
  /// Floating panel surface used by toolbars, palettes and inspectors.
  func floatingPanel(_ t: Theme, radius: CGFloat = 10) -> some View {
    background(t.surface, in: RoundedRectangle(cornerRadius: radius))
      .overlay(RoundedRectangle(cornerRadius: radius).stroke(t.hairline, lineWidth: 1))
      .shadow(color: t.shadow.opacity(0.6), radius: 14, y: 6)
  }
}

// MARK: Small display pieces

struct StateBadge: View {
  let state: String
  let t: Theme
  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(t.state(state)).frame(width: 6, height: 6)
      Text(Vocabulary.stateLabel(state)).font(.studio(size: 12, weight: .medium))
        .foregroundStyle(state == "canon" ? t.positive : t.secondary)
    }.accessibilityElement(children: .combine)
      .accessibilityLabel("State: \(Vocabulary.stateLabel(state))")
  }
}

struct CategoryTile: View {
  let record: LoreRecord
  let t: Theme
  var size: CGFloat = 32
  var body: some View {
    let tint = t.category(record.category)
    StudioIcon(recordIcon(record), size: size * 0.44)
      .foregroundStyle(tint).frame(width: size, height: size)
      .background(tint.opacity(t.dark ? 0.14 : 0.1), in: RoundedRectangle(cornerRadius: 8))
      .accessibilityHidden(true)
  }
}

struct SectionLabel: View {
  let title: String
  let t: Theme
  var body: some View {
    Text(title).font(.studio(size: 11, weight: .semibold)).tracking(0.3)
      .foregroundStyle(t.muted).frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FilterChip: View {
  let title: String
  var count: Int?
  var mutedCount = false
  let selected: Bool
  let t: Theme
  var action: () -> Void
  @State private var hover = false
  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(title).font(.studio(size: 12.5, weight: .medium))
        if let count {
          Text("\(count)").font(.studio(size: 11.5)).monospacedDigit()
            .foregroundStyle(selected && !mutedCount ? t.accent.opacity(0.8) : t.muted)
        }
      }.padding(.horizontal, 11).frame(height: 26)
        .foregroundStyle(selected ? t.accent : t.secondary)
        .background(selected ? t.accentSoft : (hover ? t.hover : .clear), in: Capsule())
        .overlay(Capsule().stroke(selected ? .clear : t.hairline, lineWidth: 1))
        .contentShape(Capsule())
    }.buttonStyle(.plain).onHover { hover = $0 }
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct SearchField: View {
  @Binding var text: String
  var placeholder: String
  let t: Theme
  var body: some View {
    HStack(spacing: 7) {
      StudioIcon("magnifyingglass", size: 12).foregroundStyle(t.muted)
      TextField(placeholder, text: $text).textFieldStyle(.plain).font(.studio(size: 13))
      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          StudioIcon("xmark.circle.fill", size: 12).foregroundStyle(t.muted)
        }.buttonStyle(.plain).help("Clear").accessibilityLabel("Clear search")
      }
    }.padding(.horizontal, 9).frame(height: Metric.control)
      .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
      .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.hairline, lineWidth: 1))
  }
}

/// Form field with the application surface instead of the system bezel.
struct FormTextArea: View {
  var label: String
  var placeholder: String
  @Binding var text: String
  var t: Theme
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.studio(size: 12.5, weight: .medium)).foregroundStyle(t.secondary)
      TextEditor(text: $text).font(.studio(size: 15)).scrollContentBackground(.hidden)
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            Text(placeholder).font(.studio(size: 15)).foregroundStyle(t.muted)
              .padding(.horizontal, 5).padding(.top, 1).allowsHitTesting(false)
              .accessibilityHidden(true)
          }
        }
        .padding(10).frame(height: 180)
        .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        .accessibilityLabel(label)
    }
  }
}

struct FormField: View {
  var label: String?
  var placeholder: String
  @Binding var text: String
  let t: Theme
  var secure = false
  var submit: () -> Void = {}
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let label {
        Text(label).font(.studio(size: 12, weight: .medium)).foregroundStyle(t.secondary)
      }
      Group {
        if secure {
          SecureField(placeholder, text: $text)
        } else {
          TextField(placeholder, text: $text)
        }
      }.textFieldStyle(.plain).font(.studio(size: 14)).onSubmit(submit)
        .padding(.horizontal, 10).frame(height: 34)
        .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.border, lineWidth: 1))
    }
  }
}

struct EmptyState<Actions: View>: View {
  let icon: String
  let title: String
  let message: String
  let t: Theme
  @ViewBuilder var actions: () -> Actions
  var body: some View {
    VStack(spacing: 14) {
      StudioIcon(icon, size: 26).foregroundStyle(t.accent)
        .frame(width: 56, height: 56).background(t.accentSoft.opacity(0.6), in: Circle())
        .accessibilityHidden(true)
      VStack(spacing: 6) {
        Text(title).font(.studio(size: 18, weight: .semibold))
        Text(message).font(.studio(size: 14)).foregroundStyle(t.secondary)
          .multilineTextAlignment(.center).lineSpacing(3).fixedSize(
            horizontal: false, vertical: true)
      }
      HStack(spacing: 8) { actions() }.padding(.top, 4)
    }.frame(maxWidth: 420).padding(28)
  }
}

struct ZoomControls: View {
  let zoom: Double
  let t: Theme
  var zoomOut: () -> Void
  var zoomIn: () -> Void
  var fit: () -> Void
  var body: some View {
    HStack(spacing: 2) {
      IconButton(icon: "minus", label: "Zoom out", t: t, action: zoomOut)
      Text("\(Int((zoom * 100).rounded()))%").font(.studio(size: 12, weight: .medium))
        .monospacedDigit().foregroundStyle(t.secondary).frame(width: 42)
      IconButton(icon: "plus", label: "Zoom in", t: t, action: zoomIn)
      Rectangle().fill(t.hairline).frame(width: 1, height: 16).padding(.horizontal, 2)
      IconButton(icon: "viewfinder", label: "Fit to content", t: t, action: fit)
    }.padding(3).floatingPanel(t)
  }
}

// MARK: Workspace chrome

private struct BarInsetKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
private struct BarCompactKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
  /// Leading space a workspace bar must leave for the window controls.
  var barInset: CGFloat {
    get { self[BarInsetKey.self] }
    set { self[BarInsetKey.self] = newValue }
  }
  /// True when a bar has too little room for labels; actions collapse to icons.
  var barCompact: Bool {
    get { self[BarCompactKey.self] }
    set { self[BarCompactKey.self] = newValue }
  }
}

/// The single top bar shared by every workspace: context on the left, workspace actions and the
/// persistent assistance switch on the right. Empty areas drag the window. When the full layout
/// does not fit, labels collapse to icons rather than truncating.
struct WorkspaceBar<Leading: View, Trailing: View>: View {
  @ObservedObject var studio: Studio
  var global = true
  /// A docked panel beside another workspace does not sit under the window controls.
  var inset = true
  @ViewBuilder var leading: () -> Leading
  @ViewBuilder var trailing: () -> Trailing
  @Environment(\.barInset) private var barInset
  var body: some View {
    ViewThatFits(in: .horizontal) {
      row(compact: false)
      row(compact: true)
    }.frame(height: Metric.bar).background(WindowDragArea())
  }
  private func row(compact: Bool) -> some View {
    HStack(spacing: 8) {
      leading()
      Spacer(minLength: 8)
      trailing()
      if global {
        Rectangle().fill(studio.t.hairline).frame(width: 1, height: 18).padding(.horizontal, 4)
        ModeSwitch(studio: studio, compact: compact)
        IconButton(icon: "magnifyingglass", label: "Search and commands · ⌘K", t: studio.t) {
          studio.palette = true
        }
      }
    }.environment(\.barCompact, compact)
      .padding(.leading, 20 + (inset ? barInset : 0)).padding(.trailing, 14)
  }
}

/// Reads the bar's compact environment inside its row, after layout chooses a variant.
struct RecordBreadcrumb: View {
  let origin: String
  let title: String
  let status: String
  let t: Theme
  var back: () -> Void
  @Environment(\.barCompact) private var compact
  var body: some View {
    HStack(spacing: 8) {
      Button(action: back) {
        HStack(spacing: 5) {
          StudioIcon("chevron.left", size: 11)
          if !compact { Text(origin).font(.studio(size: 13.5, weight: .medium)) }
        }.foregroundStyle(t.secondary).padding(.horizontal, 7).frame(height: 28)
          .hoverFill(t)
      }.buttonStyle(.plain).padding(.leading, -6).help("Back to \(origin)")
        .accessibilityLabel("Back to \(origin)").keyboardShortcut("[", modifiers: .command)
      if !compact { Text("/").foregroundStyle(t.muted.opacity(0.6)) }
      Text(title.isEmpty ? "Untitled" : title).font(.studio(size: 13.5, weight: .medium))
        .lineLimit(1).layoutPriority(1)
      if compact {
        Circle().fill(status.contains("Not saved") ? t.danger : t.muted)
          .frame(width: 5, height: 5).help(status).accessibilityLabel(status)
      } else {
        Text(status).font(.studio(size: 12)).lineLimit(1)
          .foregroundStyle(status.contains("Not saved") ? t.danger : t.muted)
          .padding(.leading, 4)
      }
    }
  }
}

/// Icon, title and optional detail for the left side of a workspace bar.
struct BarTitle: View {
  let icon: String
  let title: String
  var detail: String?
  let t: Theme
  @Environment(\.barCompact) private var compact
  var body: some View {
    HStack(spacing: 9) {
      StudioIcon(icon, size: 14).foregroundStyle(t.accent)
        .accessibilityHidden(true)
      Text(title).font(.studio(size: 15, weight: .semibold)).lineLimit(1).fixedSize()
      if let detail, !detail.isEmpty, !compact {
        Text(detail).font(.studio(size: 13)).foregroundStyle(t.muted).lineLimit(1)
      }
    }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
  }
}

/// Labelled bar action that becomes icon-only when the bar is compact.
struct BarAction: View {
  let title: String
  let icon: String
  let t: Theme
  var primary = false
  var help: String?
  var action: () -> Void
  @Environment(\.barCompact) private var compact
  var body: some View {
    Button(action: action) {
      if compact {
        StudioIcon(icon, size: 13).frame(width: 14)
      } else {
        StudioLabel(title, icon: icon)
      }
    }.buttonStyle(QuietButton(t: t, primary: primary)).help(help ?? title)
      .accessibilityLabel(title)
  }
}

/// Shared segmented control for assistance and appearance; changes use the owner's action.
struct SegmentedSwitch<Value: Hashable>: View {
  struct Choice {
    let value: Value
    let title: String
    var help: String = ""
    var indicator = false
  }
  let choices: [Choice]
  let selected: Value
  let label: String
  let t: Theme
  var select: (Value) -> Void
  @Namespace private var space
  var body: some View {
    HStack(spacing: 2) {
      ForEach(choices, id: \.value) { choice in
        let active = selected == choice.value
        Button {
          withAnimation(.easeOut(duration: 0.16)) { select(choice.value) }
        } label: {
          HStack(spacing: 6) {
            if choice.indicator {
              Circle().fill(active ? t.accent : t.muted.opacity(0.6))
                .frame(width: 6, height: 6)
            }
            Text(choice.title).font(.studio(size: 12.5, weight: .medium)).lineLimit(1).fixedSize()
          }.padding(.horizontal, 10).frame(height: 24)
            .foregroundStyle(active ? t.text : t.muted)
            .background {
              if active {
                RoundedRectangle(cornerRadius: 7).fill(t.secondarySurface)
                  .matchedGeometryEffect(id: "selection", in: space)
              }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).help(choice.help.isEmpty ? choice.title : choice.help)
          .accessibilityLabel(choice.title).accessibilityAddTraits(active ? .isSelected : [])
      }
    }.padding(2).background(t.surface, in: RoundedRectangle(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).stroke(t.hairline, lineWidth: 1))
      .accessibilityElement(children: .contain).accessibilityLabel(label)
  }
}

/// Persistent AI Assisted / Manual control. Independent of navigation.
struct ModeSwitch: View {
  @ObservedObject var studio: Studio
  var compact = false
  var body: some View {
    SegmentedSwitch(
      choices: [
        .init(
          value: WorkspaceMode.assisted, title: compact ? "AI" : "AI Assisted",
          help: "AI Assisted: the assistant is available when you send a message", indicator: true),
        .init(
          value: .manual, title: "Manual",
          help: "Manual: no model requests. Every creative tool keeps working."),
      ], selected: studio.mode, label: "Assistance mode", t: studio.t, select: studio.setMode)
  }
}

struct AppearanceSwitch: View {
  @ObservedObject var studio: Studio
  var body: some View {
    SegmentedSwitch(
      choices: [.init(value: false, title: "Light"), .init(value: true, title: "Dark")],
      selected: studio.dark, label: "Appearance", t: studio.t
    ) { dark in
      if studio.dark != dark { studio.toggleTheme() }
    }
  }
}

// MARK: Sheets

/// Background captures use the real sheet content on an opaque, theme-matched modal surface.
struct CaptureSheetPanel<Content: View>: View {
  @ViewBuilder var content: () -> Content
  @Environment(\.colorScheme) private var colorScheme
  var body: some View {
    let t = Theme(dark: colorScheme == .dark)
    content().background(t.background, in: RoundedRectangle(cornerRadius: 14))
      .background(CaptureSheetAnchor())
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hairline, lineWidth: 1))
      .shadow(color: .black.opacity(0.3), radius: 30)
  }
}

/// Marks the real panel bounds so WebKit snapshot compositing cannot overwrite opaque black.
private struct CaptureSheetAnchor: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.identifier = NSUserInterfaceItemIdentifier("synthesis.capture-sheet")
    return view
  }
  func updateNSView(_ view: NSView, context: Context) {}
}

struct SheetScaffold<Content: View, Footer: View>: View {
  let title: String
  var subtitle: String?
  let t: Theme
  var width: CGFloat = 460
  var close: () -> Void
  @ViewBuilder var content: () -> Content
  @ViewBuilder var footer: () -> Footer
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(.studio(size: 17, weight: .semibold))
          if let subtitle {
            Text(subtitle).font(.studio(size: 13)).foregroundStyle(t.secondary)
              .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 12)
        IconButton(icon: "xmark", label: "Close", t: t, size: 26, action: close)
          .keyboardShortcut(.cancelAction)
      }.padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 16)
      VStack(alignment: .leading, spacing: 16) { content() }.padding(.horizontal, 22)
      HStack(spacing: 8) { footer() }.padding(.horizontal, 22).padding(.vertical, 18)
    }.frame(width: width).background(t.background).foregroundStyle(t.text)
  }
}

// MARK: Brand and window helpers

/// Lets an empty region of the integrated header move the window and zoom on double-click.
struct WindowDragArea: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { DragHandle() }
  func updateNSView(_ view: NSView, context: Context) {}
  final class DragHandle: NSView {
    override func mouseDown(with event: NSEvent) {
      if event.clickCount == 2 {
        window?.performZoom(nil)
      } else {
        window?.performDrag(with: event)
      }
    }
  }
}

struct AppearanceButton: View {
  @ObservedObject var studio: Studio
  var body: some View {
    IconButton(
      icon: studio.dark ? "sun" : "moon",
      label: studio.dark ? "Switch to light appearance" : "Switch to dark appearance", t: studio.t,
      size: 32
    ) {
      withAnimation(.easeOut(duration: 0.18)) { studio.toggleTheme() }
    }
  }
}
struct WorldEmblem: View {
  let t: Theme
  var radius: CGFloat = 8
  var body: some View {
    StudioIcon("globe", size: 19).foregroundStyle(t.accent)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(t.accentSoft, in: RoundedRectangle(cornerRadius: radius)).accessibilityHidden(
        true)
  }
}

struct WorldBadge: View {
  @ObservedObject var studio: Studio
  var radius: CGFloat = 8
  var body: some View {
    GeometryReader { geo in
      if let image = studio.worldCover {
        Image(nsImage: image).resizable().scaledToFill()
          .frame(width: geo.size.width, height: geo.size.height).clipped()
          .clipShape(RoundedRectangle(cornerRadius: radius))
      } else {
        WorldEmblem(t: studio.t, radius: radius)
      }
    }.accessibilityHidden(true)
  }
}

@MainActor enum ImageCache {
  static let cache = NSCache<NSData, NSImage>()
  static func image(_ data: Data) -> NSImage? {
    let key = data as NSData
    if let image = cache.object(forKey: key) { return image }
    guard let image = NSImage(data: data) else { return nil }
    cache.countLimit = 40
    cache.setObject(image, forKey: key)
    return image
  }
  static func image(base64: String?) -> NSImage? {
    guard let base64, let data = Data(base64Encoded: base64) else { return nil }
    return image(data)
  }
}
