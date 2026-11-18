import AppKit
import SwiftUI
import SynthesisCore

/// One shared reading edge for content browsers, their filters and section headings.
struct ContentColumn<Content: View>: View {
  @Environment(\.studioDensity) private var density
  @ViewBuilder var content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 0, content: content)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, density.inset)
      .frame(maxWidth: Metric.contentWidth)
      .frame(maxWidth: .infinity)
  }
}

struct ContentHeader<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    ContentColumn { HStack(spacing: Space.sm, content: content) }
      .padding(.vertical, 10)
  }
}

/// Entity identity remains the primary heading when changing its writing/sections/mechanics tab.
struct EntityPageHeading: View {
  let record: LoreRecord
  let t: Theme
  var subtitle = ""
  var body: some View {
    VStack(alignment: .leading, spacing: Space.sm) {
      Text(record.category.isEmpty ? "Entity" : Vocabulary.displayCategory(record.category))
        .font(.studio(.captionStrong)).foregroundStyle(t.secondary)
      Text(record.title).font(.studio(.entityTitle)).tracking(-0.4)
        .foregroundStyle(t.text).fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      if !subtitle.isEmpty {
        Text(subtitle).font(.studio(size: 14)).foregroundStyle(t.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
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

/// Open, aligned preference rows. Small windows stack controls beneath their labels.
struct PreferenceRow<Control: View>: View {
  let title: String
  var detail: String = ""
  let t: Theme
  @ViewBuilder var control: () -> Control
  private var label: some View {
    VStack(alignment: .leading, spacing: Space.xs) {
      Text(title).font(.studio(.control)).foregroundStyle(t.text)
      if !detail.isEmpty {
        Text(detail).font(.studio(size: 12.5)).foregroundStyle(t.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Space.xl) {
        label.frame(minWidth: 200)
        control().fixedSize(horizontal: true, vertical: false)
      }
      VStack(alignment: .leading, spacing: Space.md) {
        label
        control()
      }
    }.padding(.vertical, Space.lg)
      .overlay(alignment: .bottom) { t.hairline.frame(height: 1) }
  }
}

struct PreferenceMenu<Value: Hashable>: View {
  let title: String
  @Binding var value: Value
  let options: [(Value, String)]
  let t: Theme
  var width: CGFloat = 176
  private var selectedTitle: String { options.first { $0.0 == value }?.1 ?? title }
  var body: some View {
    PlainMenu {
      ForEach(options.indices, id: \.self) { i in
        Button {
          value = options[i].0
        } label: {
          if options[i].0 == value {
            Label {
              Text(options[i].1)
            } icon: {
              StudioIcon("checkmark", size: 13)
            }
          } else {
            Text(options[i].1)
          }
        }
      }
    } label: {
      HStack(spacing: Space.sm) {
        Text(selectedTitle).lineLimit(1)
        Spacer(minLength: 4)
        StudioIcon("chevron.up.chevron.down", size: 12).foregroundStyle(t.secondary)
      }.font(.studio(.label)).foregroundStyle(t.text)
        .padding(.horizontal, Space.md).frame(width: width, height: 34)
        .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.hairline, lineWidth: 1))
    }.accessibilityLabel(title).accessibilityValue(selectedTitle)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
      configuration.label.font(.studio(.label)).lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, Space.md).frame(height: Metric.control)
        .foregroundStyle(foreground)
        .background(fill, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(
          RoundedRectangle(cornerRadius: Metric.radius).stroke(
            role == .secondary ? t.hairline : .clear, lineWidth: 1)
        )
        .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
        .contentShape(RoundedRectangle(cornerRadius: Metric.radius))
        .trackedHover($hover)
        .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: configuration.isPressed)
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
          in: RoundedRectangle(cornerRadius: Metric.smallRadius)
        )
        .contentShape(RoundedRectangle(cornerRadius: Metric.smallRadius))
        .opacity(enabled ? 1 : 0.35)
    }.buttonStyle(.plain).trackedHover($hover)
      .onChange(of: active) { _, _ in hover = false }
      .help(label).accessibilityLabel(label)
  }
}

/// The composer's only filled action: restrained hover/press feedback and a legible disabled state.
struct ComposerSendStyle: ButtonStyle {
  let t: Theme
  func makeBody(configuration: Configuration) -> some View {
    Surface(t: t, configuration: configuration)
  }
  private struct Surface: View {
    let t: Theme
    let configuration: Configuration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    var body: some View {
      configuration.label.frame(width: ComposerMetric.control, height: ComposerMetric.control)
        .foregroundStyle(enabled ? t.onAccent : t.muted)
        .background(
          enabled ? t.accent.opacity(hovered ? 0.88 : 1) : t.secondarySurface,
          in: RoundedRectangle(cornerRadius: Metric.radius)
        )
        .contentShape(RoundedRectangle(cornerRadius: Metric.radius))
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
        .opacity(configuration.isPressed ? 0.85 : 1)
        .trackedHover($hovered)
        .animation(
          reduceMotion ? nil : .easeOut(duration: ComposerMetric.transition),
          value: configuration.isPressed
        )
        .animation(
          reduceMotion ? nil : .easeOut(duration: ComposerMetric.transition), value: enabled)
    }
  }
}

/// App-themed popover shared by every dropdown. Native context menus remain native.
struct PlainMenu<Label: View, Items: View>: View {
  /// Flexible menus may shrink so a long title truncates instead of widening its bar.
  var flexible = false
  var sidebarTheme: Theme? = nil
  var sidebarRole: SidebarControlStyle.Role = .identity
  @ViewBuilder var items: () -> Items
  @ViewBuilder var label: () -> Label
  @State private var open = false
  @Environment(\.colorScheme) private var scheme
  @Environment(\.studioTheme) private var inheritedTheme
  var body: some View {
    let t = inheritedTheme ?? Theme(dark: scheme == .dark)
    trigger.fixedSize(horizontal: !flexible, vertical: true)
      .accessibilityValue(open ? "Expanded" : "Collapsed")
      .popover(isPresented: $open, arrowEdge: .bottom) {
        ScrollView {
          VStack(alignment: .leading, spacing: 3) { items() }
            .font(.studio(size: 13)).foregroundStyle(t.text)
            .buttonStyle(DropdownButtonStyle(t: t, close: { open = false }))
            .padding(7)
        }.scrollBounceBehavior(.basedOnSize).fixedSize(horizontal: false, vertical: true)
          .frame(width: 280).frame(maxHeight: 420)
          .background { FrostedSurface(t: sidebarTheme ?? t, radius: Metric.radius) }
          .preferredColorScheme(scheme)
          .onExitCommand { open = false }
      }
  }
  @ViewBuilder private var trigger: some View {
    if let sidebarTheme {
      Button {
        open.toggle()
      } label: {
        label()
      }
      .buttonStyle(SidebarControlStyle(t: sidebarTheme, role: sidebarRole, selected: open))
    } else {
      Button {
        open.toggle()
      } label: {
        label()
      }.buttonStyle(.plain)
    }
  }
}

private struct DropdownButtonStyle: PrimitiveButtonStyle {
  let t: Theme
  var close: () -> Void
  func makeBody(configuration: Configuration) -> some View {
    Button {
      close()
      configuration.trigger()
    } label: {
      configuration.label.frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, Space.sm).contentShape(Rectangle())
        .hoverFill(t, radius: 7)
    }.buttonStyle(.plain)
  }
}

