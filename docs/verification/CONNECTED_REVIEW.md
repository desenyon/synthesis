# Connected native workspace review

Date: 2026-11-12. Actual SwiftUI/AppKit application, not a web or HTML preview.

## Captures inspected

Final files live in `connected-final/`: nine states at each of 1440×900, 1920×1080 and 1024×768, 27 PNGs total. Capture log verifies logical and bitmap dimensions (1× on this display). Contact sheets cover Conversation home, persisted conversation with inline lore and table, real entity canvas with collapsed composer, expanded companion, Manual canvas, collapsed navigation, light theme, derived graph and library. Default graphite theme appears in the other states.

- [1440×900 contact sheet](connected-final/contact-1440x900.jpg)
- [1920×1080 contact sheet](connected-final/contact-1920x1080.jpg)
- [1024×768 contact sheet](connected-final/contact-1024x768.jpg)
- [Canvas](connected-final/canvas-1440x900.png)
- [Companion](connected-final/companion-1440x900.png)
- [Conversation](connected-final/conversation-1440x900.png)

The isolated capture database contains actual saved Aster sample entities, relations, boards and messages. The assistant-shaped example is visibly marked “Imported example / Authored sample · not a model response.” No provider was called. Capture setup is environment-gated and does not replace the normal user's database. Original procedural coast artwork is bundled as optional sample artwork.

Corrections from inspected iterations: clipped world image now bounded; lower cards no longer touch the compact composer; companion docks beside the canvas; at narrow width navigation automatically uses its rail and companion uses 320px; initial fixture viewport fits at each capture size while normal saved viewports remain preserved; graph edges now react to loaded data; graph labels offset away from a shared midpoint; conversation scrolling clips before the composer.

## Observed live flow

1. Reopened the sample Aster world with Manual and its saved canvas restored.
2. Switched AI on, opened Conversation and sent a user message without configured provider. Message persisted; local connection error appeared, with no invented answer.
3. Added library records to a board; actual `guided by` relation appeared. Expanded companion showed the same persisted thread. Manual removed companion and composer while keeping the board.
4. In Graph, selected Mira Vale and copied its neighborhood. Canvas opened a saved “Graph selection” board with Mira and Tidekeepers and the same relation. Relationship inspection opened its real draft record.
5. Used ⌘N to create “Verification draft · connected workspace” in Manual, typed a body, navigated away, searched its body through ⌘K and reopened the exact text. Assistance changes preserved the editor.
6. Switched theme and collapsed navigation, quit/restarted. Manual, light theme, compact navigation, selected board and draft body persisted.
7. Inserted Mira using @ Lore, sent the reference locally, clicked the rendered link and opened the actual entity. Returned to Canvas and opened companion; both saved messages and honest provider-unavailable notices remained.

A clearly named verification draft and graph-copy board remain in the sample world. No user lore or canon was overwritten or promoted.

## Checks and limits

`./scripts/check.sh` passed strict format lint, 20 tests and optimized build. Final visual build and final test run also passed; final `git diff --check` passed. Tests include actual SQLite reopen/isolation/canon boundaries, core Manual request blocking and cancellation with an offline transport, reversible audited relationship edits, delayed board-save protection, pending composer flush, board layout/undo and malformed-board preservation.

Native CUA drag returned `noWindowsAvailable`; direct node drag and companion-resize acceptance is pending. Model tests cover layout/undo but do not prove gesture behavior. No paid provider, browser test, frame-rate benchmark, release, push or notarization was performed. Automated active-request cancellation was tested; a live model stream was not interrupted through the UI. Timeline/Atlas remain connected but were not fully re-walked in this iteration. Whole milestone acceptance remains open for those gesture/performance checks.
