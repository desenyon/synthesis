import SwiftUI
import SynthesisCore

private struct SidebarContentBottomKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct SidebarViewportHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Fixed identity and utilities frame a single scrolling navigation/history surface.
struct Sidebar: View {
  @Environment(\.studioDensity) private var density
  @ObservedObject var studio: Studio
  let collapsed: Bool
  @State private var worldExpanded = true
  @State private var chatsExpanded = true
  @State private var contentBottom: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var palette: SidebarPalette { studio.t.navigation }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      worldSwitcher.padding(.top, 4).padding(.bottom, 8)
      actions.padding(.bottom, 16)
      ScrollViewReader { scroll in
        ScrollView {
          VStack(alignment: .leading, spacing: density.sectionGap) {
            section("Workspace", items: [.chat, .canvas, .library, .dashboard])
            section("Explore", items: [.knowledge, .timeline, .atlas, .review])
            if !collapsed {
              VStack(spacing: 0) {
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
                      collapsed: false,
                      trailing: studio.preferences.sidebarCounts && count > 0
                        ? count.formatted() : nil
                    ) { studio.openLens(category) }
                  }
                }
              }
              if studio.preferences.recentChats > 0 {
                VStack(spacing: 0) {
                  disclosure("Conversations", expanded: $chatsExpanded)
                  if chatsExpanded {
                    ForEach(studio.conversations.prefix(studio.preferences.recentChats)) { chat in
                      ConversationRow(studio: studio, chat: chat)
                    }
                    if studio.conversations.isEmpty {
                      Text("No conversations yet").font(.studio(.caption))
                        .foregroundStyle(palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).frame(height: density.historyRow)
                    }
                  }
                }.id("sidebar-history")
              }
            }
          }.padding(.bottom, 12)
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
              Color.clear.preference(
                key: SidebarViewportHeightKey.self, value: geometry.size.height)
            }
          }
          .onPreferenceChange(SidebarContentBottomKey.self) { contentBottom = $0 }
          .onPreferenceChange(SidebarViewportHeightKey.self) { viewportHeight = $0 }
          .modifier(
            BottomOverflowFade(active: viewportHeight > 0 && contentBottom > viewportHeight + 1)
          )
          .scrollIndicators(.automatic)
          .onChange(of: studio.captureNonce, initial: true) {
            guard !studio.captureHint.isEmpty else { return }
            worldExpanded = !studio.captureHint.contains("sidebar-folded")
            chatsExpanded = !studio.captureHint.contains("sidebar-folded")
            if studio.captureHint.contains("sidebar-history") {
              scroll.scrollTo("sidebar-history", anchor: .bottom)
            }
          }
      }
      footer
    }
    .padding(.horizontal, SidebarMetric.inset)
    .frame(width: collapsed ? Metric.rail : studio.sidebarWidth).frame(maxHeight: .infinity)
    .accessibilityElement(children: .contain).accessibilityLabel("Navigation")
  }

  @ViewBuilder private var actions: some View {
    if collapsed {
      VStack(spacing: 4) {
        newChat
        search
      }
    } else {
      HStack(spacing: 8) {
        newChat
        search
      }
    }
  }
  private var newChat: some View {
    Button {
      studio.newChat()
    } label: {
      HStack(spacing: 12) {
        StudioIcon("square.and.pencil", size: SidebarMetric.icon).frame(width: 20)
        if !collapsed {
          Text("New chat").font(.studio(.label)).lineLimit(1)
          Spacer(minLength: 4)
          Text("⇧⌘N").font(.studio(size: 11)).foregroundStyle(palette.muted)
        }
      }.padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: SidebarMetric.action)
    }.buttonStyle(SidebarControlStyle(t: studio.t, role: .action))
      .help("New conversation · ⇧⌘N").accessibilityLabel("New conversation")
  }
  private var search: some View {
    Button {
      studio.palette = true
    } label: {
      StudioIcon("search", size: SidebarMetric.icon)
        .frame(width: collapsed ? 40 : SidebarMetric.action, height: SidebarMetric.action)
    }.buttonStyle(SidebarControlStyle(t: studio.t, role: .action))
      .help("Search your world · ⌘K").accessibilityLabel("Search your world")
  }
  private var footer: some View {
    VStack(spacing: 8) {
      palette.edge.frame(height: 1)
      if collapsed {
        VStack(spacing: 4) {
          settings
          appearance
        }
      } else {
        HStack(spacing: 8) {
          settings
          appearance
        }
      }
    }.padding(.bottom, 12).padding(.top, 4)
  }
  private var settings: some View {
    NavRow(
      t: studio.t, title: "Settings", icon: "gearshape",
      selected: studio.destination == .settings && studio.selectedRecord == nil,
      collapsed: collapsed
    ) { studio.navigate(.settings) }
  }
  private var appearance: some View {
    Button {
      withAnimation(reduceMotion ? nil : .easeOut(duration: SidebarMetric.transition)) {
        studio.toggleTheme()
      }
    } label: {
      StudioIcon(studio.dark ? "moon" : "sun", size: SidebarMetric.icon)
        .frame(width: 40, height: density.navigationRow)
    }.buttonStyle(SidebarControlStyle(t: studio.t))
      .help(studio.dark ? "Dark appearance · Switch to light" : "Light appearance · Switch to dark")
      .accessibilityLabel("Appearance").accessibilityValue(studio.dark ? "Dark" : "Light")
      .accessibilityHint(studio.dark ? "Switch to light appearance" : "Switch to dark appearance")
  }
  private func heading(_ title: String) -> some View {
    Text(title).font(.studio(size: 11, weight: .medium)).foregroundStyle(palette.muted)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  private func section(_ title: String, items: [Destination]) -> some View {
    VStack(spacing: 0) {
      if !collapsed {
        heading(title).padding(.horizontal, 10).frame(height: SidebarMetric.section)
      }
      ForEach(items, id: \.self) { item in
        NavRow(
          t: studio.t, title: item.rawValue, icon: item.icon,
          selected: studio.destination == item && studio.libraryCategory == nil
            && studio.selectedRecord == nil,
          collapsed: collapsed,
          trailing: item == .review && studio.reviewCount > 0
            ? studio.reviewCount.formatted() : nil,
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
      withAnimation(reduceMotion ? nil : .easeOut(duration: SidebarMetric.transition)) {
        expanded.wrappedValue.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        heading(title)
        StudioIcon("chevron.right", size: 11)
          .rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0))
          .foregroundStyle(palette.muted)
      }.padding(.horizontal, 10).frame(height: SidebarMetric.section)
    }.buttonStyle(SidebarControlStyle(t: studio.t))
      .accessibilityLabel(title).accessibilityValue(
        expanded.wrappedValue ? "Expanded" : "Collapsed"
      )
      .accessibilityHint(expanded.wrappedValue ? "Collapse section" : "Expand section")
  }
  private var worldSwitcher: some View {
    PlainMenu(flexible: true, sidebarTheme: studio.t) {
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
      Button("New what-if from \(studio.world?.name ?? "this world")…") { studio.sheet = .whatIf }
      if let branch = studio.branch {
        Button("Send changes to \(branch.parentName)…") { studio.sheet = .sendWhatIf }
      }
      if !studio.worlds.contains(where: { $0.demo }) {
        Button("Open sample world") { studio.loadSample() }
      }
    } label: {
      HStack(spacing: 12) {
        WorldBadge(studio: studio, radius: 7).frame(width: 40, height: 40)
        if !collapsed {
          VStack(alignment: .leading, spacing: 4) {
            Text(studio.world?.name ?? "World").font(.studio(size: 14, weight: .semibold))
              .foregroundStyle(palette.text).lineLimit(1).truncationMode(.tail)
            Text(
              studio.branch.map { "What-if of \($0.parentName)" }
                ?? (studio.world?.demo == true ? "Sample universe" : "World workspace")
            )
            .font(.studio(size: 11)).foregroundStyle(palette.muted).lineLimit(1)
          }.frame(maxWidth: .infinity, alignment: .leading)
          StudioIcon("chevron.down", size: 12).foregroundStyle(palette.muted)
        }
      }.padding(collapsed ? 0 : 8).frame(maxWidth: .infinity, alignment: .leading)
    }.help("Switch world · \(studio.world?.name ?? "")")
      .accessibilityLabel("World: \(studio.world?.name ?? "")")
  }
}

