import AppKit
import SwiftUI
import Testing

@testable import SynthesisUI

@MainActor struct ComposerLayoutTests {
  @Test func growingComposerRevealsFirstLineWithoutMovingCaret() throws {
    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 40))
    let editor = ComposerTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 800))
    editor.textContainerInset = NSSize(width: 0, height: 4)
    editor.textContainer?.containerSize = NSSize(
      width: 360, height: CGFloat.greatestFiniteMagnitude)
    scroll.documentView = editor
    let input = ComposerInput(
      text: .constant(""), placeholder: "A thought", color: .white, submit: {})
    let coordinator = input.makeCoordinator()
    editor.textStorage?.setAttributedString(
      NSAttributedString(string: "First line\n\nLast line", attributes: input.baseAttributes))
    editor.setSelectedRange(NSRange(location: 5, length: 0))
    // A multiline draft can retain a scroll offset from its formerly smaller viewport.
    scroll.contentView.scroll(to: NSPoint(x: 0, y: 24))
    coordinator.measure(editor)
    #expect(scroll.contentView.bounds.origin.y == 24)  // Still overflows: retain its position.
    scroll.setFrameSize(NSSize(width: 360, height: 200))
    // TextKit may still have the old document frame when the caret scroll runs after a resize.
    editor.setFrameSize(NSSize(width: 360, height: 800))
    scroll.contentView.scroll(to: NSPoint(x: 0, y: 24))
    #expect(scroll.contentView.bounds.origin.y == 24)
    coordinator.measure(editor)
    #expect(scroll.contentView.bounds.origin == .zero)
    #expect(editor.selectedRange() == NSRange(location: 5, length: 0))
    #expect(editor.string == "First line\n\nLast line")
  }
}
