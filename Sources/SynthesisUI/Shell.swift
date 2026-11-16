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
        }
        HStack(spacing: 0) {
          Color.clear.frame(width: 84, height: 1)
          if !rail && !compact {
            Text("Synthesis").font(.studio(size: 14, weight: .semibold))
              .foregroundStyle(studio.t.text).padding(.trailing, 10)
          }
          IconButton(icon: "sidebar.left", label: "Toggle navigation · ⌘\\", t: studio.t) {
            withAnimation(.easeInOut(duration: 0.18)) {
              if compact { studio.mobileNavigation.toggle() } else { studio.toggleSidebar() }
            }
          }
        }.frame(height: Metric.bar)
        if compact && studio.mobileNavigation {
          studio.t.scrim.ignoresSafeArea().onTapGesture {
            withAnimation(.easeOut(duration: 0.16)) { studio.mobileNavigation = false }
          }
          Sidebar(studio: studio, collapsed: false).padding(.top, Metric.bar).padding(8)
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
      if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { $0.animation = nil }
    }
  }
  @ViewBuilder private var workspace: some View {
    if [.canvas, .worlds, .settings].contains(studio.destination) && studio.selectedRecord == nil {
      content
    } else if studio.destination == .chat && studio.selectedRecord == nil {
      content
    } else {
      GeometryReader { geometry in
        HStack(spacing: 0) {
          if geometry.size.width < 760 && studio.mode == .assisted && studio.companionExpanded {
            ConversationStudio(studio: studio, companion: true, docked: false)
          } else {
            content.frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
              .safeAreaInset(edge: .bottom, spacing: 0) {
                if studio.mode == .assisted && !studio.companionExpanded {
                  UnifiedComposer(studio: studio, companion: true, collapsed: true)
                    .frame(maxWidth: 620).padding(.horizontal, 20).padding(.vertical, 12)
                    .frame(maxWidth: .infinity).background(studio.t.background)
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
      case .settings: StudioSheet(studio: studio, sheet: .settings, embedded: true)
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

private struct SidebarContentBottomKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct SidebarViewportHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct Sidebar: View {
  @ObservedObject var studio: Studio
  let collapsed: Bool
  @State private var worldExpanded = true
  @State private var chatsExpanded = true
  @State private var contentBottom: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      worldSwitcher.padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 18)
      if collapsed {
        IconButton(
          icon: "square.and.pencil", label: "New conversation · ⇧⌘N", t: studio.t, size: 40
        ) { studio.newChat() }
        .padding(.horizontal, 8).padding(.bottom, 12)
      } else {
        HStack(spacing: 6) {
          Button {
            studio.newChat()
          } label: {
            HStack(spacing: 9) {
              StudioIcon("square.and.pencil", size: 15)
              Text("New chat").font(.studio(size: 13, weight: .medium)).lineLimit(1)
              Spacer(minLength: 0)
              Text("⇧⌘N").font(.studio(size: 11)).foregroundStyle(studio.t.muted)
            }.padding(.horizontal, 11).frame(height: 36)
              .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 8))
              .overlay(RoundedRectangle(cornerRadius: 8).stroke(studio.t.hairline, lineWidth: 1))
          }.buttonStyle(.plain).help("New conversation · ⇧⌘N")
          IconButton(icon: "search", label: "Search your world · ⌘K", t: studio.t, size: 34) {
            studio.palette = true
          }
        }.padding(.horizontal, 12).padding(.bottom, 20)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          section("Workspace", items: [.chat, .canvas, .library])
          section("Explore", items: [.knowledge, .timeline, .atlas, .review])
          if !collapsed {
            VStack(spacing: 4) {
              disclosure("World", expanded: $worldExpanded)
              if worldExpanded {
                ForEach(Vocabulary.categories, id: \.self) { category in
                  let count = studio.topLevelRecords.filter {
                    Vocabulary.matchesCategory($0.category, category)
                  }.count
                  NavRow(
                    t: studio.t, title: category, icon: categoryIcon(category),
                    selected: studio.destination == .library && studio.libraryCategory == category
                      && studio.selectedRecord == nil,
                    collapsed: false, trailing: count > 0 ? "\(count)" : nil,
                    tint: studio.t.category(category)
                  ) { studio.openLens(category) }
                }
              }
            }
            VStack(spacing: 4) {
              disclosure("Conversations", expanded: $chatsExpanded)
              if chatsExpanded {
                ForEach(studio.conversations.prefix(12)) { chat in
                  ConversationRow(studio: studio, chat: chat)
                }
                if studio.conversations.isEmpty {
                  Text("Your conversations will live here.").font(.studio(size: 12))
                    .foregroundStyle(studio.t.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
              }
            }
          }
        }.padding(.horizontal, 12).padding(.bottom, 18)
          .background {
            GeometryReader { geometry in
              Color.clear.preference(
                key: SidebarContentBottomKey.self,
                value: geometry.frame(in: .named("sidebarScroll")).maxY)
            }
          }
      }.coordinateSpace(name: "sidebarScroll")
        .background {
          GeometryReader { geometry in
            Color.clear.preference(key: SidebarViewportHeightKey.self, value: geometry.size.height)
          }
        }
        .onPreferenceChange(SidebarContentBottomKey.self) { contentBottom = $0 }
        .onPreferenceChange(SidebarViewportHeightKey.self) { viewportHeight = $0 }
        .modifier(
          BottomOverflowFade(active: viewportHeight > 0 && contentBottom > viewportHeight + 1)
        )
        .scrollIndicators(.never)
      VStack(spacing: 8) {
        HStack(spacing: 0) {
          NavRow(
            t: studio.t, title: "Settings", icon: "gearshape",
            selected: studio.destination == .settings, collapsed: collapsed
          ) { studio.navigate(.settings) }
          if !collapsed { AppearanceButton(studio: studio) }
        }
      }.padding(12).padding(.top, 8)
        .overlay(alignment: .top) {
          Rectangle().fill(studio.t.hairline).frame(height: 1)
        }
    }
    .frame(width: collapsed ? Metric.rail : Metric.sidebar).frame(maxHeight: .infinity)
    .background { NavigationGlass(theme: studio.t) }
    .accessibilityElement(children: .contain).accessibilityLabel("Navigation")
  }
  private func section(_ title: String, items: [Destination]) -> some View {
    VStack(spacing: 3) {
      if !collapsed {
        Text(title).font(.studio(size: 12, weight: .medium))
          .foregroundStyle(studio.t.muted).frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10).padding(.bottom, 5)
      }
      ForEach(items, id: \.self) { item in
        NavRow(
          t: studio.t, title: item.rawValue, icon: item.icon,
          selected: studio.destination == item && studio.libraryCategory == nil
            && studio.selectedRecord == nil,
          collapsed: collapsed,
          trailing: item == .review && studio.reviewCount > 0 ? "\(studio.reviewCount)" : nil,
          badge: item == .review && studio.reviewCount > 0,
          help: item == .review ? reviewBreakdown : nil
        ) { studio.navigate(item) }
      }
    }
  }
  private var reviewBreakdown: String {
    let proposals = studio.pendingProposals.count
    let canon = studio.canonQueue.count
    return "\(proposals) \(proposals == 1 ? "proposal" : "proposals") · "
      + "\(canon) \(canon == 1 ? "canon review" : "canon reviews")"
  }
  private func disclosure(_ title: String, expanded: Binding<Bool>) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.18)) { expanded.wrappedValue.toggle() }
    } label: {
      HStack(spacing: 6) {
        Text(title).font(.studio(size: 12, weight: .medium))
        Spacer()
        StudioIcon(expanded.wrappedValue ? "chevron.down" : "chevron.right", size: 12)
      }.foregroundStyle(studio.t.muted).padding(.horizontal, 10).frame(height: 24).contentShape(
        Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(
      "\(expanded.wrappedValue ? "Collapse" : "Expand") \(title)")
  }
  private var worldSwitcher: some View {
    PlainMenu {
      ForEach(studio.worlds) { world in
        Button {
          studio.switchWorld(world.id)
        } label: {
          if world.id == studio.worldID {
            StudioLabel(world.name + (world.demo ? " · Sample" : ""), icon: "checkmark")
          } else {
            Text(world.name + (world.demo ? " · Sample" : ""))
          }
        }
      }
      Divider()
      Button("All worlds…") { studio.navigate(.worlds) }
      Button("Open world file…") { studio.openPortableWorld() }
      Button("Save world file…") { studio.savePortableWorld() }
      Button("New world…") { studio.sheet = .world }
      if !studio.worlds.contains(where: { $0.demo }) {
        Button("Open sample world") { studio.loadSample() }
      }
    } label: {
      HStack(spacing: 10) {
        WorldBadge(studio: studio, radius: 8).frame(width: 32, height: 32)
        if !collapsed {
          VStack(alignment: .leading, spacing: 3) {
            Text(studio.world?.name ?? "World").font(.studio(size: 14, weight: .semibold))
              .lineLimit(1)
            Text(studio.world?.demo == true ? "Sample universe" : "World workspace").font(
              .system(size: 11.5)
            )
            .foregroundStyle(studio.t.muted).lineLimit(1)
          }
          Spacer(minLength: 0)
          StudioIcon("chevron.up.chevron.down", size: 13).foregroundStyle(studio.t.muted)
        }
      }.padding(6).frame(maxWidth: .infinity, alignment: .leading).hoverFill(studio.t, radius: 8)
    }.help("Switch world").accessibilityLabel("World: \(studio.world?.name ?? "")")
  }
}