struct NavRow: View {
  @Environment(\.studioDensity) private var density
  let t: Theme
  let title: String
  let icon: String
  let selected: Bool
  let collapsed: Bool
  var trailing: String?
  var badge = false
  var help: String?
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        StudioIcon(icon, size: SidebarMetric.icon).frame(width: 20)
        if !collapsed {
          Text(title).font(.studio(size: 13, weight: selected ? .medium : .regular))
            .lineLimit(1).truncationMode(.tail)
          Spacer(minLength: 8)
          if let trailing {
            Text(trailing).font(.studio(size: 11, weight: badge ? .medium : .regular))
              .monospacedDigit().foregroundStyle(badge ? t.navigation.text : t.navigation.muted)
              .padding(.horizontal, badge ? 6 : 0).frame(
                minWidth: badge ? 20 : 32, minHeight: 20,
                alignment: badge ? .center : .trailing
              )
              .background(
                badge ? t.navigation.pressed : .clear,
                in: RoundedRectangle(cornerRadius: 5)
              )
              .fixedSize()
          }
        }
      }.padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: density.navigationRow)
    }.buttonStyle(SidebarControlStyle(t: t, role: .navigation, selected: selected))
      .help(help ?? title)
      .overlay(alignment: .topTrailing) {
        if collapsed && badge {
          Circle().fill(t.navigation.text).frame(width: 5, height: 5).padding(6)
            .allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      .accessibilityLabel(title).accessibilityValue(trailing ?? "")
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct ConversationRow: View {
  @Environment(\.studioDensity) private var density
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
        HStack(spacing: 12) {
          StudioIcon("bubble.left", size: 15).frame(width: 20)
          Text(chat.title).font(.studio(size: 12, weight: selected ? .medium : .regular))
            .lineLimit(1).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.leading, 10).padding(.trailing, 4).frame(height: density.historyRow)
      }.buttonStyle(SidebarControlStyle(t: studio.t, role: .history, selected: selected))
        .accessibilityLabel(chat.title).accessibilityAddTraits(selected ? .isSelected : [])
      PlainMenu(sidebarTheme: studio.t, sidebarRole: .quiet) {
        actions
      } label: {
        StudioIcon("ellipsis", size: 15).foregroundStyle(studio.t.navigation.muted)
          .opacity(hover || selected ? 1 : 0.55).frame(width: 28, height: 28)
      }.padding(.trailing, 4).help("Conversation actions")
        .accessibilityLabel("Actions for \(chat.title)")
    }
    .background(
      selected || hover ? studio.t.navigation.hover : .clear,
      in: RoundedRectangle(cornerRadius: SidebarMetric.radius)
    )
    .trackedHover($hover)
    .onChange(of: studio.destination) { _, _ in hover = false }
    .onChange(of: studio.conversationID) { _, _ in hover = false }
    .onDisappear { hover = false }
    .contextMenu { actions }.help(chat.title)
  }
  @ViewBuilder private var actions: some View {
    Button("Rename…") {
      studio.renameTarget = chat.id
      studio.sheet = .rename
    }
    Button("Archive") { studio.archive(chat) }
  }
}
