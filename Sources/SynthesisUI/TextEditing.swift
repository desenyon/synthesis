import AppKit
import SwiftUI

/// Converts between the stored message text, where a lore reference is a Markdown link
/// `[Title](synthesis://record/<id>)`, and the composer's display, where it is one styled token.
enum MentionCodec {
  static let key = NSAttributedString.Key("synthesisRecord")
  private static let pattern = try? NSRegularExpression(
    pattern: #"\[([^\]\n]+)\]\(synthesis://record/([A-Za-z0-9-]+)\)"#)
  static func attributed(
    _ markdown: String, base: [NSAttributedString.Key: Any], accent: NSColor, soft: NSColor
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let source = markdown as NSString
    var cursor = 0
    for match in pattern?.matches(in: markdown, range: NSRange(location: 0, length: source.length))
      ?? []
    {
      result.append(
        NSAttributedString(
          string: source.substring(
            with: NSRange(location: cursor, length: match.range.location - cursor)),
          attributes: base))
      result.append(
        token(
          title: source.substring(with: match.range(at: 1)),
          id: source.substring(with: match.range(at: 2)), base: base, accent: accent, soft: soft))
      cursor = match.range.location + match.range.length
    }
    result.append(
      NSAttributedString(string: source.substring(from: cursor), attributes: base))
    return result
  }
  static func token(
    title: String, id: String, base: [NSAttributedString.Key: Any], accent: NSColor, soft: NSColor
  ) -> NSAttributedString {
    var attributes = base
    attributes[key] = id
    attributes[.foregroundColor] = accent
    attributes[.backgroundColor] = soft
    return NSAttributedString(string: title, attributes: attributes)
  }
  static func markdown(_ attributed: NSAttributedString) -> String {
    var output = ""
    attributed.enumerateAttribute(
      key, in: NSRange(location: 0, length: attributed.length)
    ) { value, range, _ in
      let text = attributed.attributedSubstring(from: range).string
      if let id = value as? String {
        output += "[\(text)](synthesis://record/\(id))"
      } else {
        output += text
      }
    }
    return output
  }
  /// The `@query` being typed immediately before `caret`, if any, and its range.
  static func query(in text: NSString, caret: Int) -> (text: String, range: NSRange)? {
    var index = caret - 1
    while index >= 0, caret - index <= 40 {
      let character = text.character(at: index)
      if character == 10 { return nil }
      if character == 64 {  // "@"
        let boundary = index == 0 || [32, 10, 40, 9].contains(Int(text.character(at: index - 1)))
        guard boundary else { return nil }
        let range = NSRange(location: index, length: caret - index)
        return (
          text.substring(with: NSRange(location: index + 1, length: caret - index - 1)), range
        )
      }
      index -= 1
    }
    return nil
  }
}

final class ComposerTextView: NSTextView {
  var onSubmit: (() -> Void)?
  /// Returns true when a mention list is open and consumed the key.
  var onMentionKey: ((MentionKey) -> Bool)?
  enum MentionKey { case up, down, commit, cancel }
  var placeholder = ""
  var placeholderColor = NSColor.secondaryLabelColor
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    if string.isEmpty {
      (placeholder as NSString).draw(
        at: NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height),
        withAttributes: [
          .font: font ?? StudioTypography.native(size: 15), .foregroundColor: placeholderColor,
        ])
    }
  }
  override func keyDown(with event: NSEvent) {
    if !hasMarkedText() {
      let key: MentionKey? =
        switch event.keyCode {
        case 126: .up
        case 125: .down
        case 36, 48: .commit
        case 53: .cancel
        default: nil
        }
      if let key, onMentionKey?(key) == true { return }
    }
    if event.keyCode == 36 && !event.modifierFlags.contains(.shift) && !hasMarkedText() {
      onSubmit?()
      return
    }
    super.keyDown(with: event)
  }
  /// Pasted text never brings its own fonts or colours into a message.
  override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
}

/// Lets the composer's buttons and mention list insert a reference at the caret.
@MainActor final class ComposerHandle {
  weak var view: ComposerTextView?
  var insert: ((_ title: String, _ id: String, _ replacing: NSRange?) -> Void)?
  var mentionRange: NSRange?
  func insertReference(title: String, id: String, replacingQuery: Bool = false) {
    insert?(title, id, replacingQuery ? mentionRange : nil)
  }
}

