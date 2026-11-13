import AppKit
import SwiftUI
import SynthesisCore

// UI-first interaction model. It reads existing lore but never invokes a model or changes canon.
public struct StudioModule: Identifiable, Equatable {
  public var id: String
  var title: String
  var icon: String
  var hint: String
  var section: String
  static let defaults: [StudioModule] = [
    .init(
      id: "overview", title: "Overview", icon: "square.grid.2x2", hint: "The shape of your world",
      section: "World"),
    .init(
      id: "characters", title: "Characters", icon: "person.crop.square",
      hint: "Who has something to lose?", section: "World"),
    .init(
      id: "factions", title: "Factions", icon: "flag", hint: "Who holds the balance?",
      section: "World"),
    .init(
      id: "places", title: "Places & atlas", icon: "map", hint: "Where does it all happen?",
      section: "World"),
    .init(
      id: "powers", title: "Power systems", icon: "bolt", hint: "Every power has a price",
      section: "Systems"),
    .init(
      id: "cosmology", title: "Cosmology", icon: "sparkles", hint: "What holds reality together?",
      section: "Systems"),
    .init(
      id: "history", title: "Universal history", icon: "clock.arrow.circlepath",
      hint: "What changed everything?", section: "Stories"),
    .init(
      id: "narratives", title: "Story threads",
      icon: "point.topleft.down.to.point.bottomright.curvepath", hint: "Where do the threads meet?",
      section: "Stories"),
  ]
}
public struct DesignFragment: Identifiable, Equatable {
  public var id = UUID().uuidString
  var module: String
  var title: String
  var text: String
  var x: Double
  var y: Double
  var sourceID: String?
  var starter = false
}
struct GuidedExchange: Identifiable {
  var id = UUID()
  var question: String
  var answer: String
}
public final class CanvasDesignModel: ObservableObject {
  @Published public var dark = true
  @Published public var collapsed = false
  @Published public var module = "overview"
  @Published public var conversation = false
  @Published public var guided = true
  @Published public var manual = false
  @Published public var step = 0
  @Published public var selected: String?
  @Published public var fragments: [DesignFragment] = []
  @Published var modules = StudioModule.defaults
  @Published var exchanges: [GuidedExchange] = []
  @Published var overlay: Overlay?
  @Published var scenery = true
  @Published var query = ""
  @Published var newModuleName = ""
  @Published var banner: String?
  enum Overlay: String, Identifiable {
    case search, modules, appearance
    var id: String { rawValue }
  }
  @Published var guideModule = "overview"
  var guide: [(String, String)] {
    switch guideModule {
    case "powers":
      return [
        ("The source", "Where does power come from in this world?"),
        ("The expression", "What can someone actually do with it?"),
        ("The cost", "What must someone give up to use it?"),
        ("The limit", "What is absolutely impossible—even for the strongest?"),
        ("The consequence", "How has this power changed ordinary life?"),
      ]
    case "history":
      return [
        ("The beginning", "What existed before recorded history?"),
        ("The turning point", "Which event split history into before and after?"),
        ("The era", "What did the world become in its wake?"),
        ("The legacy", "What remains of that age today?"),
        ("The disagreement", "Who tells a different version of this history?"),
      ]
    case "characters":
      return [
        ("The desire", "What does this person want more than anything?"),
        ("The contradiction", "What part of them gets in the way?"),
        ("The past", "What happened that they cannot leave behind?"),
        ("The connection", "Who do they need—and who needs them?"),
        ("The change", "What choice could make them someone else?"),
      ]
    case "factions":
      return [
        ("The purpose", "Why did this group come together?"),
        ("The authority", "Who leads—and why does anyone follow?"),
        ("The resource", "What do they control that others need?"),
        ("The rival", "Who stands in the way of their purpose?"),
        ("The fracture", "What could tear the group apart from within?"),
      ]
    case "places":
      return [
        ("The landscape", "What would someone notice first on arriving here?"),
        ("The life", "Who calls this place home?"),
        ("The pressure", "What makes living here difficult?"),
        ("The secret", "What is hidden beneath the familiar surface?"),
        ("The connection", "How does this place depend on the world around it?"),
      ]
    case "cosmology":
      return [
        ("The origin", "How did existence begin—or what do people believe?"),
        ("The structure", "What lies beyond the world people can see?"),
        ("The law", "What holds reality together?"),
        ("The exception", "Where does that law begin to break?"),
        ("The unknown", "What question can no one answer?"),
      ]
    case "narratives":
      return [
        ("The spark", "What disturbs the way things have always been?"),
        ("The conflict", "Whose desires cannot coexist?"),
        ("The cost", "What will be lost if nothing changes?"),
        ("The choice", "Which decision cannot be taken back?"),
        ("The aftermath", "How might the world be different afterward?"),
      ]
    case "overview":
      return [
        ("The premise", "What is the one thing that makes your world different?"),
        ("The possibility", "What can someone do here that they can't do in our world?"),
        ("The constraint", "What does that power cost?"),
        ("The history", "Which event changed this world forever?"),
        ("The character", "Who is caught in the middle of it all?"),
      ]
    default:
      let name =
        modules.first { $0.id == guideModule }?.title.lowercased() ?? "this part of your world"
      return [
        ("The idea", "What makes \(name) distinctive?"),
        ("The shape", "What are its most important parts?"),
        ("The rule", "What rules or patterns hold those parts together?"),
        ("The connection", "How does it change life elsewhere in your world?"),
        ("The question", "What would you like to explore next?"),
      ]
    }
  }
  var questions: [String] { guide.map(\.1) }
  var steps: [String] { guide.map(\.0) }
  var guideTitle: String {
    guideModule == "overview"
      ? "Build your world" : modules.first { $0.id == guideModule }?.title ?? "World guide"
  }
  var starters: [(String, String)] {
    switch guideModule {
    case "powers":
      return [
        ("From nature", "Power is drawn from "), ("An inheritance", "Some people are born with "),
        ("A bargain", "Power is granted in exchange for "),
      ]
    case "history":
      return [
        ("An ancient age", "Before recorded history, "),
        ("A lost civilization", "The first civilization vanished when "),
        ("A creation myth", "The oldest story begins with "),
      ]
    case "characters":
      return [
        ("To belong", "More than anything, they want to belong to "),
        ("To change things", "They cannot accept "), ("To find someone", "They are searching for "),
      ]
    case "factions":
      return [
        ("A shared belief", "They came together because they believe "),
        ("A necessity", "They formed to survive "), ("An ambition", "Their common goal is "),
      ]
    case "places":
      return [
        ("The landscape", "On arriving, you first notice "),
        ("The people", "The streets are full of "),
        ("Something strange", "What makes this place unusual is "),
      ]
    case "cosmology":
      return [
        ("A beginning", "Existence began when "), ("A cycle", "Reality is part of a cycle of "),
        ("A mystery", "No one knows why "),
      ]
    case "narratives":
      return [
        ("An arrival", "Everything changes when someone arrives with "),
        ("A discovery", "Someone discovers "), ("A loss", "The story begins with the loss of "),
      ]
    case "overview":
      return [
        ("A strange place", "A world where the ocean remembers "),
        ("An impossible rule", "In this world, everyone can "),
        ("A person", "It begins with someone who "),
      ]
    default:
      return [
        ("An idea", "The central idea is "), ("A question", "What if "),
        ("A connection", "This connects to "),
      ]
    }
  }
  var t: CanvasTheme { CanvasTheme(dark: dark) }
  var active: StudioModule { modules.first { $0.id == module } ?? modules[0] }
  var currentQuestion: String { questions[min(step, questions.count - 1)] }
  var visible: [DesignFragment] { fragments.filter { module == "overview" || $0.module == module } }
  public init(records: [LoreRecord] = []) {
    let positions: [(Double, Double)] = [(-285, -120), (70, -150), (350, 65), (-220, 160)]
    fragments = records.prefix(8).enumerated().map { i, r in
      let module =
        r.category.lowercased().contains("character")
        ? "characters"
        : r.category.lowercased().contains("faction")
          ? "factions" : r.category.lowercased().contains("place") ? "places" : "overview"
      let point = positions[i % positions.count]
      return DesignFragment(
        id: r.id, module: module, title: r.title, text: r.body, x: point.0 + Double(i / 4) * 60,
        y: point.1 + Double(i / 4) * 70, sourceID: r.id)
    }
  }
  public func openAppearance() { overlay = .appearance }
  public func openSearch() { overlay = .search }
  public func createNote() { addNote() }
  public func configureCapture(_ state: String) {
    dark = true
    collapsed = false
    module = "overview"
    conversation = false
    guided = true
    manual = false
    step = 0
    guideModule = "overview"
    selected = nil
    exchanges = []
    loadBlueprint()
    switch state {
    case "conversation":
      submit(
        "A world where memories become physical objects, and the sea keeps what people forget.")
      submit("People can borrow a memory and briefly live the skill inside it.")
      conversation = true
    case "power-system":
      module = "powers"
      start("powers")
    case "detail":
      submit("Memories crystallize beneath the sea.")
      selected = fragments.last?.id
    case "collapsed": collapsed = true
    case "light": dark = false
    default: break
    }
  }
  public func loadBlueprint() {
    fragments = [
      DesignFragment(
        module: "overview", title: "A world of your own",
        text: "Begin with one impossible thing. The rest can grow around it.", x: -260, y: -120,
        starter: true),
      DesignFragment(
        module: "powers", title: "Power systems",
        text: "The source. The cost. The limits. Build a system that changes how people live.",
        x: 95, y: -175, starter: true),
      DesignFragment(
        module: "history", title: "Universal history",
        text: "A turning point, a forgotten age, or the event everyone remembers differently.",
        x: 375, y: 65, starter: true),
      DesignFragment(
        module: "characters", title: "Characters",
        text: "Give someone a desire, a contradiction, and a reason to keep going.", x: -260,
        y: 70, starter: true),
    ]
  }
  func selectModule(_ value: String) {
    withAnimation(.easeInOut(duration: 0.18)) {
      module = value
      if guideModule != value { start(value) }
      selected = nil
      conversation = false
    }
  }
  func start(_ id: String) {
    guided = true
    conversation = false
    guideModule = id
    step = 0
    selected = nil
  }
  func submit(_ input: String) {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    let usesGuide = guided && !manual
    let id =
      usesGuide
      ? (guideModule == "overview"
        ? ["overview", "powers", "powers", "history", "characters"][min(step, 4)] : guideModule)
      : module
    let title =
      usesGuide
      ? steps[min(step, 4)]
      : String(value.split(separator: "\n").first?.prefix(48) ?? "Untitled thought")
    exchanges.append(
      GuidedExchange(question: usesGuide ? currentQuestion : "Freeform note", answer: value))
    fragments.removeAll { $0.starter && $0.module == id }
    let index = fragments.filter { !$0.starter }.count
    fragments.append(
      DesignFragment(
        module: id, title: title, text: value, x: Double(index % 3) * 300 - 280,
        y: Double(index / 3) * 210 - 70))
    if usesGuide {
      if step < 4 {
        step += 1
      } else {
        guided = false
        banner = "Your first threads are on the canvas. Keep shaping them."
      }
    }
  }
  func addNote() {
    let node = DesignFragment(module: module, title: "Untitled thought", text: "", x: 0, y: 0)
    fragments.append(node)
    selected = node.id
  }
}
struct CanvasTheme {
  let dark: Bool
  var base: Color { Color(hex: dark ? 0x111214 : 0xECEEF1) }
  var panel: Color { Color(hex: dark ? 0x1B1C1F : 0xF6F7F8) }
  var card: Color { Color(hex: dark ? 0x242629 : 0xFFFFFF) }
  var elevated: Color { Color(hex: dark ? 0x2B2D31 : 0xE8EBEF) }
  var text: Color { Color(hex: dark ? 0xE7E9EB : 0x22272E) }
  var secondary: Color { Color(hex: dark ? 0x9A9FA7 : 0x626A76) }
  var muted: Color { Color(hex: dark ? 0x737A84 : 0x7D8590) }
  var line: Color { Color(hex: dark ? 0x36393E : 0xD9DDE3) }
  var accent: Color { Color(hex: dark ? 0x9BB8CB : 0x526A86) }
  var tint: Color { Color(hex: dark ? 0x25353E : 0xDFE8EF) }
}

