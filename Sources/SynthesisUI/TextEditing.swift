import AppKit
import SwiftUI

final class ComposerTextView: NSTextView {
  var onSubmit: (() -> Void)?
  var placeholder = ""
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    if string.isEmpty {
      (placeholder as NSString).draw(
        at: NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height),
        withAttributes: [
          .font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.secondaryLabelColor,
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
struct ComposerInput: NSViewRepresentable {
  @Binding var text: String
  var placeholder: String
  var color: Color
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
    view.font = .systemFont(ofSize: 16)
    view.textColor = NSColor(color)
    view.textContainerInset = NSSize(width: 2, height: 6)
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.autoresizingMask = [.width]
    view.textContainer?.widthTracksTextView = true
    view.delegate = context.coordinator
    view.onSubmit = submit
    view.setAccessibilityLabel("Message your world")
    view.placeholder = placeholder
    return scroll
  }
  func updateNSView(_ view: NSScrollView, context: Context) {
    guard let editor = view.documentView as? ComposerTextView else { return }
    context.coordinator.parent = self
    if editor.string != text { editor.string = text }
    editor.textColor = NSColor(color)
    editor.onSubmit = submit
    editor.needsDisplay = true
  }
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: ComposerInput
    init(_ parent: ComposerInput) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      if let editor = notification.object as? NSTextView { parent.text = editor.string }
    }
  }
}
struct RichDocumentEditor: NSViewRepresentable {
  let id: String
  let body: String
  let rtf: String?
  let t: Theme
  let reloadToken: Int
  var changed: (String, String?) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    let view = NSTextView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.documentView = view
    view.isRichText = true
    view.importsGraphics = false
    view.allowsUndo = true
    view.drawsBackground = false
    view.font = .systemFont(ofSize: 17)
    view.textColor = NSColor(t.text)
    view.textContainerInset = NSSize(width: 4, height: 16)
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.autoresizingMask = [.width]
    view.textContainer?.widthTracksTextView = true
    view.delegate = context.coordinator
    view.isAutomaticQuoteSubstitutionEnabled = true
    view.isAutomaticLinkDetectionEnabled = true
    view.setAccessibilityLabel("Document body")
    install(view)
    context.coordinator.token = reloadToken
    return scroll
  }
  private func install(_ view: NSTextView) {
    if let rtf, let data = Data(base64Encoded: rtf),
      let attributed = NSAttributedString(rtf: data, documentAttributes: nil)
    {
      view.textStorage?.setAttributedString(attributed)
    } else {
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineSpacing = 7
      paragraph.paragraphSpacing = 14
      view.textStorage?.setAttributedString(
        NSAttributedString(
          string: body,
          attributes: [
            .font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor(t.text),
            .paragraphStyle: paragraph,
          ]))
      view.typingAttributes = [
        .font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor(t.text),
        .paragraphStyle: paragraph,
      ]
    }
    view.textColor = NSColor(t.text)
  }
  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.parent = self
    guard let view = scroll.documentView as? NSTextView else { return }
    if context.coordinator.token != reloadToken {
      context.coordinator.updating = true
      install(view)
      view.undoManager?.removeAllActions()
      context.coordinator.token = reloadToken
      context.coordinator.updating = false
    }
    view.textColor = NSColor(t.text)
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
