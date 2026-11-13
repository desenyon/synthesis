import AppKit
import SwiftUI
import SynthesisCore

final class DesignViewport: ObservableObject {
  @Published var pan = CGSize.zero
  @Published var zoom = 1.0
  func move(_ delta: CGSize) {
    pan = CGSize(width: pan.width + delta.width, height: pan.height + delta.height)
  }
  func scale(_ delta: Double) { zoom = max(0.3, min(1.8, zoom + delta)) }
  func reset() {
    withAnimation(.easeOut(duration: 0.2)) {
      pan = .zero
      zoom = 1
    }
  }
}
struct InfiniteDesignCanvas: View {
  @ObservedObject var studio: Studio
  @ObservedObject var model: CanvasDesignModel
  @StateObject private var viewport = DesignViewport()
  @State private var dragging: (id: String, x: Double, y: Double)?
  @State private var showGuide = true
  @State private var dragOffset = CGSize.zero
  static let scenery: NSImage? = {
    let path = Bundle.main.resourceURL?.appendingPathComponent("Assets/landscape.png")
    return path.flatMap { NSImage(contentsOf: $0) }
  }()
  var body: some View {
    GeometryReader { geo in
      let compact = geo.size.width < 650
      ZStack(alignment: .bottom) {
        ZStack {
          model.t.base
          if model.scenery, let image = Self.scenery {
            Image(nsImage: image).resizable().scaledToFill().frame(
              width: geo.size.width, height: geo.size.height
            ).opacity(model.dark ? 0.75 : 0.32).clipped().allowsHitTesting(false)
          }
          Canvas { context, size in
            let gap = 28.0 * viewport.zoom
            let ox = viewport.pan.width.truncatingRemainder(dividingBy: gap)
            let oy = viewport.pan.height.truncatingRemainder(dividingBy: gap)
            for x in stride(from: ox, to: size.width, by: gap) {
              for y in stride(from: oy, to: size.height, by: gap) {
                context.fill(
                  Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                  with: .color(model.t.muted.opacity(0.17)))
              }
            }
            let nodes = model.visible
            if nodes.count > 1 {
              for i in 1..<nodes.count where nodes[0].starter && nodes[i].starter {
                let a = location(nodes[0], size: geo.size)
                let b = location(nodes[i], size: geo.size)
                var p = Path()
                p.move(to: CGPoint(x: a.x + 116 * viewport.zoom, y: a.y))
                p.addCurve(
                  to: CGPoint(x: b.x - 116 * viewport.zoom, y: b.y),
                  control1: CGPoint(x: a.x + 210 * viewport.zoom, y: a.y),
                  control2: CGPoint(x: b.x - 210 * viewport.zoom, y: b.y))
                context.stroke(
                  p, with: .color(model.t.secondary.opacity(0.23)),
                  style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
              }
            }
          }.allowsHitTesting(false)
          CanvasInputSurface(onPan: viewport.move, onZoom: viewport.scale).frame(
            maxWidth: .infinity, maxHeight: .infinity)
          if !model.conversation {
            ForEach(model.visible) { node in
              FragmentCard(
                node: node, module: model.modules.first { $0.id == node.module }, t: model.t,
                selected: model.selected == node.id,
                action: {
                  withAnimation(.easeOut(duration: 0.18)) {
                    if node.starter {
                      model.start(node.module)
                      showGuide = true
                    } else {
                      model.selected = node.id
                    }
                  }
                }
              )
              .frame(width: 244).scaleEffect(viewport.zoom).position(location(node, size: geo.size))
              .gesture(
                DragGesture(minimumDistance: 5).onChanged { value in
                  if dragging == nil { dragging = (node.id, node.x, node.y) }
                  dragOffset = value.translation
                }.onEnded { value in
                  if let drag = dragging,
                    let index = model.fragments.firstIndex(where: { $0.id == drag.id })
                  {
                    model.fragments[index].x = drag.x + value.translation.width / viewport.zoom
                    model.fragments[index].y = drag.y + value.translation.height / viewport.zoom
                  }
                  dragging = nil
                  dragOffset = .zero
                })
            }
            if model.visible.isEmpty {
              moduleEmpty(compact: compact).position(
                x: geo.size.width / 2, y: geo.size.height * 0.32)
            }
          }
        }.clipped()
        VStack(spacing: 0) {
          canvasBreadcrumb(compact: compact)
          Spacer(minLength: 8)
          if model.conversation {
            GuideTranscript(model: model).frame(maxWidth: 680).padding(
              .horizontal, compact ? 16 : 32
            ).transition(.opacity.combined(with: .offset(y: 12)))
          }
          if showGuide || model.conversation {
            DesignComposer(studio: studio, model: model, compact: compact).frame(maxWidth: 680)
              .padding(.horizontal, compact ? 12 : 28).padding(.bottom, compact ? 18 : 32)
              .transition(.opacity.combined(with: .offset(y: 14)))
          }
          bottomControls(compact: compact)
        }
        if let selected = model.selected,
          let index = model.fragments.firstIndex(where: { $0.id == selected })
        {
          FragmentInspector(
            node: $model.fragments[index], t: model.t,
            close: { withAnimation(.easeOut(duration: 0.18)) { model.selected = nil } }
          ).frame(width: min(350, geo.size.width - 32)).padding(16).frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing
          ).padding(.top, 44).transition(.opacity.combined(with: .move(edge: .trailing))).zIndex(6)
        }
      }
      .onAppear { frameCanvas(geo.size) }
      .onChange(of: geo.size) { _, size in frameCanvas(size) }
      .onChange(of: model.module) { _, _ in frameCanvas(geo.size) }
    }
  }
  private func frameCanvas(_ size: CGSize) {
    let nodes = model.visible
    guard let first = nodes.first else {
      viewport.reset()
      return
    }
    let left = nodes.map(\.x).min() ?? first.x
    let right = nodes.map(\.x).max() ?? first.x
    let top = nodes.map(\.y).min() ?? first.y
    let bottom = nodes.map(\.y).max() ?? first.y
    let areaHeight = max(190, size.height - 430)
    let scale = max(
      0.3,
      min(
        1, (size.width - 48) / (right - left + 244),
        (areaHeight - 24) / (bottom - top + 170)))
    viewport.zoom = scale
    viewport.pan = CGSize(
      width: -(left + right) / 2 * scale,
      height: 62 + areaHeight / 2 - size.height * 0.35 - (top + bottom) / 2 * scale)
  }
  private func location(_ node: DesignFragment, size: CGSize) -> CGPoint {
    CGPoint(
      x: size.width / 2 + node.x * viewport.zoom + viewport.pan.width
        + (dragging?.id == node.id ? dragOffset.width : 0),
      y: size.height * 0.35 + node.y * viewport.zoom + viewport.pan.height
        + (dragging?.id == node.id ? dragOffset.height : 0))
  }
  private func canvasBreadcrumb(compact: Bool) -> some View {
    HStack(spacing: 8) {
      Text(model.conversation ? "World guide" : model.active.title).font(
        .system(size: 12, weight: .medium))
      Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(model.t.muted)
      Text(model.conversation ? "\(model.exchanges.count) notes" : "Canvas").font(.system(size: 12))
        .foregroundStyle(model.t.secondary)
      if !compact { Text("/ Draft space").font(.system(size: 11)).foregroundStyle(model.t.muted) }
      Spacer()
      if compact {
        Button {
          withAnimation(.easeOut(duration: 0.18)) { model.conversation.toggle() }
        } label: {
          Image(systemName: model.conversation ? "square.on.square" : "bubble.left")
        }.buttonStyle(StudioControl(t: model.t))
      }
      Button {
        model.addNote()
      } label: {
        Label(compact ? "Note" : "Add a note", systemImage: "plus").font(.system(size: 11))
      }.buttonStyle(StudioAction(t: model.t))
    }.padding(.horizontal, compact ? 16 : 28).padding(.top, 14)
  }
  private func bottomControls(compact: Bool) -> some View {
    HStack(spacing: 10) {
      if !compact {
        Image(systemName: "cursorarrow.motionlines").font(.system(size: 11))
        Text("Drag to explore · pinch to zoom").font(.system(size: 10))
      }
      Spacer()
      Button {
        withAnimation(.easeOut(duration: 0.18)) { showGuide.toggle() }
      } label: {
        Label(showGuide ? "Hide chat" : "Show chat", systemImage: "bubble.left").font(
          .system(size: 11))
      }.buttonStyle(StudioAction(t: model.t))
      HStack(spacing: 2) {
        Button {
          viewport.scale(-0.1)
        } label: {
          Image(systemName: "minus").font(.system(size: 10))
        }.buttonStyle(StudioControl(t: model.t)).help("Zoom out")
        Button("\(Int(viewport.zoom*100))%") { viewport.reset() }.font(.system(size: 10))
          .buttonStyle(.plain).frame(width: 36).help("Reset canvas view")
        Button {
          viewport.scale(0.1)
        } label: {
          Image(systemName: "plus").font(.system(size: 10))
        }.buttonStyle(StudioControl(t: model.t)).help("Zoom in")
      }.padding(2).background(model.t.panel, in: RoundedRectangle(cornerRadius: 7)).overlay(
        RoundedRectangle(cornerRadius: 7).stroke(model.t.line.opacity(0.6), lineWidth: 0.5))
    }.foregroundStyle(model.t.muted).padding(.horizontal, 18).padding(.bottom, 12)
  }
  private func moduleEmpty(compact: Bool) -> some View {
    VStack(spacing: 14) {
      Image(systemName: model.active.icon).font(.system(size: 25, weight: .light)).foregroundStyle(
        model.t.accent)
      Text(model.active.title).font(.system(size: 25, weight: .medium)).tracking(-0.6)
      Text(model.active.hint).font(.system(size: 13)).foregroundStyle(model.t.secondary)
      Button("Start a thread") {
        model.start(model.module)
        showGuide = true
      }.buttonStyle(StudioAction(t: model.t))
    }.padding(28).frame(maxWidth: compact ? 290 : 420)
  }
}

