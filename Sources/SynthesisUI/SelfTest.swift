import AppKit
import Foundation
import SynthesisCore

/// In-process interaction check for the isolated runner. It posts real mouse and key events to
/// the application's own window, so pointer gestures are exercised without moving the user's
/// cursor or touching another application. Never runs against the normal database.
extension Studio {
  @MainActor public func runInteractionSelfTest(
    window: NSWindow, snapshot: @escaping (String) -> Void
  ) async -> [String] {
    var log: [String] = []
    var number = 0
    func pause(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
    func mouse(_ type: NSEvent.EventType, _ point: CGPoint, clicks: Int = 1) {
      guard let content = window.contentView else { return }
      number += 1
      let event = NSEvent.mouseEvent(
        with: type, location: NSPoint(x: point.x, y: content.bounds.height - point.y),
        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber, context: nil, eventNumber: number, clickCount: clicks,
        pressure: type == .leftMouseUp ? 0 : 1)
      if let event { NSApp.postEvent(event, atStart: false) }
    }
    func click(_ point: CGPoint, clicks: Int = 1) async {
      mouse(.leftMouseDown, point, clicks: clicks)
      await pause(60)
      mouse(.leftMouseUp, point, clicks: clicks)
      await pause(350)
    }
    func drag(from: CGPoint, by delta: CGSize, hold: (() async -> Void)? = nil) async {
      mouse(.leftMouseDown, from)
      await pause(80)
      for step in 1...12 {
        let f = Double(step) / 12
        mouse(.leftMouseDragged, CGPoint(x: from.x + delta.width * f, y: from.y + delta.height * f))
        await pause(25)
      }
      await hold?()
      mouse(.leftMouseUp, CGPoint(x: from.x + delta.width, y: from.y + delta.height))
      await pause(600)
    }
    func key(_ code: UInt16, _ characters: String) async {
      for type in [NSEvent.EventType.keyDown, .keyUp] {
        if let event = NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
          context: nil, characters: characters, charactersIgnoringModifiers: characters,
          isARepeat: false, keyCode: code)
        {
          window.sendEvent(event)
        }
      }
      await pause(450)
    }
    func board() -> CanvasDocument? {
      guard
        let saved = try? store.boards(worldID: worldID, kind: "canvas").first(where: {
          $0.id == canvasBoardID
        })
      else { return nil }
      return try? JSONDecoder().decode(CanvasDocument.self, from: Data(saved.content.utf8))
    }
    // Gestures are ignored unless this window is key in the active app. If someone clicks
    // elsewhere mid-run, say so instead of reporting a product failure.
    var focusLost = false
    func check(_ name: String, _ passed: Bool, _ detail: String = "") {
      let focused = NSApp.isActive && window.isKeyWindow
      if !focused { focusLost = true }
      let verdict = passed ? "PASS" : (focusLost ? "SKIP (window lost focus)" : "FAIL")
      log.append("\(verdict) \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    }
    func refocus() async {
      guard !(NSApp.isActive && window.isKeyWindow) else { return }
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      await pause(400)
      focusLost = false
    }
    guard let content = window.contentView else { return ["FAIL no content view"] }
    let size = content.bounds.size
    let column = Metric.sidebar + 8
    let area = CGSize(width: size.width - column, height: size.height - Metric.bar)
    func screen(_ card: CanvasCard, _ viewport: BoardViewport) -> CGPoint {
      CGPoint(
        x: column + area.width / 2 + card.x * viewport.zoom + viewport.x,
        y: Metric.bar + area.height / 2 + card.y * viewport.zoom + viewport.y)
    }

    // 1. Controls inside the integrated header receive clicks beneath the title bar.
    let before = collapsed
    await click(CGPoint(x: 98, y: Metric.bar / 2))
    check("header control under title bar is clickable", collapsed != before)
    if collapsed != before { toggleSidebar() }
    await pause(400)

    await refocus()
    // 1b. A SwiftUI tap gesture (palette row) responds to posted events.
    palette = true
    await pause(700)
    await refocus()
    // Rows start below the 52-point field: section label, then Conversation, Canvas, Library…
    await click(CGPoint(x: size.width / 2, y: 96 + 52 + 8 + 26 + 34 * 2 + 17))
    check("tap gesture on a palette row navigates", destination == .library, destination.rawValue)
    palette = false
    navigate(.canvas)
    await pause(900)

    await refocus()
    // 2. Dragging a card moves it, the connectors follow mid-drag, and the move is saved.
    guard let start = board(), let viewport = start.viewport,
      let mira = start.cards.first(where: { $0.text == "Mira Vale" })
    else {
      check("board fixture is readable", false)
      return log
    }
    await drag(from: screen(mira, viewport), by: CGSize(width: -120, height: 70)) {
      snapshot("selftest-card-drag-mid")
    }
    let moved = board()?.cards.first { $0.id == mira.id }
    let dx = (moved?.x ?? mira.x) - mira.x
    let dy = (moved?.y ?? mira.y) - mira.y
    check(
      "card drag moves and persists the card",
      abs(dx + 120 / viewport.zoom) < 3 && abs(dy - 70 / viewport.zoom) < 3,
      "Δ(\(Int(dx)), \(Int(dy))) expected (\(Int(-120 / viewport.zoom)), \(Int(70 / viewport.zoom)))"
    )
    snapshot("selftest-card-drag-end")

    // 3. Undo restores the previous layout.
    canvasUndo?(true)
    await pause(500)
    let restored = board()?.cards.first { $0.id == mira.id }
    check("undo restores the card position", restored?.x == mira.x && restored?.y == mira.y)

    await refocus()
    // 3a. Dragging a card's connection handle onto another card asks for the relationship label.
    let relationsBefore = (try? store.relations(worldID: worldID).count) ?? -1
    if let current = board(), let v = current.viewport,
      let from = current.cards.first(where: { $0.text == "Mira Vale" }),
      let to = current.cards.first(where: { $0.text == "The art of remembrance" })
    {
      let origin = screen(from, v)
      await click(origin)
      await refocus()
      let handle = CGPoint(x: origin.x + 150 * v.zoom + 9, y: origin.y)
      let target = screen(to, v)
      await drag(
        from: handle, by: CGSize(width: target.x - handle.x, height: target.y - handle.y)
      ) { snapshot("selftest-connect-mid") }
      await pause(500)
      let sheet = window.attachedSheet
      // The sheet itself is key while it is open, so judge focus by the app here.
      log.append(
        "\(sheet != nil ? "PASS" : (NSApp.isActive ? "FAIL" : "SKIP (window lost focus)")) handle drag onto a card opens the connection sheet"
      )
      snapshot("selftest-connect-sheet")
      log.append(
        "\((try? store.relations(worldID: worldID).count) == relationsBefore ? "PASS" : "FAIL") no relationship exists until it is labelled and saved"
      )
      if let sheet {
        // Close it the way a person would: Escape triggers the sheet's cancel action.
        for type in [NSEvent.EventType.keyDown, .keyUp] {
          if let escape = NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: sheet.windowNumber,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53)
          {
            NSApp.sendEvent(escape)
          }
        }
        await pause(800)
      }
      guard window.attachedSheet == nil else {
        log.append("FAIL connection sheet could not be dismissed; remaining checks not run")
        return log
      }
      await click(CGPoint(x: column + 40, y: Metric.bar + 40))
    }

    await refocus()
    // 4. Dragging empty space draws a marquee and selects what it touches.
    let cards = board()?.cards ?? []
    let top = cards.map { screen($0, viewport).y }.min() ?? 200
    let left = cards.map { screen($0, viewport).x }.min() ?? 400
    let right = cards.map { screen($0, viewport).x }.max() ?? 900
    await drag(
      from: CGPoint(x: left - 190, y: top - 110),
      by: CGSize(width: right - left + 380, height: 150)
    ) { snapshot("selftest-marquee-mid") }
    snapshot("selftest-marquee-end")

    // 5. Delete removes the marquee selection from the board but keeps the source records.
    let recordCount = records.count
    await key(51, "\u{7F}")
    let afterDelete = board()?.cards.count ?? -1
    check(
      "delete key removes selected cards, records stay",
      afterDelete < cards.count
        && afterDelete >= 0 && (try? store.records(worldID: worldID).count) == recordCount,
      "\(cards.count) → \(afterDelete) cards, \(recordCount) records")
    canvasUndo?(true)
    await pause(500)
    check("undo restores removed cards", board()?.cards.count == cards.count)

    await refocus()
    // 6. Double-clicking a card opens its record; closing returns to the canvas.
    await click(CGPoint(x: 400, y: size.height - 160))
    if let current = board(), let v = current.viewport,
      let card = current.cards.first(where: { $0.text == "The art of remembrance" })
    {
      let point = screen(card, v)
      await click(point)
      // 6a. Arrow keys nudge the selected card by ten points.
      await key(124, "\u{F703}")
      let nudged = board()?.cards.first { $0.id == card.id }
      check(
        "arrow key nudges the selected card", nudged?.x == card.x + 10 && nudged?.y == card.y,
        "x \(Int(card.x)) → \(Int(nudged?.x ?? .nan))")
      canvasUndo?(true)
      await pause(400)
      mouse(.leftMouseDown, point, clicks: 2)
      await pause(60)
      mouse(.leftMouseUp, point, clicks: 2)
      await pause(700)
      check(
        "double-click opens the card's record",
        selectedRecord?.title == "The art of remembrance", selectedRecord?.title ?? "nothing open")
      snapshot("selftest-open-record")
      closeRecord()
      await pause(600)
      check("closing the record returns to Canvas", selectedRecord == nil && destination == .canvas)
    }

    await refocus()
    // 7. The companion divider resizes the docked conversation.
    companionWidth = 400
    companionExpanded = true
    await pause(900)
    await drag(
      from: CGPoint(x: size.width - 400 - 4.5, y: size.height / 2),
      by: CGSize(width: -44, height: 0))
    check(
      "companion divider drag resizes the panel", abs(companionWidth - 444) < 4,
      "width \(Int(companionWidth))")
    snapshot("selftest-companion-resized")
    companionExpanded = false
    await pause(500)

    await refocus()
    // 8. Graph: dragging a node repositions it without changing stored relationships.
    let relationCount = (try? store.relations(worldID: worldID).count) ?? -1
    navigate(.knowledge)
    await pause(900)
    snapshot("selftest-graph-before")
    await drag(
      from: CGPoint(x: column + area.width / 2, y: Metric.bar + area.height / 2 + 14),
      by: CGSize(width: 0, height: 150))
    snapshot("selftest-graph-after")
    check(
      "graph interaction leaves relationships untouched",
      (try? store.relations(worldID: worldID).count) == relationCount)

    return log
  }
}
