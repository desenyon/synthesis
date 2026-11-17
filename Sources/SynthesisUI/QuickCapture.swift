import AppKit
import Combine
import SwiftUI
import SynthesisCore

/// A native utility panel: it receives typing without activating or navigating the main window.
final class QuickCapturePanel: NSPanel {
  static let headerHeight: CGFloat = 48
  var dismiss: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
  override func cancelOperation(_ sender: Any?) { dismiss?() }
  func layoutWindowControls() {
    guard let close = standardWindowButton(.closeButton),
      let minimize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let container = close.superview?.superview
    else { return }
    var bar = container.frame
    bar.size.height = Self.headerHeight
    bar.origin.y = frame.height - Self.headerHeight
    if container.frame != bar { container.frame = bar }
    for (index, button) in [close, minimize, zoom].enumerated() {
      let origin = NSPoint(
        x: 16 + CGFloat(index) * 20, y: (Self.headerHeight - button.frame.height) / 2)
      if button.frame.origin != origin { button.setFrameOrigin(origin) }
    }
  }
  override func update() {
    super.update()
    layoutWindowControls()
  }
}

@MainActor public final class QuickCaptureController: NSObject, NSWindowDelegate {
  private weak var studio: Studio?
  let model: QuickCaptureModel
  private let input = ComposerHandle()
  private var observation: AnyCancellable?
  private var shortcut: QuickCaptureShortcut?
  private(set) var panel: QuickCapturePanel?

  public init(studio: Studio) {
    self.studio = studio
    self.model = QuickCaptureModel(store: studio.store)
    super.init()
    model.didCapture = { [weak studio] record in
      guard let studio, studio.worldID == record.worldID else { return }
      do { try studio.reload() } catch { studio.error = error.localizedDescription }
      studio.toast = Toast(message: "Idea captured", icon: "lightbulb")
    }
    observation = studio.$dark.combineLatest(studio.$preferences).sink {
      [weak self] dark, preferences in
      guard let self else { return }
      model.dark = dark
      model.oled = preferences.darkPalette == .oled
      panel?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
      panel?.backgroundColor = NSColor(model.t.background)
    }
  }

  /// Install only during an ordinary launch, never in capture/test processes.
  public func installShortcut() {
    guard shortcut == nil else { return }
    let candidate = QuickCaptureShortcut { [weak self] in self?.open() }
    model.shortcutUnavailable = !candidate.install()
    shortcut = candidate
  }

  public func open() {
    guard let studio else { return }
    if panel?.isVisible != true { _ = model.prepare(worldID: studio.worldID) }
    let panel = preparePanel()
    if !panel.isVisible { panel.center() }
    panel.makeKeyAndOrderFront(nil)
    DispatchQueue.main.async { [weak self] in
      guard let self, let editor = input.view else { return }
      panel.makeFirstResponder(editor)
    }
  }

  /// Called by the app before quitting, so a failing disk never silently drops the visible note.
  public func flush() -> Bool { model.flush() }

  func dismiss() {
    guard model.flush() else { return }
    panel?.orderOut(nil)
  }

  public func windowShouldClose(_ sender: NSWindow) -> Bool { model.flush() }
  public func windowDidResize(_ notification: Notification) { panel?.layoutWindowControls() }

  func save() {
    guard model.save() != nil else { return }
    panel?.orderOut(nil)
  }

  @discardableResult func preparePanel() -> QuickCapturePanel {
    if let panel { return panel }
    let panel = QuickCapturePanel(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 330),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.title = "Quick Capture"
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isReleasedWhenClosed = false
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.minSize = NSSize(width: 420, height: 280)
    panel.maxSize = NSSize(width: 920, height: 760)
    panel.appearance = NSAppearance(named: model.dark ? .darkAqua : .aqua)
    panel.backgroundColor = NSColor(model.t.background)
    panel.delegate = self
    panel.dismiss = { [weak self] in self?.dismiss() }
    let hosting = NSHostingView(
      rootView: QuickCaptureView(
        model: model, input: input, save: { [weak self] in self?.save() },
        dismiss: { [weak self] in self?.dismiss() }))
    // The user owns the utility window's size. A new error row must shrink the scrollable
    // input rather than make NSHostingView resize the whole panel to its ideal height.
    hosting.sizingOptions = []
    hosting.autoresizingMask = [.width, .height]
    panel.contentView = hosting
    self.panel = panel
    return panel
  }
}