/// An expandable group inside a dropdown instead of an unrelated system submenu.
struct MenuSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content
  @State private var expanded = false
  init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
    self.title = title
    self.content = content
  }
  var body: some View {
    DisclosureGroup(title, isExpanded: $expanded) {
      VStack(alignment: .leading, spacing: 2) { content() }.padding(.top, 4)
    }.padding(.horizontal, 10).padding(.vertical, 7)
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
        .background(
          hover ? t.hover : .clear, in: RoundedRectangle(cornerRadius: Metric.smallRadius)
        )
        .contentShape(RoundedRectangle(cornerRadius: Metric.smallRadius))
    }.trackedHover($hover).help(label).accessibilityLabel(label)
  }
}

/// Adds the standard row hover fill.
struct HoverFill: ViewModifier {
  let t: Theme
  var radius: CGFloat = Metric.smallRadius
  var selected = false
  @State private var hover = false
  func body(content: Content) -> some View {
    content.background(
      selected ? t.secondarySurface : (hover ? t.hover : .clear),
      in: RoundedRectangle(cornerRadius: radius)
    ).contentShape(RoundedRectangle(cornerRadius: radius))
      .trackedHover($hover)
      .onChange(of: selected) { _, _ in hover = false }

  }
}
extension View {
  func elevation(_ level: Elevation, t: Theme) -> some View {
    shadow(color: t.shadow.opacity(level.opacity), radius: level.radius, y: level.offset)
  }
  func hoverFill(_ t: Theme, radius: CGFloat = Metric.smallRadius, selected: Bool = false)
    -> some View
  {
    modifier(HoverFill(t: t, radius: radius, selected: selected))
  }
  /// Floating panel surface used by toolbars, palettes and inspectors.
  func floatingPanel(_ t: Theme, radius: CGFloat = Metric.floatingRadius) -> some View {
    background { FrostedSurface(t: t, radius: radius) }
      .overlay(RoundedRectangle(cornerRadius: radius).stroke(t.hairline, lineWidth: 1))
      .elevation(.floating, t: t)
  }
}