struct FragmentCard: View {
  let node: DesignFragment
  let module: StudioModule?
  let t: CanvasTheme
  let selected: Bool
  let action: () -> Void
  @State private var hover = false
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          Image(systemName: module?.icon ?? "doc.text").font(.system(size: 12)).foregroundStyle(
            t.secondary)
          Text(node.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
          Spacer(minLength: 0)
          Image(systemName: node.starter ? "arrow.up.right" : "ellipsis").font(.system(size: 10))
            .foregroundStyle(t.muted)
        }.padding(.horizontal, 14).padding(.vertical, 12)
        Rectangle().fill(t.line.opacity(0.5)).frame(height: 0.5)
        Text(node.text.isEmpty ? "A thought, waiting to take shape." : node.text).font(
          .system(size: 12)
        ).lineSpacing(4).foregroundStyle(t.secondary).lineLimit(4).frame(
          maxWidth: .infinity, minHeight: 64, alignment: .topLeading
        ).padding(14)
        HStack(spacing: 5) {
          Circle().fill(node.starter ? t.accent : t.muted).frame(width: 4, height: 4)
          Text(node.starter ? "Start here" : "Draft").font(.system(size: 10))
          Spacer()
          Text(module?.title ?? "World").font(.system(size: 10))
        }.foregroundStyle(t.muted).padding(.horizontal, 14).padding(.vertical, 10).background(
          t.base.opacity(0.2))
      }.background(t.card, in: RoundedRectangle(cornerRadius: 10)).clipShape(
        RoundedRectangle(cornerRadius: 10)
      ).overlay(
        RoundedRectangle(cornerRadius: 10).stroke(
          selected ? t.accent : t.line.opacity(hover ? 1 : 0.6), lineWidth: 0.8)
      ).shadow(color: .black.opacity(t.dark ? 0.14 : 0.04), radius: hover ? 14 : 8, y: 5).offset(
        y: hover ? -2 : 0)
    }.buttonStyle(.plain).onHover { value in
      withAnimation(.easeOut(duration: 0.15)) { hover = value }
    }
  }
}

