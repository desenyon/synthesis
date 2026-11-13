import AppKit
import SwiftUI

final class ComposerTextView: NSTextView {
  var onSubmit: (() -> Void)?
  var placeholder = ""
  var placeholderColor = NSColor.secondaryLabelColor
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    if string.isEmpty {
      (placeholder as NSString).draw(
        at: NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height),
        withAttributes: [
          .font: font ?? NSFont.systemFont(ofSize: 15), .foregroundColor: placeholderColor,
        ])
    }
  }
  override func keyDown(with event: NSEvent) {
    if event.keyCode == 36 && !event.modifierFlags.contains(.shift) && !hasMarkedText() {
      onSubmit?()
      return
    }
    super.keyDown(with: event)
  }
}

/// Plain-text message input. Return sends, Shift-Return inserts a line. Reports its content
/// height so the composer can grow with the text instead of guessing from character counts.
struct ComposerInput: NSViewRepresentable {
  @Binding var text: String
  var placeholder: String
  var color: Color
  var placeholderColor: Color = .secondary
  var autofocus = false
  var onHeight: (CGFloat) -> Void = { _ in }
  var submit: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    let view = ComposerTextView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = false
    scroll.documentView = view
    view.isRichText = false
    view.drawsBackground = false
    view.font = .systemFont(ofSize: 15)
    view.textColor = NSColor(color)
    view.insertionPointColor = NSColor(color)
    view.textContainerInset = NSSize(width: 0, height: 4)
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.autoresizingMask = [.width]
    view.textContainer?.widthTracksTextView = true
    view.delegate = context.coordinator
    view.onSubmit = submit
    view.allowsUndo = true
    view.setAccessibilityLabel("Message your world")
    view.placeholder = placeholder
    view.placeholderColor = NSColor(placeholderColor)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 3
    view.defaultParagraphStyle = paragraph
    view.typingAttributes = [
      .font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor(color),
      .paragraphStyle: paragraph,
    ]
    if autofocus {
      DispatchQueue.main.async { [weak view] in view?.window?.makeFirstResponder(view) }
    }
    return scroll
  }
  func updateNSView(_ view: NSScrollView, context: Context) {
    guard let editor = view.documentView as? ComposerTextView else { return }
    context.coordinator.parent = self
    if editor.string != text { editor.string = text }
    editor.textColor = NSColor(color)
    editor.insertionPointColor = NSColor(color)
    editor.placeholderColor = NSColor(placeholderColor)
    editor.placeholder = placeholder
    editor.onSubmit = submit
    editor.needsDisplay = true
    context.coordinator.measure(editor)
  }
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: ComposerInput
    private var reported: CGFloat = 0
    init(_ parent: ComposerInput) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      guard let editor = notification.object as? NSTextView else { return }
      parent.text = editor.string
      measure(editor)
    }
    func measure(_ editor: NSTextView) {
      guard let container = editor.textContainer, let layout = editor.layoutManager else { return }
      layout.ensureLayout(for: container)
      let height =
        ceil(layout.usedRect(for: container).height) + editor.textContainerInset.height * 2
      guard abs(height - reported) > 0.5 else { return }
      reported = height
      let callback = parent.onHeight
      DispatchQueue.main.async { callback(height) }
    }
  }
}

/// Lets toolbar controls act on the document text view without owning it.
@MainActor final class EditorHandle {
  weak var view: NSTextView?
  func send(_ selector: String) {
    guard let view else { return }
    view.window?.makeFirstResponder(view)
    NSApp.sendAction(Selector(selector), to: view, from: nil)
  }
  /// Sets the paragraph(s) under the selection to a heading size, or back to body text.
  func heading(_ size: CGFloat, bold: Bool) {
    guard let view, let storage = view.textStorage else { return }
    let range = (view.string as NSString).paragraphRange(for: view.selectedRange())
    let font =
      bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
    guard view.shouldChangeText(in: range, replacementString: nil) else { return }
    storage.addAttribute(.font, value: font, range: range)
    view.didChangeText()
    view.typingAttributes[.font] = font
    view.window?.makeFirstResponder(view)
  }
  func focus() {
    guard let view else { return }
    view.window?.makeFirstResponder(view)
  }
}