struct NavRow: View {
  let t: Theme
  let title: String
  let icon: String
  let selected: Bool
  let collapsed: Bool
  var trailing: String?
  var tint: Color?
  /// Shows the trailing value as an attention count, also on the collapsed rail.
  var badge = false
  var help: String?
  var action: () -> Void
  @State private var hover = false
  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        StudioIcon(icon, size: 14)
          .foregroundStyle(selected ? (tint ?? t.accent) : (tint?.opacity(0.85) ?? t.secondary))
          .frame(width: 20)
        if !collapsed {
          Text(title).font(.studio(size: 13, weight: selected ? .medium : .regular))
            .lineLimit(1)
          Spacer(minLength: 0)
          if let trailing, badge {
            Text(trailing).font(.studio(size: 11, weight: .semibold)).monospacedDigit()
              .foregroundStyle(t.accent).padding(.horizontal, 6).frame(minWidth: 18, minHeight: 18)
              .background(t.accentSoft, in: Capsule())
          } else if let trailing {
            Text(trailing).font(.studio(size: 11.5)).monospacedDigit()
              .foregroundStyle(t.muted.opacity(trailing.hasPrefix("⌘") ? (hover ? 1 : 0) : 1))
          }
        }
      }.padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: collapsed ? 38 : 33)
        .foregroundStyle(selected ? t.text : t.secondary)
        .background(
          selected ? t.accentSoft : (hover ? t.hover : .clear),
          in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }.buttonStyle(.plain).onHover { hover = $0 }.help(help ?? (collapsed ? title : ""))
      .overlay(alignment: .topTrailing) {
        if collapsed && badge {
          Circle().fill(t.accent).frame(width: 7, height: 7).padding(7)
        }
      }
      .accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct ConversationRow: View {
  @ObservedObject var studio: Studio
  let chat: Conversation
  @State private var hover = false
  var body: some View {
    let selected =
      studio.destination == .chat && studio.conversationID == chat.id
      && studio.selectedRecord == nil
    HStack(spacing: 0) {
      Button {
        studio.openChat(chat)
      } label: {
        HStack(spacing: 8) {
          StudioIcon("bubble.left", size: 13).foregroundStyle(studio.t.muted)
          Text(chat.title).font(.studio(size: 13, weight: selected ? .medium : .regular))
            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.leading, 10).frame(height: 32).contentShape(Rectangle())
      }.buttonStyle(.plain)
      if hover || selected {
        IconMenu(icon: "ellipsis", label: "Conversation actions", t: studio.t, size: 24) {
          actions
        }.padding(.trailing, 3)
      }
    }
    .foregroundStyle(selected ? studio.t.text : studio.t.secondary)
    .background(
      selected ? studio.t.secondarySurface : (hover ? studio.t.hover : .clear),
      in: RoundedRectangle(cornerRadius: 7)
    )
    .onHover { hover = $0 }.contextMenu { actions }.help(chat.title)
  }
  @ViewBuilder private var actions: some View {
    Button("Rename…") {
      studio.renameTarget = chat.id
      studio.sheet = .rename
    }
    Button("Archive") { studio.archive(chat) }
  }
}