struct DesignComposer: View {
  @ObservedObject var studio: Studio
  @ObservedObject var model: CanvasDesignModel
  let compact: Bool
  @State private var draft = ""
  @State private var expanded = false
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if model.guided && !model.manual {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 7) {
            SynthesisGlyph().stroke(model.t.accent, lineWidth: 1.2).frame(width: 14, height: 14)
            Text(model.guideTitle).font(.system(size: 11, weight: .medium))
            Text("/ \(model.steps[min(model.step,4)])").font(.system(size: 11)).foregroundStyle(
              model.t.muted)
            Spacer()
            HStack(spacing: 4) {
              ForEach(0..<5) { i in
                Capsule().fill(i <= model.step ? model.t.accent : model.t.line).frame(
                  width: i == model.step ? 16 : 5, height: 4)
              }
            }
          }
          Text(model.currentQuestion).font(.system(size: compact ? 17 : 20, weight: .medium))
            .tracking(-0.3).fixedSize(horizontal: false, vertical: true)
          if model.step == 0 && draft.isEmpty {
            HStack(spacing: 6) {
              ForEach(Array(model.starters.prefix(compact ? 2 : 3).enumerated()), id: \.offset) {
                _, item in
                suggestion(item.0, item.1)
              }
            }
          }
        }.padding(.horizontal, 18).padding(.top, 17).padding(.bottom, 16)
      }
      VStack(spacing: 0) {
        ComposerInput(
          text: $draft,
          placeholder: model.manual
            ? "Capture a thought. It doesn't need to be finished…"
            : "Tell me what you have in mind. @ to connect…", color: model.t.text, submit: submit
        )
        .frame(height: expanded ? 140 : 70).padding(.horizontal, 12).padding(.top, 10)
        HStack(spacing: 10) {
          Menu {
            Button("New canvas note") { model.addNote() }
            Button("Add a module") { model.overlay = .modules }
            Button("Restart guided creation") {
              model.guided = true
              model.step = 0
            }
          } label: {
            Image(systemName: "plus").font(.system(size: 14))
          }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24).help(
            "Add to workspace")
          Menu {
            ForEach(model.fragments.filter { !$0.starter }) { node in
              Button(node.title) { draft += " @\(node.title) " }
            }
            if model.fragments.filter({ !$0.starter }).isEmpty {
              Text("Your fragments will appear here")
            }
          } label: {
            Text("@ Context").font(.system(size: 11))
          }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(
            model.t.muted)
          Spacer()
          Button {
            withAnimation(.easeOut(duration: 0.16)) { expanded.toggle() }
          } label: {
            Image(
              systemName: expanded
                ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
            ).font(.system(size: 11))
          }.buttonStyle(StudioControl(t: model.t)).help("Resize composer")
          Button(action: submit) {
            Image(systemName: "arrow.up").font(.system(size: 14, weight: .medium)).foregroundStyle(
              draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? model.t.muted : model.t.base
            ).frame(width: 28, height: 28).background(
              draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? model.t.elevated : model.t.text, in: Circle())
          }.buttonStyle(.plain).disabled(
            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ).help("Add to canvas · Return")
        }.padding(.horizontal, 13).padding(.bottom, 12).padding(.top, 4)
      }.background(model.t.panel, in: RoundedRectangle(cornerRadius: 13)).overlay(
        RoundedRectangle(cornerRadius: 13).stroke(model.t.line.opacity(0.8), lineWidth: 0.7)
      ).padding(.horizontal, 5)
      HStack(spacing: 6) {
        Image(systemName: "lock").font(.system(size: 9))
        Text("Drafts only").font(.system(size: 10))
        if !compact {
          Text("·")
          Text("UI study · not saved to lore").font(.system(size: 10))
        }
        Spacer()
        Menu {
          Button("Guided creation") {
            model.manual = false
            model.guided = true
          }
          Button("Manual notes") {
            model.manual = true
            studio.stop()
            model.guided = false
          }
        } label: {
          HStack(spacing: 5) {
            Circle().fill(!model.manual ? model.t.accent : model.t.muted).frame(
              width: 4, height: 4)
            Text(model.manual ? "Manual" : model.guided ? "Guided creation" : "Freeform")
            Image(systemName: "chevron.down").font(.system(size: 7))
          }.font(.system(size: 10))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
      }.foregroundStyle(model.t.muted).padding(.horizontal, 16).padding(.vertical, 10)
    }.background(
      (model.dark ? model.t.base : model.t.card).opacity(0.99),
      in: RoundedRectangle(cornerRadius: 17)
    ).overlay(
      RoundedRectangle(cornerRadius: 17).stroke(model.t.line.opacity(0.7), lineWidth: 0.7)
    ).shadow(color: .black.opacity(model.dark ? 0.30 : 0.055), radius: 32, y: 10)
  }
  private func suggestion(_ title: String, _ value: String) -> some View {
    Button {
      draft = value
    } label: {
      Text(title).font(.system(size: 10)).foregroundStyle(model.t.secondary).padding(.horizontal, 9)
        .padding(.vertical, 6).background(
          model.t.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 5))
    }.buttonStyle(.plain)
  }
  private func submit() {
    guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    withAnimation(.easeOut(duration: 0.2)) {
      model.submit(draft)
      draft = ""
    }
  }
}

