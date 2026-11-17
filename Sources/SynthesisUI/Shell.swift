import AppKit
import SwiftUI
import SynthesisCore

/// Application shell: integrated header zone, navigation, the active workspace and global overlays.
public struct ConnectedRoot: View {
  @ObservedObject var studio: Studio
  @State private var canvasFrame: CGRect?
  @State private var lastCanvasFrame = CGRect(x: 0, y: 0, width: 900, height: 600)
  public init(studio: Studio) { self.studio = studio }
  public var body: some View {
    GeometryReader { geo in
      let compact = geo.size.width < 760
      let rail =
        studio.collapsed
        || (geo.size.width < 1180 && studio.companionExpanded
          && ![.chat, .worlds, .settings].contains(studio.destination)
          && studio.selectedRecord == nil)
      let column: CGFloat = compact ? 0 : (rail ? Metric.rail : Metric.sidebar)
      ZStack(alignment: .topLeading) {
        studio.t.sidebar.ignoresSafeArea()
        // The canvas engine's web view is mounted here once and never moved. The Canvas
        // workspace leaves a transparent area above it and reports where that area is; on
        // every other screen the web view stays in place but hidden.
        if let session = studio.canvasSession {
          let frame = canvasFrame ?? lastCanvasFrame
          CanvasWebView(session: session)
            .frame(width: max(1, frame.width), height: max(1, frame.height))
            .position(x: frame.midX, y: frame.midY)
            .opacity(canvasFrame == nil ? 0 : 1).allowsHitTesting(canvasFrame != nil)
            .accessibilityHidden(canvasFrame == nil)
        }
        HStack(spacing: 0) {
          if !compact {
            Sidebar(studio: studio, collapsed: rail).padding(.top, Metric.bar)
              .background {
                NavigationGlass(
                  theme: studio.t, forceOpaque: studio.captureHint.hasSuffix("sidebar-opaque"))
              }

          }
          workspace.id("\(studio.worldID)#\(studio.captureNonce)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Canvas is mounted underneath this native layout. An opaque background
            // here hides the entire engine while its accessibility tree stays alive.
            .background(
              studio.destination == .canvas && studio.selectedRecord == nil
                ? Color.clear : studio.t.background
            )
            .overlay(alignment: .leading) {
              Rectangle().fill(studio.t.hairline).frame(width: 1).allowsHitTesting(false)
            }
            .environment(\.barInset, max(0, Metric.chrome - column - 12))
            .animation(.easeInOut(duration: 0.22), value: studio.destination)
            .animation(.easeInOut(duration: 0.22), value: studio.companionExpanded)
        }
        HStack(spacing: 0) {
          Color.clear.frame(width: 84, height: 1)
          if !rail && !compact {
            Text("Synthesis").font(.studio(size: 14, weight: .semibold))
              .foregroundStyle(studio.t.text).padding(.trailing, 10)
          }
          Button {
            withAnimation(.easeInOut(duration: 0.18)) {
              if compact { studio.mobileNavigation.toggle() } else { studio.toggleSidebar() }
            }
          } label: {
            StudioIcon("sidebar.left", size: 15).frame(width: 28, height: 28)
          }.buttonStyle(SidebarControlStyle(t: studio.t))
            .help("Toggle navigation · ⌘\\").accessibilityLabel("Toggle navigation")
        }.frame(height: Metric.bar)
        if compact && studio.mobileNavigation {
          studio.t.scrim.ignoresSafeArea().onTapGesture {
            withAnimation(.easeOut(duration: 0.16)) { studio.mobileNavigation = false }
          }
          Sidebar(studio: studio, collapsed: false).padding(.top, Metric.bar)
            .background { NavigationGlass(theme: studio.t) }.padding(8)
            .shadow(color: studio.t.shadow, radius: 24, x: 6)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
        if studio.palette {
          CommandPalette(studio: studio).transition(.opacity)
        }
      }
      .coordinateSpace(name: "shell")
      .onPreferenceChange(CanvasFrameKey.self) { frame in
        canvasFrame = frame
        if let frame { lastCanvasFrame = frame }
      }
      .overlay(alignment: .bottom) { toast }
      .animation(.easeOut(duration: 0.14), value: studio.palette)
    }
    .foregroundStyle(studio.t.text)
    .ignoresSafeArea()
    .preferredColorScheme(studio.dark ? .dark : .light)
    .studioSheet(item: $studio.sheet) { StudioSheet(studio: studio, sheet: $0).id($0) }
    .alert(
      "Something needs attention",
      isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })
    ) {
      Button("OK") { studio.error = nil }
    } message: {
      Text(studio.error ?? "")
    }
    .transaction {
      // Occluded windows can retain a compositor animation's starting frame. Captures
      // describe settled states; the focused interaction runner still exercises motion.
      let staticCapture =
        !studio.captureHint.isEmpty
        && ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"] == nil
      if staticCapture || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        $0.animation = nil
        $0.disablesAnimations = true
      }
    }
  }
  @ViewBuilder private var workspace: some View {
    if [.canvas, .worlds, .settings].contains(studio.destination) && studio.selectedRecord == nil {
      content.transition(.opacity)
    } else if studio.destination == .chat && studio.selectedRecord == nil {
      content.transition(.opacity)
    } else {
      GeometryReader { geometry in
        HStack(spacing: 0) {
          if geometry.size.width < 760 && studio.mode == .assisted && studio.companionExpanded {
            ConversationStudio(studio: studio, companion: true, docked: false)
          } else {
            content.transition(.opacity).frame(
              minWidth: 0, maxWidth: .infinity, maxHeight: .infinity
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
              if studio.mode == .assisted && !studio.companionExpanded {
                UnifiedComposer(studio: studio, companion: true, collapsed: true)
                  .frame(maxWidth: 620).padding(.horizontal, 20).padding(.vertical, 12)
                  .frame(maxWidth: .infinity).background(studio.t.background)
                  .transition(.move(edge: .bottom).combined(with: .opacity))
              }
            }
            if studio.mode == .assisted && studio.companionExpanded {
              Rectangle().fill(studio.t.hairline).frame(width: 1)
              ConversationStudio(studio: studio, companion: true)
                .frame(width: min(420, max(300, geometry.size.width * 0.4)))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
          }
        }
      }
    }
  }
  @ViewBuilder private var content: some View {
    if let record = studio.selectedRecord {
      EditorScreen(studio: studio, record: record).id(record.id)
    } else {
      switch studio.destination {
      case .chat: ConversationStudio(studio: studio)
      case .canvas: CuratedCanvas(studio: studio).id(studio.canvasBoardID ?? "default")
      case .library: LibraryScreen(studio: studio)
      case .knowledge: RelationshipGraph(studio: studio)
      case .timeline: TimelineScreen(studio: studio)
      case .atlas: AtlasScreen(studio: studio)
      case .review: ReviewScreen(studio: studio)
      case .worlds: WorldsScreen(studio: studio)
      case .settings: SettingsScreen(studio: studio)
      }
    }
  }
  @ViewBuilder private var toast: some View {
    if let toast = studio.toast {
      HStack(spacing: 10) {
        StudioIcon(toast.icon).foregroundStyle(studio.t.accent)
        Text(toast.message).font(.studio(size: 13)).lineLimit(2)
        if let title = toast.actionTitle, let action = toast.action {
          Button(title) {
            action()
            studio.toast = nil
          }.buttonStyle(.plain).font(.studio(size: 13, weight: .semibold))
            .foregroundStyle(studio.t.accent)
        }
        IconButton(icon: "xmark", label: "Dismiss", t: studio.t, size: 22) { studio.toast = nil }
      }.padding(.leading, 14).padding(.trailing, 8).frame(height: 40).floatingPanel(studio.t)
        // On Canvas the bottom centre belongs to the composer, so confirmations sit above it.
        .padding(
          .bottom,
          studio.destination == .canvas && studio.selectedRecord == nil && studio.mode == .assisted
            && !studio.companionExpanded ? 96 : 22
        ).transition(.move(edge: .bottom).combined(with: .opacity))
        .id(toast.id).accessibilityElement(children: .contain)
    }
  }
}
