import AppKit
import SwiftUI
import SynthesisCore

public struct ConnectedRoot: View {
  @ObservedObject var studio: Studio
  public init(studio: Studio) { self.studio = studio }
  public var body: some View {
    GeometryReader { geo in
      let compact = geo.size.width < 760
      VStack(spacing: 0) {
        header(compact: compact)
        HStack(spacing: 0) {
          if !compact {
            navigation(
              collapsed: studio.collapsed
                || (geo.size.width < 1200 && studio.companionExpanded
                  && studio.destination == .canvas)
            )
          }
          ZStack(alignment: .topLeading) {
            workspace.id(studio.worldID).frame(maxWidth: .infinity, maxHeight: .infinity)
            if compact && studio.mobileNavigation {
              navigation(collapsed: false).shadow(color: .black.opacity(0.25), radius: 20)
            }
          }
        }
      }.background(studio.t.background).foregroundStyle(studio.t.text)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .preferredColorScheme(studio.dark ? .dark : .light)
    .sheet(item: $studio.sheet) { StudioSheet(studio: studio, sheet: $0) }
    .alert(
      "Something needs attention",
      isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })
    ) {
      Button("OK") { studio.error = nil }
    } message: {
      Text(studio.error ?? "")
    }
    .overlay(alignment: .bottom) {
      if let notice = studio.notice {
        HStack {
          Text(notice)
          Button("Dismiss") { studio.notice = nil }
        }
        .font(.system(size: 13)).padding(16).background(
          studio.t.surface, in: RoundedRectangle(cornerRadius: 12)
        ).padding(20)
      }
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
      case .canvas, .manual: CuratedCanvas(studio: studio).id(studio.canvasBoardID ?? "default")
      case .library: LibraryScreen(studio: studio)
      case .knowledge: RelationshipGraph(studio: studio)
      case .timeline: TimelineScreen(studio: studio)
      case .atlas: AtlasScreen(studio: studio)
      }
    }
  }
  private func header(compact: Bool) -> some View {
    HStack(spacing: compact ? 8 : 16) {
      IconButton(icon: "sidebar.left", label: "Expand or collapse navigation", t: studio.t) {
        withAnimation(.easeInOut(duration: 0.18)) {
          if compact { studio.mobileNavigation.toggle() } else { studio.toggleSidebar() }
        }
      }
      SynthesisGlyph().stroke(studio.t.text, lineWidth: 1.5).frame(width: 20, height: 20)
      if !compact { Text("Synthesis").font(.system(size: 14, weight: .semibold)) }
      Menu {
        ForEach(studio.worlds) { world in
          Button(world.name + (world.demo ? " · Sample" : "")) { studio.switchWorld(world.id) }
        }
        Divider()
        Button("Create world…") { studio.sheet = .world }
        Button("Open sample world") { studio.loadSample() }
      } label: {
        Text(studio.world?.name ?? "World").font(.system(size: 14, weight: .medium)).lineLimit(1)
      }
      .menuStyle(.borderlessButton).frame(width: compact ? 90 : 160).padding(6)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 8))
      WindowDragArea().frame(maxWidth: .infinity, maxHeight: .infinity)
      HStack(spacing: 3) {
        mode(.assisted, compact ? "AI" : "AI Assisted")
        mode(.manual, "Manual")
      }.padding(3).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 9))
      if !compact {
        IconButton(icon: "magnifyingglass", label: "Quick open · ⌘K", t: studio.t) {
          studio.sheet = .search
        }
        IconButton(icon: studio.dark ? "sun.max" : "moon", label: "Switch appearance", t: studio.t)
        { studio.toggleTheme() }
      }
    }.padding(.horizontal, 12).frame(height: 56)
  }
  private func mode(_ mode: WorkspaceMode, _ label: String) -> some View {
    Button {
      withAnimation(.easeOut(duration: 0.18)) { studio.setMode(mode) }
    } label: {
      HStack(spacing: 6) {
        if mode == .assisted {
          Circle().fill(studio.mode == .assisted ? studio.t.accent : studio.t.muted).frame(
            width: 5, height: 5)
        }
        Text(label).font(.system(size: 13, weight: .medium))
      }.padding(.horizontal, 12).padding(.vertical, 7)
        .background(
          studio.mode == mode ? studio.t.secondarySurface : .clear,
          in: RoundedRectangle(cornerRadius: 6)
        )
        .foregroundStyle(studio.mode == mode ? studio.t.text : studio.t.secondary)
    }.buttonStyle(.plain).accessibilityLabel(
      mode == .assisted ? "AI Assisted" : "Manual — no model calls"
    )
    .accessibilityAddTraits(studio.mode == mode ? .isSelected : [])
  }
  private func navigation(collapsed: Bool) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      if !collapsed {
        HStack(spacing: 12) {
          WorldBadge(studio: studio).frame(width: 40, height: 40)
          VStack(alignment: .leading, spacing: 4) {
            Text(studio.world?.name ?? "World").font(.system(size: 15, weight: .semibold))
            Text(studio.world?.demo == true ? "Sample universe" : "Personal universe").font(
              .system(size: 12)
            ).foregroundStyle(studio.t.secondary)
          }
        }.padding(.horizontal, 12).padding(.top, 12)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(spacing: 3) {
            if !collapsed { section("Workspace") }
            ForEach([Destination.chat, .canvas, .library, .knowledge, .timeline, .atlas]) {
              destination in
              nav(
                destination.rawValue, destination.icon,
                selected: studio.destination == destination && studio.selectedRecord == nil,
                collapsed: collapsed
              ) { studio.navigate(destination) }
            }
          }
          if !collapsed {
            VStack(spacing: 3) {
              section("Worldbuilding")
              ForEach(
                ["Characters", "Factions", "Places", "Power systems", "Cosmology"], id: \.self
              ) { category in
                nav(
                  category, categoryIcon(category),
                  selected: studio.destination == .library && studio.libraryCategory == category,
                  collapsed: false
                ) {
                  studio.libraryCategory = category
                  studio.navigate(.library)
                }
              }
            }
            VStack(spacing: 3) {
              HStack {
                section("Conversations")
                Spacer()
                Button {
                  studio.newChat()
                } label: {
                  Image(systemName: "plus")
                }.buttonStyle(.plain).help("New conversation")
              }.padding(.trailing, 10)
              ForEach(studio.conversations.prefix(8)) { chat in
                nav(
                  chat.title, "bubble.left",
                  selected: studio.destination == .chat && studio.conversationID == chat.id,
                  collapsed: false
                ) { studio.openChat(chat) }
                .contextMenu {
                  Button("Rename") {
                    studio.openChat(chat)
                    studio.sheet = .rename
                  }
                }
              }
              if studio.conversations.isEmpty {
                Text("Your conversations appear here").font(.system(size: 12)).foregroundStyle(
                  studio.t.muted
                ).padding(12)
              }
            }
          }
        }
      }
      Spacer(minLength: 0)
      nav("Settings", "slider.horizontal.3", selected: false, collapsed: collapsed) {
        studio.sheet = .settings
      }
    }.padding(8).frame(width: collapsed ? 56 : 220).frame(maxHeight: .infinity)
      .background(studio.t.sidebar, in: RoundedRectangle(cornerRadius: 10)).padding(.leading, 8)
      .padding(.bottom, 8)
  }
  private func section(_ title: String) -> some View {
    Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.muted).padding(
      .horizontal, 12
    ).padding(.bottom, 6)
  }
  private func nav(
    _ title: String, _ icon: String, selected: Bool, collapsed: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 16)).frame(width: 20)
        if !collapsed {
          Text(title).font(.system(size: 14, weight: selected ? .medium : .regular)).lineLimit(1)
          Spacer(minLength: 0)
        }
      }.padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 36)
        .foregroundStyle(selected ? studio.t.text : studio.t.secondary)
        .background(
          selected ? studio.t.secondarySurface : .clear, in: RoundedRectangle(cornerRadius: 7))
    }.buttonStyle(.plain).help(title).accessibilityLabel(title)
  }
}
func categoryIcon(_ category: String) -> String {
  switch category.lowercased() {
  case "characters": return "person.crop.square"
  case "factions": return "flag"
  case "places": return "map"
  case "power systems": return "bolt"
  case "cosmology": return "sparkles"
  default: return "doc.text"
  }
}
struct WorldEmblem: View {
  let t: Theme
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10).fill(t.accentSoft)
      Canvas { context, size in
        for i in 0..<5 {
          var path = Path()
          path.move(to: CGPoint(x: -5, y: size.height * 0.35 + Double(i) * 5))
          path.addQuadCurve(
            to: CGPoint(x: size.width + 5, y: size.height * 0.7 + Double(i) * 4),
            control: CGPoint(x: size.width * 0.4, y: -12 + Double(i) * 6))
          context.stroke(path, with: .color(t.accent.opacity(0.45)), lineWidth: 1)
        }
      }.clipShape(RoundedRectangle(cornerRadius: 10))
    }.accessibilityHidden(true)
  }
}

struct WorldBadge: View {
  @ObservedObject var studio: Studio
  var body: some View {
    GeometryReader { geo in
      if let image = studio.worldCover {
        Image(nsImage: image).resizable().scaledToFill().frame(
          width: geo.size.width, height: geo.size.height
        ).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        WorldEmblem(t: studio.t)
      }
    }
  }
}