public struct CanvasDesignRoot: View {
  @ObservedObject var studio: Studio
  @ObservedObject var model: CanvasDesignModel
  @State private var mobileSidebar = false
  public init(studio: Studio, model: CanvasDesignModel) {
    self.studio = studio
    self.model = model
  }
  public var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.width < 760
      VStack(spacing: 0) {
        topbar(compact: compact)
        HStack(spacing: 0) {
          if !compact {
            moduleSidebar.frame(width: model.collapsed ? 56 : 224).padding(.leading, 10).padding(
              .bottom, 10
            ).transition(.move(edge: .leading).combined(with: .opacity))
          }
          ZStack(alignment: .topLeading) {
            InfiniteDesignCanvas(studio: studio, model: model)
            if compact && mobileSidebar {
              moduleSidebar.frame(width: 224).padding(8).shadow(
                color: .black.opacity(0.3), radius: 20
              ).zIndex(8)
            }
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }.background(model.t.base).foregroundStyle(model.t.text).font(.system(size: 13))
        .preferredColorScheme(model.dark ? .dark : .light)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottom) {
          if let banner = model.banner {
            HStack {
              Text(banner)
              Button("Dismiss") { model.banner = nil }.buttonStyle(.plain)
            }.font(.system(size: 11)).padding(12).background(
              model.t.elevated, in: RoundedRectangle(cornerRadius: 8)
            ).padding(.bottom, 12)
          }
        }
        .transaction { transaction in
          if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            transaction.animation = nil
          }
        }
        .sheet(item: $model.overlay) { overlay in designOverlay(overlay) }
        .onChange(of: studio.worldID) { _, _ in
          model.fragments = CanvasDesignModel(records: studio.records).fragments
          model.exchanges = []
          model.step = 0
        }
    }
  }
  private func topbar(compact: Bool) -> some View {
    HStack(spacing: 12) {
      Button {
        withAnimation(.easeInOut(duration: 0.18)) {
          if compact { mobileSidebar.toggle() } else { model.collapsed.toggle() }
        }
      } label: {
        Image(systemName: "sidebar.left").font(.system(size: 14))
      }.buttonStyle(StudioControl(t: model.t)).help("Toggle modules")
      SynthesisGlyph().stroke(model.t.text, lineWidth: 1.6).frame(width: 18, height: 18)
      if !compact {
        Text("Synthesis").font(.system(size: 13, weight: .semibold)).padding(.trailing, 8)
      }
      Menu {
        ForEach(studio.worlds) { world in Button(world.name) { studio.switchWorld(world.id) } }
      } label: {
        Text(studio.world?.name ?? "Your world").font(.system(size: 12, weight: .medium)).lineLimit(
          1)
      }.menuStyle(.borderlessButton).frame(width: compact ? 110 : 150)
        .padding(.horizontal, 8).padding(.vertical, 5).background(
          model.t.panel, in: RoundedRectangle(cornerRadius: 7))
      WindowDragArea().frame(maxWidth: .infinity, maxHeight: .infinity)
      if !compact {
        HStack(spacing: 2) {
          tab("Canvas", icon: "square.on.square", active: !model.conversation) {
            model.conversation = false
          }
          tab("Conversation", icon: "bubble.left", active: model.conversation) {
            model.conversation = true
          }
        }.padding(3).background(model.t.panel, in: RoundedRectangle(cornerRadius: 7))
        Rectangle().fill(model.t.line).frame(width: 1, height: 16).padding(.horizontal, 4)
      }
      Button {
        model.overlay = .search
      } label: {
        Image(systemName: "magnifyingglass")
      }.buttonStyle(StudioControl(t: model.t)).keyboardShortcut("k", modifiers: .command).help(
        "Search canvas · ⌘K")
      if !compact {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { model.dark.toggle() }
        } label: {
          Image(systemName: model.dark ? "sun.max" : "moon")
        }.buttonStyle(StudioControl(t: model.t)).help("Appearance")
      }
    }.padding(.horizontal, 12).frame(height: 48)
  }
  private func tab(_ title: String, icon: String, active: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button {
      withAnimation(.easeInOut(duration: 0.18), action)
    } label: {
      Label(title, systemImage: icon).font(.system(size: 11, weight: .medium)).padding(
        .horizontal, 10
      ).padding(.vertical, 5).foregroundStyle(active ? model.t.text : model.t.secondary).background(
        active ? model.t.elevated : .clear, in: RoundedRectangle(cornerRadius: 5))
    }.buttonStyle(.plain)
  }
  private var moduleSidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !model.collapsed {
        HStack {
          Text("World studio").font(.system(size: 14, weight: .medium))
          Spacer()
          Button {
            model.addNote()
          } label: {
            Image(systemName: "square.and.pencil")
          }.buttonStyle(StudioControl(t: model.t)).help("New note")
        }.padding(.horizontal, 14).padding(.top, 10)
        Button {
          model.overlay = .search
        } label: {
          HStack {
            Image(systemName: "magnifyingglass").font(.system(size: 11))
            Text("Find anything")
            Spacer()
            Text("⌘ K").font(.system(size: 10))
          }.foregroundStyle(model.t.muted).padding(9).background(
            model.t.base.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).padding(.horizontal, 12).padding(.top, 7).padding(.bottom, 18)
      } else {
        SynthesisGlyph().stroke(model.t.secondary, lineWidth: 1.3).frame(width: 20, height: 20)
          .frame(maxWidth: .infinity).padding(.vertical, 20)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          ForEach(["World", "Systems", "Stories", "Custom"], id: \.self) { section in
            let modules = model.modules.filter { $0.section == section }
            if !modules.isEmpty {
              VStack(alignment: .leading, spacing: 3) {
                if !model.collapsed {
                  HStack {
                    Text(section).font(.system(size: 11, weight: .medium))
                    Spacer()
                    if section == "Systems" {
                      Button {
                        model.overlay = .modules
                      } label: {
                        Image(systemName: "plus").font(.system(size: 10))
                      }.buttonStyle(.plain)
                    }
                  }.foregroundStyle(model.t.muted).padding(.horizontal, 12).padding(.bottom, 6)
                }
                ForEach(modules) { module in
                  Button {
                    model.selectModule(module.id)
                    mobileSidebar = false
                  } label: {
                    HStack(spacing: 10) {
                      Image(systemName: module.icon).font(.system(size: 14, weight: .regular))
                        .frame(width: 18)
                      if !model.collapsed {
                        Text(module.title).font(.system(size: 12))
                        Spacer()
                        let count = model.fragments.filter { $0.module == module.id && !$0.starter }
                          .count
                        if count > 0 {
                          Text("\(count)").font(.system(size: 10)).foregroundStyle(model.t.muted)
                        }
                      }
                    }
                    .foregroundStyle(model.module == module.id ? model.t.text : model.t.secondary)
                    .padding(.horizontal, 10).frame(height: 32).frame(
                      maxWidth: .infinity, alignment: model.collapsed ? .center : .leading
                    ).background(
                      model.module == module.id ? model.t.elevated : .clear,
                      in: RoundedRectangle(cornerRadius: 6))
                  }.buttonStyle(StudioHover(t: model.t)).help(module.title)
                }
              }
            }
          }
          if !model.collapsed && model.fragments.contains(where: { !$0.starter }) {
            VStack(alignment: .leading, spacing: 9) {
              Text("In this world").font(.system(size: 11, weight: .medium)).foregroundStyle(
                model.t.muted
              ).padding(.horizontal, 12)
              ForEach(model.fragments.filter { !$0.starter }.prefix(5)) { node in
                Button {
                  model.module = "overview"
                  model.selected = node.id
                } label: {
                  HStack(spacing: 9) {
                    Image(systemName: "doc.text").font(.system(size: 11))
                    Text(node.title).lineLimit(1)
                    Spacer()
                  }.font(.system(size: 11)).foregroundStyle(model.t.secondary).padding(
                    .horizontal, 12
                  ).padding(.vertical, 5)
                }.buttonStyle(StudioHover(t: model.t))
              }
            }
          }
        }.padding(.horizontal, 8).padding(.top, model.collapsed ? 6 : 0)
      }
      Spacer(minLength: 10)
      if !model.collapsed {
        Button {
          model.overlay = .modules
        } label: {
          HStack {
            Image(systemName: "plus")
            Text("Add a module")
            Spacer()
          }.font(.system(size: 11)).foregroundStyle(model.t.secondary).padding(12)
        }.buttonStyle(StudioHover(t: model.t)).padding(6)
      }
      Rectangle().fill(model.t.line.opacity(0.65)).frame(height: 0.5)
      HStack(spacing: 9) {
        Image(systemName: "circle.hexagongrid").font(.system(size: 18)).foregroundStyle(
          model.t.accent)
        if !model.collapsed {
          VStack(alignment: .leading, spacing: 2) {
            Text(studio.world?.demo == true ? "Sample world" : "Personal workspace").font(
              .system(size: 11, weight: .medium))
            Text("Local · just for you").font(.system(size: 10)).foregroundStyle(model.t.muted)
          }
          Spacer()
        }
        Button {
          model.overlay = .appearance
        } label: {
          Image(systemName: "slider.horizontal.3").font(.system(size: 12))
        }.buttonStyle(StudioControl(t: model.t)).help("Workspace appearance")
      }.padding(12)
    }.background(model.t.panel, in: RoundedRectangle(cornerRadius: 10)).overlay(
      RoundedRectangle(cornerRadius: 10).stroke(model.t.line.opacity(0.65), lineWidth: 0.7))
  }
  @ViewBuilder private func designOverlay(_ overlay: CanvasDesignModel.Overlay) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text(
          overlay == .search
            ? "Find a thread"
            : overlay == .modules ? "Make the workspace yours" : "Workspace appearance"
        ).font(.system(size: 19, weight: .medium))
        Spacer()
        Button {
          model.overlay = nil
        } label: {
          Image(systemName: "xmark")
        }.buttonStyle(StudioControl(t: model.t))
      }
      switch overlay {
      case .search:
        TextField("Search canvas fragments", text: $model.query).textFieldStyle(.plain)
          .padding(12).background(model.t.base, in: RoundedRectangle(cornerRadius: 7))
        ScrollView {
          VStack(spacing: 4) {
            ForEach(
              model.fragments.filter {
                model.query.isEmpty || $0.title.localizedCaseInsensitiveContains(model.query)
                  || $0.text.localizedCaseInsensitiveContains(model.query)
              }
            ) { node in
              Button {
                model.module = "overview"
                model.selected = node.id
                model.overlay = nil
              } label: {
                HStack {
                  Image(systemName: "doc.text")
                  Text(node.title)
                  Spacer()
                  Text("Open ↗").foregroundStyle(model.t.muted)
                }.padding(10)
              }.buttonStyle(StudioHover(t: model.t))
            }
          }
        }.frame(height: 240)
      case .modules:
        Text(
          "A module is a lens on your world. Add one for languages, religions, species—or anything your world needs."
        ).font(.system(size: 13)).foregroundStyle(model.t.secondary)
        TextField("Module name", text: $model.newModuleName).textFieldStyle(.plain).padding(12)
          .background(model.t.base, in: RoundedRectangle(cornerRadius: 7))
        Button("Add module") {
          let title = model.newModuleName.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !title.isEmpty else { return }
          let id = UUID().uuidString
          model.modules.append(
            StudioModule(
              id: id, title: title, icon: "square.stack.3d.up", hint: "A new part of your world",
              section: "Custom"))
          model.selectModule(id)
          model.newModuleName = ""
          model.overlay = nil
        }.buttonStyle(StudioAction(t: model.t)).disabled(
          model.newModuleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      case .appearance:
        Toggle("Dark appearance", isOn: $model.dark).toggleStyle(.switch)
        Toggle("ASCII landscape", isOn: $model.scenery).toggleStyle(.switch)
        Text("A quiet landscape behind your canvas.").font(
          .system(size: 12)
        ).foregroundStyle(model.t.secondary)
      }
    }.padding(24).frame(width: 430).background(model.t.panel).foregroundStyle(model.t.text)
      .preferredColorScheme(model.dark ? .dark : .light)
  }
}

