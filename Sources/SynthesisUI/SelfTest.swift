import AppKit
import Foundation
import SynthesisCore

/// In-process interaction check for the isolated runner. It posts real mouse and key events to
/// the application's own window, so pointer gestures are exercised without moving the user's
/// cursor or touching another application. Never runs against the normal database.
extension Studio {
  @MainActor public func runInteractionSelfTest(
    window: NSWindow, snapshot: @escaping (String) async -> Void
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
    func key(_ code: UInt16, _ characters: String, target: NSWindow? = nil) async {
      let receiver = target ?? window
      for type in [NSEvent.EventType.keyDown, .keyUp] {
        if let event = NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: receiver.windowNumber,
          context: nil, characters: characters, charactersIgnoringModifiers: characters,
          isARepeat: false, keyCode: code)
        {
          receiver.sendEvent(event)
        }
      }
      await pause(450)
    }
    func storedBoard() -> CanvasBoardContent? {
      guard let id = canvasSession?.boardID,
        let saved = try? store.boards(worldID: worldID, kind: "canvas").first(where: { $0.id == id }
        )
      else { return nil }
      return try? CanvasBoardContent.decode(saved.content)
    }
    /// A card as the canvas reports it: scene position plus where its centre is in the window.
    func card(_ title: String) async -> (x: Double, y: Double, point: CGPoint)? {
      guard let id = records.first(where: { $0.title == title })?.id,
        let cards = await canvasSession?.probe()["cards"] as? [[String: Any]],
        let hit = cards.first(where: { $0["recordID"] as? String == id }),
        let x = hit["x"] as? Double, let y = hit["y"] as? Double,
        let cx = hit["clientX"] as? Double, let cy = hit["clientY"] as? Double
      else { return nil }
      return (x, y, CGPoint(x: Metric.sidebar + 8 + cx, y: Metric.bar + cy))
    }
    // Gestures are ignored unless this window is key in the active app. If someone clicks
    // elsewhere mid-run, say so instead of reporting a product failure.
    var focusLost = false
    func check(_ name: String, _ passed: Bool, _ detail: String = "") {
      let focused =
        NSApp.isActive && (window.isKeyWindow || window.attachedSheet?.isKeyWindow == true)
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

    // 1c. Exercise AppKit modal presentation, not the background capture's inline panel.
    navigate(.library)
    newRecordKind = "lore"
    sheet = .document
    await pause(700)
    let recordModal = window.attachedSheet
    check("New record opens a real modal sheet", recordModal?.isVisible == true)
    await snapshot("selftest-new-record-sheet")
    if let recordModal { await key(53, "\u{1b}", target: recordModal) }
    check("Escape dismisses the New record modal", sheet == nil && window.attachedSheet == nil)
    // Keep later tests independent if dismissal failed.
    sheet = nil
    await pause(350)

    navigate(.canvas)
    await pause(900)

    // 2. The board opens in the Excalidraw engine: the earlier layout is converted, records
    //    become cards and stored relationships become arrows.
    for _ in 0..<40 where canvasSession?.loaded != true { await pause(250) }
    await pause(900)
    let probe = await canvasSession?.probe() ?? [:]
    let cardCount = (probe["cards"] as? [[String: Any]])?.count ?? 0
    check(
      "board loads in the canvas engine with record cards and relationship arrows",
      canvasSession?.loaded == true && cardCount == 4 && (probe["relations"] as? Int ?? 0) >= 3,
      "\(cardCount) cards, \(probe["relations"] as? Int ?? 0) relationship arrows")
    let saved = storedBoard()
    check(
      "the converted board is saved in the new format and keeps the original layout",
      saved?.scene != nil && saved?.legacyRaw != nil && saved?.counts.cards == 4,
      "\(saved?.counts.elements ?? 0) elements stored")
    await snapshot("selftest-canvas-loaded")

    // 3. Dragging a card moves it in the engine and the move is saved.
    await refocus()
    if let before = await card("Mira Vale") {
      let zoom = probe["zoom"] as? Double ?? 1
      let id = records.first { $0.title == "Mira Vale" }?.id ?? ""
      let dragged = await canvasSession?.testDrag(recordID: id, dx: -110, dy: 60) ?? false
      await snapshot("selftest-card-drag-end")
      await pause(700)
      let after = await card("Mira Vale")
      let dx = (after?.x ?? before.x) - before.x
      let dy = (after?.y ?? before.y) - before.y
      check(
        "dragging a card moves it (pointer events dispatched in the canvas)",
        dragged && abs(dx + 110 / zoom) < 6 && abs(dy - 60 / zoom) < 6,
        "Δ(\(Int(dx)), \(Int(dy))) expected (\(Int(-110 / zoom)), \(Int(60 / zoom)))")
      // Relationship arrows are bound to the card, so they follow it.
      let arrows = await canvasSession?.probe()["relations"] as? Int ?? 0
      check("relationship arrows stay attached after the move", arrows >= 3, "\(arrows) arrows")
      let stored = (storedBoard()?.scene?["elements"] as? [[String: Any]])?.first {
        ($0["customData"] as? [String: Any])?["recordID"] as? String
          == records.first { $0.title == "Mira Vale" }?.id
      }
      check(
        "the move is saved to the board",
        abs((stored?["x"] as? Double ?? .nan) - (after?.x ?? .infinity)) < 0.5)
    } else {
      check("dragging a card moves it", false, "the canvas did not report the card")
    }

    // 4. Double-clicking a card opens its record; closing returns to the same canvas.
    await refocus()
    if let target = await card("The art of remembrance") {
      await click(CGPoint(x: Metric.sidebar + 60, y: size.height - 200))
      mouse(.leftMouseDown, target.point, clicks: 1)
      await pause(50)
      mouse(.leftMouseUp, target.point, clicks: 1)
      await pause(90)
      mouse(.leftMouseDown, target.point, clicks: 2)
      await pause(50)
      mouse(.leftMouseUp, target.point, clicks: 2)
      await pause(900)
      check(
        "double-click opens the card's record",
        selectedRecord?.title == "The art of remembrance", selectedRecord?.title ?? "nothing open")
      await snapshot("selftest-open-record")
      closeRecord()
      await pause(900)
      let again = (await canvasSession?.probe()["cards"] as? [[String: Any]])?.count ?? 0
      check(
        "closing the record returns to the same canvas",
        selectedRecord == nil && destination == .canvas && again == 4)
      await snapshot("selftest-canvas-returned")
    }

    // 5. Canvas actions: show a record on the board, reference the selection, card artwork.
    if let oren = records.first(where: { $0.title == "Oren Ashe" }) {
      navigate(.library)
      await pause(500)
      showOnCanvas(oren)
      await pause(1600)
      let cards = await canvasSession?.probe()["cards"] as? [[String: Any]] ?? []
      check(
        "“Show on canvas” adds the record's card and selects it",
        destination == .canvas && cards.count == 5 && canvasSession?.selection == [oren.id],
        "\(cards.count) cards, selection \(canvasSession?.selection.count ?? 0)")
      pendingComposer = nil
      draft = ""
      referenceCanvasSelection()
      check(
        "the selected card can be referenced in the conversation",
        draft.contains("[Oren Ashe](synthesis://record/\(oren.id))") && companionExpanded, draft)
      draft = ""
      persistComposer()
      companionExpanded = false
      await pause(700)
      let before = cards.first { $0["recordID"] as? String == oren.id }?["height"] as? Double ?? 0
      if let art = Self.sampleArtwork() {
        canvasSession?.setArtwork(art.base64EncodedString(), for: oren.id)
        await pause(1500)
        let after = (await canvasSession?.probe()["cards"] as? [[String: Any]] ?? []).first {
          $0["recordID"] as? String == oren.id
        }
        check(
          "artwork attaches to the card and the text moves below it",
          after?["art"] as? Bool == true && (after?["height"] as? Double ?? 0) > before + 40
            && canvasSession?.selectionWithArt == [oren.id],
          "height \(Int(before)) → \(Int(after?["height"] as? Double ?? 0))")
        await snapshot("selftest-card-artwork")
        canvasSession?.setArtwork(nil, for: oren.id)
        await pause(1000)
        let cleared = (await canvasSession?.probe()["cards"] as? [[String: Any]] ?? []).first {
          $0["recordID"] as? String == oren.id
        }
        check(
          "removing the artwork restores the card",
          cleared?["art"] as? Bool == false
            && abs((cleared?["height"] as? Double ?? 0) - before) < 2)
      }
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
    await snapshot("selftest-companion-resized")
    companionExpanded = false
    await pause(500)

    await refocus()
    // 8. Graph: dragging a node repositions it without changing stored relationships.
    let relationCount = (try? store.relations(worldID: worldID).count) ?? -1
    navigate(.knowledge)
    await pause(900)
    await snapshot("selftest-graph-before")
    await drag(
      from: CGPoint(x: column + area.width / 2, y: Metric.bar + area.height / 2 + 14),
      by: CGSize(width: 0, height: 150))
    await snapshot("selftest-graph-after")
    check(
      "graph interaction leaves relationships untouched",
      (try? store.relations(worldID: worldID).count) == relationCount)

    // 9. Typing "@" in the composer offers lore; Return inserts a reference instead of sending.
    newChat()
    draft = ""
    await pause(900)
    await refocus()
    await click(CGPoint(x: column + area.width / 2, y: size.height - 96))
    for character in ["@", "o", "r", "e"] { await key(0, character) }
    await snapshot("selftest-mention-list")
    await key(36, "\r")
    let composed = pendingComposer?.text ?? draft
    check(
      "typing @ore and pressing Return inserts a reference to Oren Ashe",
      composed.contains("[Oren Ashe](synthesis://record/"), composed)
    check("the message was not sent by that Return", messages.isEmpty && !busy)
    await snapshot("selftest-mention-token")
    pendingComposer = nil
    draft = ""
    persistComposer()

    return log
  }
}
