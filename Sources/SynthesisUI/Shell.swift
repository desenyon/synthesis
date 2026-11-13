import AppKit
import SwiftUI
import SynthesisCore

/// Application shell: integrated header zone, navigation, the active workspace and global overlays.
public struct ConnectedRoot: View {
  @ObservedObject var studio: Studio
  public init(studio: Studio) { self.studio = studio }
  public var body: some View {
    GeometryReader { geo in
      let compact = geo.size.width < 760
      let rail =
        studio.collapsed
        || (geo.size.width < 1180 && studio.companionExpanded && studio.destination == .canvas
          && studio.selectedRecord == nil)
      let column: CGFloat = compact ? 0 : (rail ? Metric.rail : Metric.sidebar) + 8
      ZStack(alignment: .topLeading) {
        studio.t.background.ignoresSafeArea()
        HStack(spacing: 0) {
          if !compact {
            Sidebar(studio: studio, collapsed: rail).padding(.top, Metric.bar)
              .padding(.leading, 8).padding(.bottom, 8)
          }
          workspace.id("\(studio.worldID)#\(studio.captureNonce)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.barInset, max(0, Metric.chrome - column - 12))
        }
        HStack(spacing: 0) {
          Color.clear.frame(width: 84, height: 1)
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
      .overlay(alignment: .bottom) { toast }
      .animation(.easeOut(duration: 0.14), value: studio.palette)
    }
    .foregroundStyle(studio.t.text)
    .ignoresSafeArea()
    .preferredColorScheme(studio.dark ? .dark : .light)
    .sheet(item: $studio.sheet) { StudioSheet(studio: studio, sheet: $0).id($0) }
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
      }
    }
  }
  @ViewBuilder private var toast: some View {
    if let toast = studio.toast {
      HStack(spacing: 10) {
        Image(systemName: toast.icon).foregroundStyle(studio.t.accent)
        Text(toast.message).font(.system(size: 13)).lineLimit(2)
        if let title = toast.actionTitle, let action = toast.action {
          Button(title) {
            action()
            studio.toast = nil
          }.buttonStyle(.plain).font(.system(size: 13, weight: .semibold))
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

struct Sidebar: View {
  @ObservedObject var studio: Studio
  let collapsed: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      worldSwitcher.padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 10)
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(spacing: 1) {
            ForEach(Array(Destination.allCases.enumerated()), id: \.element) { index, item in
              NavRow(
                t: studio.t, title: item.rawValue, icon: item.icon,
                selected: studio.destination == item && studio.libraryCategory == nil,
                collapsed: collapsed,
                trailing: item == .review && studio.reviewCount > 0
                  ? "\(studio.reviewCount)" : "⌘\(index + 1)",
                badge: item == .review && studio.reviewCount > 0
              ) { studio.navigate(item) }
            }
          }
          if !collapsed {
            VStack(spacing: 1) {
              SectionLabel(title: "World", t: studio.t).padding(.horizontal, 10).padding(.bottom, 5)
              ForEach(Vocabulary.categories, id: \.self) { category in
                let count = studio.records.filter { $0.category == category }.count
                NavRow(
                  t: studio.t, title: category, icon: categoryIcon(category),
                  selected: studio.destination == .library && studio.libraryCategory == category
                    && studio.selectedRecord == nil,
                  collapsed: false, trailing: count > 0 ? "\(count)" : nil,
                  tint: studio.t.category(category)
                ) { studio.openLens(category) }
              }
            }
            conversations
          }
        }.padding(.horizontal, 8).padding(.bottom, 8)
      }.scrollIndicators(.never)
      Rectangle().fill(studio.t.hairline).frame(height: 1)
      footer.padding(8)
    }
    .frame(width: collapsed ? Metric.rail : Metric.sidebar).frame(maxHeight: .infinity)
    .background(studio.t.sidebar, in: RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .contain).accessibilityLabel("Navigation")
  }
  private var worldSwitcher: some View {
    PlainMenu {
      ForEach(studio.worlds) { world in
        Button {
          studio.switchWorld(world.id)
        } label: {
          if world.id == studio.worldID {
            Label(world.name + (world.demo ? " · Sample" : ""), systemImage: "checkmark")
          } else {
            Text(world.name + (world.demo ? " · Sample" : ""))
          }
        }
      }
      Divider()
      Button("New world…") { studio.sheet = .world }
      if !studio.worlds.contains(where: { $0.demo }) {
        Button("Open sample world") { studio.loadSample() }
      }
    } label: {
      HStack(spacing: 10) {
        WorldBadge(studio: studio, radius: 7).frame(width: 30, height: 30)
        if !collapsed {
          VStack(alignment: .leading, spacing: 1) {
            Text(studio.world?.name ?? "World").font(.system(size: 14, weight: .semibold))
              .lineLimit(1)
            Text(studio.world?.demo == true ? "Sample universe" : "Your universe")
              .font(.system(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(1)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .medium))
            .foregroundStyle(studio.t.muted)
        }
      }.padding(collapsed ? 5 : 6).frame(width: collapsed ? 40 : Metric.sidebar - 16)
        .hoverFill(studio.t, radius: 9)
    }.help("Switch world").accessibilityLabel("World: \(studio.world?.name ?? "")")
  }
  private var conversations: some View {
    VStack(spacing: 1) {
      HStack {
        SectionLabel(title: "Conversations", t: studio.t)
        IconButton(icon: "plus", label: "New conversation · ⇧⌘N", t: studio.t, size: 22) {
          studio.newChat()
        }
      }.padding(.leading, 10).padding(.trailing, 4).padding(.bottom, 3)
      ForEach(studio.conversations.prefix(8)) { chat in
        ConversationRow(studio: studio, chat: chat)
      }
      if studio.conversations.isEmpty {
        Text("Conversations you start appear here.").font(.system(size: 12))
          .foregroundStyle(studio.t.muted).frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10).padding(.vertical, 6)
      }
    }
  }
  private var footer: some View {
    HStack(spacing: 2) {
      if collapsed {
        IconButton(icon: "gearshape", label: "Settings · ⌘,", t: studio.t, size: 40) {
          studio.sheet = .settings
        }
      } else {
        NavRow(
          t: studio.t, title: "Settings", icon: "gearshape", selected: false, collapsed: false,
          trailing: nil
        ) { studio.sheet = .settings }
        IconButton(
          icon: studio.dark ? "sun.max" : "moon",
          label: studio.dark ? "Switch to light appearance" : "Switch to dark appearance",
          t: studio.t, size: 30
        ) { studio.toggleTheme() }
      }
    }
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
  var action: () -> Void
  @State private var hover = false
  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon).font(.system(size: 14))
          .foregroundStyle(selected ? (tint ?? t.accent) : (tint?.opacity(0.85) ?? t.secondary))
          .frame(width: 20)
        if !collapsed {
          Text(title).font(.system(size: 13.5, weight: selected ? .medium : .regular))
            .lineLimit(1)
          Spacer(minLength: 0)
          if let trailing, badge {
            Text(trailing).font(.system(size: 11, weight: .semibold)).monospacedDigit()
              .foregroundStyle(t.accent).padding(.horizontal, 6).frame(minWidth: 18, minHeight: 18)
              .background(t.accentSoft, in: Capsule())
          } else if let trailing {
            Text(trailing).font(.system(size: 11.5)).monospacedDigit()
              .foregroundStyle(t.muted.opacity(trailing.hasPrefix("⌘") ? (hover ? 1 : 0) : 1))
          }
        }
      }.padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: collapsed ? 36 : 30)
        .foregroundStyle(selected ? t.text : t.secondary)
        .background(
          selected ? t.secondarySurface : (hover ? t.hover : .clear),
          in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }.buttonStyle(.plain).onHover { hover = $0 }.help(collapsed ? title : "")
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
        Text(chat.title).font(.system(size: 13.5, weight: selected ? .medium : .regular))
          .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
          .padding(.leading, 10).frame(height: 30).contentShape(Rectangle())
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
