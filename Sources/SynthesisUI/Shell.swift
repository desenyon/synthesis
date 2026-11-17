import AppKit
import SwiftUI
import SynthesisCore

/// Application shell: integrated header zone, navigation, the active workspace and global overlays.
public struct ConnectedRoot: View {
  @ObservedObject var studio: Studio
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var canvasFrame: CGRect?
  @State private var lastCanvasFrame = CGRect(x: 0, y: 0, width: 900, height: 600)
  public init(studio: Studio) { self.studio = studio }
  public var body: some View {
    GeometryReader { geo in
      let compact = geo.size.width < 760
      let rail = studio.collapsed
      let column = studio.visibleSidebarWidth(windowWidth: geo.size.width)
      let dockInspector = studio.dockedInspectorWidth(windowWidth: geo.size.width) > 0
      ZStack(alignment: .topLeading) {
        studio.t.sidebar.ignoresSafeArea()
        // The canvas engine's web view is mounted here once and never moved. The Canvas
        // workspace leaves a transparent area above it and reports where that area is; on
        // every other screen the web view stays in place but hidden.
        if let session = studio.canvasSession {
          let frame = canvasFrame ?? lastCanvasFrame
          let visible = canvasFrame != nil && studio.canvasVisible(windowWidth: geo.size.width)
          CanvasWebView(session: session, visible: visible)
            .frame(width: max(1, frame.width), height: max(1, frame.height))
            .position(x: frame.midX, y: frame.midY)
            .opacity(visible ? 1 : 0).allowsHitTesting(visible)
            .accessibilityHidden(!visible)
        }
        HStack(spacing: 0) {
          if !compact && !studio.focusMode {
            Sidebar(studio: studio, collapsed: rail).padding(.top, Metric.bar)
              .background {
                NavigationGlass(
                  theme: studio.t, forceOpaque: studio.captureHint.hasSuffix("sidebar-opaque"))
              }
              .overlay(alignment: .trailing) {
                if !rail {
                  PanelResizeHandle(studio: studio, panel: .sidebar, divider: false).padding(
                    .top, Metric.bar)
                }
              }
          }
          SplitWorkspace(studio: studio) {
            HStack(spacing: 0) {
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
                .animation(
                  reduceMotion ? nil : Motion.workspaceAnimation, value: studio.destination
                )
                .animation(
                  reduceMotion ? nil : Motion.workspaceAnimation, value: studio.selectedRecord?.id
                )
                .animation(
                  reduceMotion ? nil : Motion.panelAnimation, value: studio.companionExpanded)
              if !studio.focusMode && dockInspector && studio.workspaceInspector
                && studio.selectedRecord == nil
              {
                ObjectInspector(studio: studio)
                  .frame(width: studio.inspectorWidth)
                  .overlay(alignment: .leading) {
                    PanelResizeHandle(studio: studio, panel: .inspector)
                  }
                  .transition(Motion.panelTransition)
              }
            }.overlay(alignment: .trailing) {
              if !studio.focusMode && !dockInspector && studio.workspaceInspector
                && studio.selectedRecord == nil
              {
                ObjectInspector(studio: studio).frame(
                  width: min(
                    studio.inspectorWidth,
                    studio.primaryContentWidth(windowWidth: geo.size.width) - 28)
                )
                .overlay(alignment: .leading) {
                  PanelResizeHandle(
                    studio: studio, panel: .inspector,
                    displayedWidth: min(
                      studio.inspectorWidth,
                      studio.primaryContentWidth(windowWidth: geo.size.width) - 28),
                    maximum: studio.primaryContentWidth(windowWidth: geo.size.width) - 28,
                    divider: false)
                }
                .clipShape(RoundedRectangle(cornerRadius: Metric.floatingRadius))
                .overlay(
                  RoundedRectangle(cornerRadius: Metric.floatingRadius).stroke(
                    studio.t.hairline, lineWidth: 1)
                )
                .shadow(color: studio.t.shadow, radius: 12, x: -4, y: 4)
                .padding(.top, Metric.bar + 10).padding([.trailing, .bottom], 12)
                .transition(Motion.panelTransition)
              }
            }.animation(
              reduceMotion ? nil : Motion.panelAnimation, value: studio.workspaceInspector)
          }

        }
        HStack(spacing: 0) {
          Color.clear.frame(width: 84, height: 1)
          if !rail && !compact && !studio.focusMode {
            Text("Synthesis").font(.studio(size: 14, weight: .semibold))
              .foregroundStyle(studio.t.text).padding(.trailing, 10)
          }
          Button {
            withAnimation(reduceMotion ? nil : Motion.panelAnimation) {
              if studio.focusMode {
                studio.toggleFocusMode()
              } else if compact {
                studio.mobileNavigation.toggle()
              } else {
                studio.toggleSidebar()
              }
            }
          } label: {
            StudioIcon("sidebar.left", size: 15).frame(width: 28, height: 28)
          }.buttonStyle(SidebarControlStyle(t: studio.t))
            .help("Toggle navigation · ⌘\\").accessibilityLabel("Toggle navigation")
        }.frame(height: Metric.bar)
        if compact && studio.mobileNavigation && !studio.focusMode {
          studio.t.scrim.ignoresSafeArea().onTapGesture {
            withAnimation(reduceMotion ? nil : Motion.feedbackAnimation) {
              studio.mobileNavigation = false
            }
          }
          Sidebar(studio: studio, collapsed: false).padding(.top, Metric.bar)
            .background { NavigationGlass(theme: studio.t) }.padding(8)
            .shadow(color: studio.t.shadow, radius: 24, x: 6)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
        if studio.palette {
          CommandPalette(studio: studio).transition(.opacity)
            .opacity(studio.recordDrag == nil ? 1 : 0)
            .allowsHitTesting(studio.recordDrag == nil)
            .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: studio.recordDrag?.id)
        }
      }
      .coordinateSpace(name: "shell")
      .onPreferenceChange(CanvasFrameKey.self) { frame in
        canvasFrame = frame
        if let frame { lastCanvasFrame = frame }
      }
      .overlay(alignment: .bottom) { toast }
      .animation(reduceMotion ? nil : Motion.panelAnimation, value: studio.palette)
      .animation(reduceMotion ? nil : Motion.panelAnimation, value: studio.toast?.id)
      .animation(reduceMotion ? nil : Motion.panelAnimation, value: studio.focusMode)
    }
    .foregroundStyle(studio.t.text)
    .environment(\.studioTheme, studio.t)
    .environment(
      \.interactionScope,
      [
        studio.worldID, studio.destination.rawValue,
        studio.selectedRecord?.id ?? "", studio.graphSelectedID ?? "", studio.atlasSelectedID ?? "",
      ].joined(separator: ":")
    )
    .environment(\.studioDensity, DensityMetric(value: studio.preferences.density))
    .environment(\.studioOpaqueMaterials, studio.captureHint.contains("opaque"))
    .ignoresSafeArea()
    .preferredColorScheme(studio.dark ? .dark : .light)
    .onChange(of: studio.worldID) { _, _ in studio.endRecordDrag() }
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
        content.transition(.opacity).frame(maxWidth: .infinity, maxHeight: .infinity)
          .safeAreaInset(edge: .bottom, spacing: 0) {
            if !studio.focusMode && studio.mode == .assisted && !studio.splitUsesSharedComposer {
              UnifiedComposer(studio: studio, companion: true, collapsed: true)
                .frame(maxWidth: 620).padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: .infinity).background(studio.t.background)
                .opacity(studio.companionExpanded || studio.recordDrag != nil ? 0 : 1)
                .allowsHitTesting(!studio.companionExpanded && studio.recordDrag == nil)
                .accessibilityHidden(studio.companionExpanded || studio.recordDrag != nil)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
          }
          .overlay(alignment: .bottomTrailing) {
            if !studio.focusMode && studio.mode == .assisted && studio.companionExpanded {
              FloatingCompanion(studio: studio, available: geometry.size)
                .padding(14)
                .transition(Motion.companionTransition)
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
      case .dashboard: DashboardScreen(studio: studio)
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
        // Keep feedback above every compact composer, not over its input or Send control.
        .padding(
          .bottom,
          !studio.focusMode && studio.mode == .assisted && !studio.companionExpanded
            && (studio.selectedRecord != nil
              || ![.chat, .worlds, .settings].contains(studio.destination))
            ? 106 : 22
        ).transition(.move(edge: .bottom).combined(with: .opacity))
        .id(toast.id).accessibilityElement(children: .contain)
    }
  }
}
