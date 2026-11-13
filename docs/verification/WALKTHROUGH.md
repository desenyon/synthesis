# Native verification — 2026-11-12

The actual macOS application was operated through its accessibility controls and native keyboard input. No browser test was run; this is a SwiftUI/AppKit app.

## Observed interactive journey

1. Created **Verification world** through the world menu.
2. Typed a fictional whale-city prompt into the composer and pressed Return. User message persisted; no-provider state appeared. No AI response was fabricated and no provider call was made.
3. Switched to Manual, captured **Whale city**, typed two paragraphs into NSTextView and saved with ⌘S. Invoked native bold formatting. Converted the capture into a document through its menu.
4. ⌘K full-text search for `bells` returned the saved page; opening it showed the original text.
5. Changed appearance and collapsed navigation. Returned to AI, renamed the chat **Whale-city exploration**, used ⌘N, then found/reopened the previous conversation.
6. Quit and relaunched. Selected world, Manual mode, dark theme, collapsed navigation and saved page remained.
7. Added a canvas note, edited it, used undo and redo, navigated away and reopened. The exact note text persisted.
8. Created **The Dreaming Whale** entity. Linked **Whale city** to it in the record inspector, saved tags and alias `Bellhaven`, searched that alias, and followed the page's linked entity.
9. Created **The first bell**, date label **Age of drifting**, sourced to **Whale city**. The event appeared; its source action opened the page.
10. Opened exact-version canon review and inspected its current/proposed text and explicit approval button. Cancelled; no user canon was approved by the coding agent.
11. Explicitly opened the labeled **Aster** sample. Knowledge graph read its stored entities and relation; selecting Mira and opening the record showed the actual entity.
12. Uploaded a generated, explicitly labeled atlas verification PNG into the sample world. Placed a marker linked to The Glass Sea; its action opened the actual source page.

Canvas dragging/resizing/grouping/connectors, atlas pan/zoom, formatting fidelity and source backlinks require further detailed interaction coverage. They are implemented but the steps above are the observed coverage, not an exhaustive certification. Active-request Manual cancellation is covered by automated injected-transport tests, not by a live paid model request.

## Visual evidence

`round1` is diagnostic. Its 1920 filenames did not all match actual dimensions because NSWindow constrained them to the physical screen. Do not use those as exact-size evidence.

`round2` captures six native states at each requested logical size. A diagnostic script asserted their Retina dimensions (2× logical size); all 24 were visually inspected via contact sheets, with selected home/manual/editor states also inspected at larger scale. Compact horizontal overflow and duplicate native menu indicators were corrected between rounds. The screenshot harness now rejects viewport mismatches and permits offscreen native window sizing only in capture mode.

The capture fixture's active chat contains a real persisted user message and explicit missing-provider system message. It does not simulate a successful AI answer. A compact 390-point native layout is not an iOS application.