struct GuideTranscript: View {
  @ObservedObject var model: CanvasDesignModel
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if model.exchanges.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("One idea. Then another.").font(.system(size: 23, weight: .medium))
              Text(
                "The guide helps you shape a premise, a power system, a history, and the people who live inside them. Every answer becomes a fragment on your canvas."
              ).font(.system(size: 13)).foregroundStyle(model.t.secondary).lineSpacing(5)
            }.padding(.vertical, 24)
          }
          ForEach(model.exchanges) { exchange in
            VStack(alignment: .leading, spacing: 14) {
              HStack(alignment: .top, spacing: 10) {
                SynthesisGlyph().stroke(model.t.accent, lineWidth: 1.2).frame(width: 16, height: 16)
                Text(exchange.question).font(.system(size: 14)).lineSpacing(4)
              }
              HStack {
                Spacer(minLength: 28)
                Text(exchange.answer).font(.system(size: 13)).lineSpacing(4).padding(14).background(
                  model.t.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
              }
              Label("Added to your canvas", systemImage: "checkmark").font(.system(size: 10))
                .foregroundStyle(model.t.muted)
            }
          }
          Color.clear.frame(height: 1).id("bottom")
        }.padding(20)
      }.background(model.t.base.opacity(0.92), in: RoundedRectangle(cornerRadius: 14)).padding(
        .bottom, 12
      ).onChange(of: model.exchanges.count) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
      }
    }
  }
}