private struct QuickCaptureView: View {
  @ObservedObject var model: QuickCaptureModel
  let input: ComposerHandle
  var save: () -> Void
  var dismiss: () -> Void

  var body: some View {
    let t = model.t
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: Space.sm) {
        Text("Quick capture").font(.studio(.label)).lineLimit(1).layoutPriority(1)
        Spacer(minLength: Space.sm)
        worldPicker
      }.foregroundStyle(t.text)
        .padding(.leading, 88).padding(.trailing, Space.lg).frame(
          height: QuickCapturePanel.headerHeight)
      Rectangle().fill(t.hairline).frame(height: 1)
      ComposerInput(
        text: Binding(get: { model.draft.text }, set: { model.edit($0) }),
        placeholder: "An idea, a fragment, something to come back to…", color: t.text,
        placeholderColor: t.muted, accent: t.accent, accentSoft: t.accentSoft,
        sendShortcut: .commandEnter, handle: input,
        onMentionKey: { key in
          if key == .cancel {
            dismiss()
            return true
          }
          return false
        }, submit: save
      ).frame(maxWidth: .infinity, minHeight: 64, maxHeight: .infinity)
        .padding(.horizontal, Space.xl).padding(.vertical, Space.lg)
        .accessibilityLabel("Idea to capture")
      if let error = model.error {
        Text(error).font(.studio(.caption)).foregroundStyle(t.danger)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, Space.xl).padding(.bottom, Space.md)
      }
      HStack(spacing: Space.md) {
        VStack(alignment: .leading, spacing: Space.xs) {
          Text(
            model.draft.text.isEmpty
              ? "Saved ideas appear in Library"
              : (model.saved
                ? "Draft kept on this Mac"
                : (model.error == nil ? "Keeping draft…" : "Draft not yet saved"))
          )
          .font(.studio(.caption)).foregroundStyle(t.muted)
          if model.shortcutUnavailable {
            Text("Shortcut unavailable · use File → Quick Capture")
              .font(.studio(.caption)).foregroundStyle(t.secondary)
          }
        }
        Spacer(minLength: Space.sm)
        Button(action: save) {
          HStack(spacing: Space.sm) {
            Text("Save idea")
            Text("⌘↵").opacity(0.7).accessibilityHidden(true)
          }
        }.buttonStyle(QuietButton(t: t, primary: true)).disabled(!model.canSave)
          .help("Save an idea in \(model.worldName) without changing the current workspace")
      }.padding(.horizontal, Space.xl).padding(.bottom, Space.lg)
    }.background(t.background)
      .ignoresSafeArea(.container, edges: .top)
      .environment(\.studioTheme, t)
      .environment(\.studioOpaqueMaterials, model.opaqueMaterials)
      .preferredColorScheme(model.dark ? .dark : .light)
      .onExitCommand(perform: dismiss)
  }

  private var worldPicker: some View {
    PlainMenu(flexible: true) {
      ForEach(model.worlds, id: \.id) { world in
        Button {
          model.selectWorld(world.id)
        } label: {
          HStack(spacing: Space.sm) {
            Text(world.name).lineLimit(1)
            Spacer(minLength: 4)
            if model.worldID == world.id { StudioIcon("checkmark", size: 13) }
          }
        }
      }
    } label: {
      HStack(spacing: Space.sm) {
        StudioIcon("globe", size: 14)
        Text(model.worldName).font(.studio(.label)).lineLimit(1).truncationMode(.tail)
        StudioIcon("chevron.down", size: 10)
      }.foregroundStyle(model.t.secondary).padding(.horizontal, 10).padding(.vertical, 6)
        .background(model.t.secondarySurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
    }.frame(maxWidth: 260, alignment: .trailing)
      .accessibilityLabel("Capture universe").accessibilityValue(model.worldName)
      .help("Choose where this idea is saved; your main workspace stays where it is")
  }
}