/// Message input. Return sends, Shift-Return inserts a line. Lore references appear as tokens
/// and are stored as Markdown links. Reports its content height and any `@query` being typed.
struct ComposerInput: NSViewRepresentable {
  @Binding var text: String
  var placeholder: String
  var color: Color
  var placeholderColor: Color = .secondary
  var accent: Color = .accentColor
  var accentSoft: Color = .clear
  var autofocus = false
  var handle: ComposerHandle?
  var onHeight: (CGFloat) -> Void = { _ in }
  /// The text after `@` while a mention is being typed, or nil.
  var onMention: (String?) -> Void = { _ in }
  var onMentionKey: (ComposerTextView.MentionKey) -> Bool = { _ in false }
  var submit: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  var baseAttributes: [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 3
    return [
      .font: StudioTypography.native(size: 15), .foregroundColor: NSColor(color),
      .paragraphStyle: paragraph,
    ]
  }
  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    let view = ComposerTextView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = false
    scroll.documentView = view
    view.isRichText = true
    view.importsGraphics = false
    view.usesFontPanel = false
    view.usesRuler = false
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
    view.allowsUndo = true
    view.isAutomaticLinkDetectionEnabled = false
    view.setAccessibilityLabel("Message your world")
    view.typingAttributes = baseAttributes
    context.coordinator.view = view
    if autofocus {
      DispatchQueue.main.async { [weak view] in view?.window?.makeFirstResponder(view) }
    }
    return scroll
  }
  func updateNSView(_ scroll: NSScrollView, context: Context) {
    guard let editor = scroll.documentView as? ComposerTextView else { return }
    let coordinator = context.coordinator
    coordinator.parent = self
    handle?.view = editor
    handle?.insert = { [weak coordinator] title, id, range in
      coordinator?.insertToken(title: title, id: id, replacing: range)
    }
    if MentionCodec.markdown(editor.attributedString()) != text {
      coordinator.updating = true
      editor.textStorage?.setAttributedString(
        MentionCodec.attributed(
          text, base: baseAttributes, accent: NSColor(accent), soft: NSColor(accentSoft)))
      editor.setSelectedRange(NSRange(location: editor.attributedString().length, length: 0))
      coordinator.updating = false
    }
    editor.typingAttributes = baseAttributes
    editor.insertionPointColor = NSColor(color)
    editor.placeholderColor = NSColor(placeholderColor)
    editor.placeholder = placeholder
    editor.onSubmit = submit
    editor.onMentionKey = onMentionKey
    editor.needsDisplay = true
    coordinator.measure(editor)
  }
  @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: ComposerInput
    weak var view: ComposerTextView?
    var updating = false
    private var reported: CGFloat = 0
    private var lastQuery: String?
    init(_ parent: ComposerInput) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      guard !updating, let editor = notification.object as? NSTextView else { return }
      editor.typingAttributes = parent.baseAttributes
      parent.text = MentionCodec.markdown(editor.attributedString())
      measure(editor)
      detect(editor)
    }
    func textViewDidChangeSelection(_ notification: Notification) {
      guard !updating, let editor = notification.object as? NSTextView else { return }
      editor.typingAttributes = parent.baseAttributes
      detect(editor)
    }
    /// A reference is edited as a whole: touching part of a token removes all of it.
    func textView(
      _ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?
    ) -> Bool {
      guard !updating, let storage = textView.textStorage, storage.length > 0 else { return true }
      var union = range
      var touched = false
      storage.enumerateAttribute(
        MentionCodec.key, in: NSRange(location: 0, length: storage.length)
      ) { value, tokenRange, _ in
        guard value != nil else { return }
        let inside =
          NSIntersectionRange(tokenRange, range).length > 0
          || (range.length == 0 && range.location > tokenRange.location
            && range.location < NSMaxRange(tokenRange))
        if inside,
          !(range.location <= tokenRange.location && NSMaxRange(range) >= NSMaxRange(tokenRange))
        {
          union = NSUnionRange(union, tokenRange)
          touched = true
        }
      }
      guard touched else { return true }
      updating = true
      if textView.shouldChangeText(in: union, replacementString: replacementString ?? "") {
        storage.replaceCharacters(
          in: union,
          with: NSAttributedString(
            string: replacementString ?? "", attributes: parent.baseAttributes))
        textView.didChangeText()
      }
      updating = false
      textView.setSelectedRange(
        NSRange(location: union.location + (replacementString ?? "").utf16.count, length: 0))
      textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
      return false
    }
    func insertToken(title: String, id: String, replacing: NSRange?) {
      guard let editor = view, let storage = editor.textStorage else { return }
      let target = replacing ?? editor.selectedRange()
      guard NSMaxRange(target) <= storage.length else { return }
      let piece = NSMutableAttributedString()
      let before =
        target.location > 0
        ? (storage.string as NSString).character(at: target.location - 1) : 32
      if replacing == nil, ![32, 10].contains(Int(before)) {
        piece.append(NSAttributedString(string: " ", attributes: parent.baseAttributes))
      }
      piece.append(
        MentionCodec.token(
          title: title, id: id, base: parent.baseAttributes, accent: NSColor(parent.accent),
          soft: NSColor(parent.accentSoft)))
      piece.append(NSAttributedString(string: " ", attributes: parent.baseAttributes))
      updating = true
      if editor.shouldChangeText(in: target, replacementString: piece.string) {
        storage.replaceCharacters(in: target, with: piece)
        editor.didChangeText()
      }
      updating = false
      editor.setSelectedRange(NSRange(location: target.location + piece.length, length: 0))
      editor.window?.makeFirstResponder(editor)
      textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
    }
    private func detect(_ editor: NSTextView) {
      let selection = editor.selectedRange()
      var found: (text: String, range: NSRange)?
      if selection.length == 0 {
        found = MentionCodec.query(in: editor.string as NSString, caret: selection.location)
        // An "@" that is part of an existing reference is not a new query.
        if let range = found?.range, let storage = editor.textStorage,
          storage.attribute(MentionCodec.key, at: range.location, effectiveRange: nil) != nil
        {
          found = nil
        }
      }
      parent.handle?.mentionRange = found?.range
      guard found?.text != lastQuery else { return }
      lastQuery = found?.text
      let callback = parent.onMention
      let value = found?.text
      DispatchQueue.main.async { callback(value) }
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
      StudioTypography.native(size: size, bold: bold)
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
            .font: StudioTypography.native(size: 16), .foregroundColor: NSColor(t.text),
            .paragraphStyle: paragraph,
          ]))
    }
    view.typingAttributes = [
      .font: StudioTypography.native(size: 16), .foregroundColor: NSColor(t.text),
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