struct FragmentInspector: View {
  @Binding var node: DesignFragment
  let t: CanvasTheme
  let close: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("Fragment", systemImage: "doc.text").font(.system(size: 11)).foregroundStyle(
          t.secondary)
        Spacer()
        Button(action: close) { Image(systemName: "xmark").font(.system(size: 11)) }.buttonStyle(
          StudioControl(t: t))
      }
      TextField("Title", text: $node.title).font(.system(size: 18, weight: .medium)).textFieldStyle(
        .plain)
      TextEditor(text: $node.text).font(.system(size: 13)).scrollContentBackground(.hidden).frame(
        height: 220
      ).lineSpacing(5)
      HStack {
        Circle().fill(t.muted).frame(width: 4, height: 4)
        Text(node.sourceID == nil ? "Working fragment" : "Working copy · source preserved").font(
          .system(size: 10))
        Spacer()
        Button("Done", action: close).buttonStyle(StudioAction(t: t))
      }.foregroundStyle(t.secondary)
    }.padding(18).background(t.card, in: RoundedRectangle(cornerRadius: 12)).overlay(
      RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.7)
    ).shadow(color: .black.opacity(0.2), radius: 25, y: 12)
  }
}

struct CanvasInputSurface: NSViewRepresentable {
  var onPan: (CGSize) -> Void
  var onZoom: (Double) -> Void
  func makeNSView(context: Context) -> InputView {
    let v = InputView()
    v.onPan = onPan
    v.onZoom = onZoom
    return v
  }
  func updateNSView(_ view: InputView, context: Context) {
    view.onPan = onPan
    view.onZoom = onZoom
  }
  final class InputView: NSView {
    var onPan: ((CGSize) -> Void)?
    var onZoom: ((Double) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDragged(with event: NSEvent) {
      onPan?(CGSize(width: event.deltaX, height: event.deltaY))
    }
    override func scrollWheel(with event: NSEvent) {
      if event.modifierFlags.contains(.command) {
        onZoom?(Double(event.scrollingDeltaY) * 0.005)
      } else {
        onPan?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
      }
    }
    override func magnify(with event: NSEvent) { onZoom?(Double(event.magnification)) }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
  }
}