struct RichDocumentEditor: NSViewRepresentable {
  let id: String
  let body: String
  let rtf: String?
  let t: Theme
  let reloadToken: Int
  var handle: EditorHandle?
  var changed: (String, String?) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    let view = NSTextView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.scrollerStyle = .overlay
    scroll.documentView = view
    view.isRichText = true
    view.importsGraphics = false
    view.allowsUndo = true
    view.drawsBackground = false
    view.font = .systemFont(ofSize: 16)
    view.textColor = NSColor(t.text)
    view.insertionPointColor = NSColor(t.accent)
    view.textContainerInset = NSSize(width: 0, height: 10)
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.autoresizingMask = [.width]
    view.textContainer?.widthTracksTextView = true
    view.delegate = context.coordinator
    view.isAutomaticQuoteSubstitutionEnabled = true
    view.isAutomaticLinkDetectionEnabled = true
    view.setAccessibilityLabel("Document body")
    install(view)
    handle?.view = view
    context.coordinator.token = reloadToken
    return scroll
  }
  private var paragraph: NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 6
    style.paragraphSpacing = 12
    return style
  }
  private func install(_ view: NSTextView) {
    if let rtf, let data = Data(base64Encoded: rtf),
      let attributed = NSAttributedString(rtf: data, documentAttributes: nil)
    {
      view.textStorage?.setAttributedString(attributed)
    } else {
      view.textStorage?.setAttributedString(
        NSAttributedString(
          string: body,
          attributes: [
            .font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor(t.text),
            .paragraphStyle: paragraph,
          ]))
    }
    view.typingAttributes = [
      .font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor(t.text),
      .paragraphStyle: paragraph,
    ]
    view.textColor = NSColor(t.text)
  }
  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.parent = self
    guard let view = scroll.documentView as? NSTextView else { return }
    handle?.view = view
    if context.coordinator.token != reloadToken {
      context.coordinator.updating = true
      install(view)
      view.undoManager?.removeAllActions()
      context.coordinator.token = reloadToken
      context.coordinator.updating = false
    }
    view.textColor = NSColor(t.text)
    view.insertionPointColor = NSColor(t.accent)
  }
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: RichDocumentEditor
    var token = 0
    var updating = false
    init(_ parent: RichDocumentEditor) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      guard !updating, let view = notification.object as? NSTextView else { return }
      let data = try? view.attributedString().data(
        from: NSRange(location: 0, length: view.attributedString().length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
      parent.changed(view.string, data?.base64EncodedString())
    }
  }
}

/// Pan, zoom, marquee and keyboard input for spatial workspaces. Trackpad scrolling pans;
/// pinch or ⌘-scroll zooms around the pointer. Coordinates are top-left based to match SwiftUI.
struct CanvasInputSurface: NSViewRepresentable {
  enum Phase { case began, changed, ended }
  var onPan: (CGSize) -> Void
  /// Multiplicative zoom factor and the pointer location it should stay anchored to.
  var onZoom: (Double, CGPoint) -> Void
  var onClick: () -> Void = {}
  /// Primary-button drag across empty space: start point, current point, phase.
  var onDrag: ((CGPoint, CGPoint, Phase) -> Void)?
  /// Return true when the key was handled.
  var onKey: ((NSEvent) -> Bool)?
  var focus: InputFocus?
  func makeNSView(context: Context) -> InputView {
    let view = InputView()
    apply(view)
    return view
  }
  func updateNSView(_ view: InputView, context: Context) { apply(view) }
  private func apply(_ view: InputView) {
    view.onPan = onPan
    view.onZoom = onZoom
    view.onClick = onClick
    view.onDrag = onDrag
    view.onKey = onKey
    focus?.view = view
  }
  final class InputView: NSView {
    var onPan: ((CGSize) -> Void)?
    var onZoom: ((Double, CGPoint) -> Void)?
    var onClick: (() -> Void)?
    var onDrag: ((CGPoint, CGPoint, Phase) -> Void)?
    var onKey: ((NSEvent) -> Bool)?
    private var origin: CGPoint?
    private var dragging = false
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private func location(_ event: NSEvent) -> CGPoint {
      convert(event.locationInWindow, from: nil)
    }
    override func mouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      origin = location(event)
      dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
      guard let origin else { return }
      let point = location(event)
      if let onDrag {
        if !dragging && hypot(point.x - origin.x, point.y - origin.y) < 3 { return }
        onDrag(origin, point, dragging ? .changed : .began)
        dragging = true
      } else {
        dragging = true
        onPan?(CGSize(width: event.deltaX, height: event.deltaY))
      }
    }
    override func mouseUp(with event: NSEvent) {
      if dragging, let origin, let onDrag {
        onDrag(origin, location(event), .ended)
      } else if !dragging {
        onClick?()
      }
      origin = nil
      dragging = false
    }
    override func otherMouseDragged(with event: NSEvent) {
      onPan?(CGSize(width: event.deltaX, height: event.deltaY))
    }
    override func scrollWheel(with event: NSEvent) {
      if event.modifierFlags.contains(.command) {
        onZoom?(exp(Double(event.scrollingDeltaY) * 0.01), location(event))
      } else {
        let precise = event.hasPreciseScrollingDeltas
        onPan?(
          CGSize(
            width: event.scrollingDeltaX * (precise ? 1 : 8),
            height: event.scrollingDeltaY * (precise ? 1 : 8)))
      }
    }
    override func magnify(with event: NSEvent) {
      onZoom?(1 + Double(event.magnification), location(event))
    }
    override func keyDown(with event: NSEvent) {
      if onKey?(event) != true { super.keyDown(with: event) }
    }
  }
}
/// Holds the input surface so card interactions can return keyboard focus to the board.
@MainActor final class InputFocus {
  weak var view: NSView?
  func take() { view?.window?.makeFirstResponder(view) }
}