// MARK: Small display pieces

struct StateBadge: View {
  let state: String
  let t: Theme
  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(t.state(state)).frame(width: 6, height: 6)
      Text(Vocabulary.stateLabel(state)).font(.studio(.captionStrong))
        .foregroundStyle(state == "canon" ? t.positive : t.secondary)
        .lineLimit(1).fixedSize()
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
      .background(
        tint.opacity(t.dark ? 0.14 : 0.1), in: RoundedRectangle(cornerRadius: Metric.radius)
      )
      .accessibilityHidden(true)
  }
}

struct SectionLabel: View {
  let title: String
  let t: Theme
  var body: some View {
    Text(title).font(.studio(.sectionLabel)).tracking(0.3)
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
    }.buttonStyle(.plain).trackedHover($hover)
      .onChange(of: selected) { _, _ in hover = false }
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct SearchField: View {
  @Binding var text: String
  var placeholder: String
  let t: Theme
  var autofocus = false
  @FocusState private var focused: Bool
  var body: some View {
    HStack(spacing: 7) {
      StudioIcon("magnifyingglass", size: 12).foregroundStyle(t.muted)
      TextField(placeholder, text: $text).textFieldStyle(.plain).font(.studio(size: 13))
        .focused($focused)
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
      .onAppear { if autofocus { focused = true } }
  }
}

/// Form field with the application surface instead of the system bezel.
struct FormTextArea: View {
  var label: String
  var placeholder: String
  @Binding var text: String
  var t: Theme
  var height: CGFloat = 180
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
        .padding(10).frame(height: height)
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
  var autofocus = false
  var submit: () -> Void = {}
  @FocusState private var focused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let label {
        Text(label).font(.studio(.captionStrong)).foregroundStyle(t.secondary)
      }
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain).font(.studio(size: 14)).onSubmit(submit)
        .focused($focused)
        .padding(.horizontal, 10).frame(height: 34)
        .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.border, lineWidth: 1))
    }.onAppear { if autofocus { focused = true } }
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
      HStack(spacing: Space.sm) { actions() }.padding(.top, 4)
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
      Text("\(Int((zoom * 100).rounded()))%").font(.studio(.captionStrong))
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
    HStack(spacing: Space.sm) {
      if global && !studio.focusMode { NavigationButtons(studio: studio) }
      leading()
      Spacer(minLength: 8)
      if !studio.focusMode { trailing() }
      if global {
        if studio.focusMode {
          FocusWorkspaceControl(studio: studio)
        } else if compact {
          IconMenu(icon: "square.stack.3d.up", label: "Workspace tools", t: studio.t) {
            if studio.canFocusWorkspace {
              Button("Focus workspace · ⌥⌘F") { studio.toggleFocusMode() }
            }
            Button("Open document beside workspace…") { studio.sheet = .splitRecord }
            if studio.selectedRecord == nil {
              Button(studio.workspaceInspector ? "Hide inspector" : "Show inspector") {
                studio.toggleWorkspaceInspector()
              }
            }
            if studio.creativeScope != nil {
              Button("Creative components…") { studio.sheet = .components }
            }
          }
        } else {
          FocusWorkspaceControl(studio: studio)
          IconButton(
            icon: "square.stack.3d.up", label: "Open a document beside this workspace", t: studio.t,
            active: studio.splitRecord != nil
          ) { studio.sheet = .splitRecord }
          if studio.selectedRecord == nil {
            IconButton(
              icon: "sidebar.right", label: "Toggle inspector", t: studio.t,
              active: studio.workspaceInspector
            ) { studio.toggleWorkspaceInspector() }
          }
          if studio.creativeScope != nil {
            IconButton(icon: "rectangle.on.rectangle", label: "Creative components", t: studio.t) {
              studio.sheet = .components
            }
          }
        }
        Rectangle().fill(studio.t.hairline).frame(width: 1, height: 18).padding(
          .horizontal, Space.xs)
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
  @ObservedObject var studio: Studio
  let origin: String
  let title: String
  let status: DocumentSaveState
  let t: Theme
  @Environment(\.barCompact) private var compact
  var body: some View {
    HStack(spacing: Space.sm) {
      RecordTrail(studio: studio, origin: origin)
      Text(title.isEmpty ? "Untitled" : title).font(.studio(size: 13.5, weight: .medium))
        .lineLimit(1).layoutPriority(1)
      OperationFeedbackView(feedback: status.feedback, t: t, compact: compact, showDetail: false)
        .padding(.leading, compact ? 0 : 4)
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    HStack(spacing: 2) {
      ForEach(choices, id: \.value) { choice in
        let active = selected == choice.value
        Button {
          withAnimation(reduceMotion ? nil : Motion.feedbackAnimation) { select(choice.value) }
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
                RoundedRectangle(cornerRadius: Metric.smallRadius).fill(t.secondarySurface)
                  .transition(.opacity)
              }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metric.smallRadius))
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
    content().background(t.background, in: RoundedRectangle(cornerRadius: Metric.panelRadius))
      .background(CaptureSheetAnchor())
      .clipShape(RoundedRectangle(cornerRadius: Metric.panelRadius))
      .overlay(RoundedRectangle(cornerRadius: Metric.panelRadius).stroke(t.hairline, lineWidth: 1))
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
      VStack(alignment: .leading, spacing: Space.lg) { content() }.padding(.horizontal, 22)
      HStack(spacing: Space.sm) { footer() }.padding(.horizontal, 22).padding(.vertical, 18)
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

/// Shared themed selection field for forms; avoids unrelated system popup styling.
struct ChoiceField<Value: Hashable>: View {
  let title: String
  @Binding var selection: Value
  let choices: [(Value, String)]
  let t: Theme
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.studio(size: 12.5, weight: .medium)).foregroundStyle(t.secondary)
      PlainMenu(flexible: true) {
        ForEach(choices.indices, id: \.self) { index in
          Button {
            selection = choices[index].0
          } label: {
            HStack {
              Text(choices[index].1)
              Spacer()
              if selection == choices[index].0 { StudioIcon("checkmark", size: 12) }
            }
          }
        }
      } label: {
        HStack {
          Text(choices.first { $0.0 == selection }?.1 ?? "Choose…").lineLimit(1)
          Spacer()
          StudioIcon("chevron.down", size: 11).foregroundStyle(t.secondary)
        }.font(.studio(size: 14)).padding(.horizontal, 11).frame(height: 35)
          .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.hairline, lineWidth: 1))
      }.accessibilityLabel(title)
    }
  }
}

