# Expansion #16 — multiple open documents

Per-world tabs support selection, pin/unpin, closing, closing other unpinned tabs and recent reopening. Native File/View commands provide Command-W, Shift-Command-T and Control-Tab / Control-Shift-Tab. Editor and Library share the document-history menu; quick-open includes reopening. Long tab titles truncate; the strip scrolls the active tab into view.

Tab addresses/pins/recent IDs persist locally per world. They resolve current records and filter archived/foreign sources. Failed saves block leaving/closing the active document. The actual native text view is retained for open tabs, including caret, viewport, rich text and its own UndoManager. Fresh external content clears obsolete undo history. Closing a tab never archives lore. See [DOCUMENTS](../../DOCUMENTS.md). Full session restoration remains #33.

`./scripts/check.sh`: strict lint, **204 tests / 52 suites**, optimized ad-hoc build. Four new tests exercise disk restart, pins, close/reopen order, world isolation, failed saves, archive pruning, malformed preferences, native scroll/caret/format retention, independent undo, and stale-content reset. An earlier test build was invalidated by editing a capture fixture during compilation; the final complete check ran against unchanged source and passed.

Captured `document-tabs,light-document-tabs,manual-document-tabs,document-tabs-many,document-tabs-reopened,document-tabs-sections,library,editor-recovered` at 1440×900 and 1024×768. **All 16 captures** inspected in six contact-sheet rows, plus full-size normal/long-tab checks. README preserves the normal 1440px tab strip. Long-record captures are authored isolated fixtures; no user data or subscription usage.

Native state tests exercise editing programmatically in the background. Foreground keyboard/menu actions, pointer feel and VoiceOver were not reverified. No release or restart of the owner's app.