struct SynthesisGlyph: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    let w = r.width
    let h = r.height
    p.move(to: CGPoint(x: w * 0.1, y: h * 0.35))
    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.1))
    p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.35))
    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.6))
    p.closeSubpath()
    p.move(to: CGPoint(x: w * 0.1, y: h * 0.65))
    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))
    p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.65))
    p.move(to: CGPoint(x: w * 0.1, y: h * 0.5))
    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.75))
    p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.5))
    return p
  }
}
struct StudioControl: ButtonStyle {
  let t: CanvasTheme
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.foregroundStyle(t.secondary).frame(width: 28, height: 28).background(
      configuration.isPressed ? t.elevated : .clear, in: RoundedRectangle(cornerRadius: 6)
    ).contentShape(Rectangle())
  }
}
struct StudioHover: ButtonStyle {
  let t: CanvasTheme
  @State private var hovered = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.65 : 1).background(
      hovered ? t.elevated.opacity(0.45) : .clear, in: RoundedRectangle(cornerRadius: 6)
    ).contentShape(Rectangle()).onHover { value in
      withAnimation(.easeOut(duration: 0.12)) { hovered = value }
    }
  }
}
struct StudioAction: ButtonStyle {
  let t: CanvasTheme
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium)).foregroundStyle(t.text).padding(
      .horizontal, 14
    ).padding(.vertical, 9).background(t.elevated, in: RoundedRectangle(cornerRadius: 7)).overlay(
      RoundedRectangle(cornerRadius: 7).stroke(t.line, lineWidth: 0.7)
    ).opacity(configuration.isPressed ? 0.7 : 1)
  }
}

struct WindowDragArea: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { DragHandle() }
  func updateNSView(_ view: NSView, context: Context) {}
  final class DragHandle: NSView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
  }
}