// MARK: Navigation materials and controls

/// Explicit appearance prevents adaptive glass from flipping against desktop content.
/// The opaque tint keeps the navigation legible even over a bright wallpaper.
struct NavigationGlass: View {
  let theme: Theme
  var forceOpaque = false
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  var body: some View {
    if forceOpaque || reduceTransparency || contrast == .increased {
      theme.navigation.background
    } else {
      SidebarVibrancy(dark: theme.dark)
        .overlay(theme.navigation.background.opacity(0.88))
        .allowsHitTesting(false).accessibilityHidden(true)
    }
  }
}

private struct SidebarVibrancy: NSViewRepresentable {
  let dark: Bool
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .sidebar
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }
  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  }
}

/// Shared navigation interaction, including keyboard focus and reduced-motion support.
struct SidebarControlStyle: PrimitiveButtonStyle {
  enum Role { case navigation, history, action, identity, quiet }
  let t: Theme
  var role: Role = .quiet
  var selected = false
  func makeBody(configuration: Configuration) -> some View {
    Control(configuration: configuration, palette: t.navigation, role: role, selected: selected)
  }
  private struct Control: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let palette: SidebarPalette
    let role: Role
    let selected: Bool
    @State private var hover = false
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
      Button {
        hover = false
        configuration.trigger()
      } label: {
        configuration.label
          .foregroundStyle(selected || hover ? palette.text : palette.secondary)
          .contentShape(RoundedRectangle(cornerRadius: SidebarMetric.radius))
      }.buttonStyle(PressStyle(palette: palette))
        .background(fill, in: RoundedRectangle(cornerRadius: SidebarMetric.radius))
        .overlay {
          RoundedRectangle(cornerRadius: SidebarMetric.radius)
            .strokeBorder(edge, lineWidth: focused ? 2 : 1).allowsHitTesting(false)
        }
        .focusable().focused($focused).focusEffectDisabled()
        .opacity(enabled ? 1 : 0.4)
        .trackedHover($hover)
        .onChange(of: selected) { _, _ in hover = false }
        .animation(
          reduceMotion ? nil : .easeOut(duration: SidebarMetric.transition), value: selected)
    }
    private var fill: Color {
      // History's selection belongs to the complete row, including its action slot.
      if selected { return role == .history ? .clear : palette.selected }
      if hover && enabled { return palette.hover }
      return role == .action || role == .identity ? palette.elevated.opacity(0.65) : .clear
    }
    private var edge: Color {
      if focused { return palette.focus }
      return (selected && role != .history) || role == .action || role == .identity
        ? palette.edge : .clear
    }
  }
  private struct PressStyle: ButtonStyle {
    let palette: SidebarPalette
    func makeBody(configuration: Configuration) -> some View {
      configuration.label.background(
        configuration.isPressed ? palette.pressed : .clear,
        in: RoundedRectangle(cornerRadius: SidebarMetric.radius))
    }
  }
}

/// Localized material for floating tools; content and document surfaces remain opaque.
struct FrostedSurface: View {
  let t: Theme
  var radius: CGFloat = Metric.panelRadius
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.studioOpaqueMaterials) private var forceOpaque
  var body: some View {
    Group {
      if reduceTransparency || contrast == .increased || forceOpaque {
        t.surface
      } else {
        FloatingVibrancy(dark: t.dark)
          .overlay(t.surface.opacity(t.dark ? 0.84 : 0.9))
      }
    }.clipShape(RoundedRectangle(cornerRadius: radius))
      .allowsHitTesting(false).accessibilityHidden(true)
  }
}
private struct FloatingVibrancy: NSViewRepresentable {
  let dark: Bool
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .popover
    view.blendingMode = .withinWindow
    view.state = .active
    return view
  }
  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  }
}
