# Decisions

## 2026-11-12 — owner-protected product decisions

- Product name: Synthesis. A native macOS application; user allows GPUI or another native implementation.
- Complete replacement of the rejected black three-pane design. Light default, collapsible navigation, central conversational workspace, no fixed AI sidebar, no automatically opened document. Manual mode must remain independently useful and stop model calls.
- AI output never becomes canon without explicit scoped creator approval. Lore, history and privacy safeguards remain protected.
- No releases, public deployments or unnecessary paid calls. Commit useful increments and maintain documentation alongside implementation.

## Implementation choices

- SwiftUI/AppKit selected over GPUI: the current Mac has a working Swift toolchain; Rust/GPUI and full Xcode were not established. This is genuinely native, not an embedded website. GPUI has not been implemented.
- Native system sans-serif and serif typography with SF Symbols keep controls coherent with macOS. Monospace is confined to the ASCII artwork and technical text.
- SQLite C API avoids third-party runtime dependencies. Preserve the original relational migration; add native tables. Old web scaffold and HTML design studies remain historical, not runnable product claims.
- NSTextView supplies rich text, selection, undo and native keyboard editing; RTF plus plain-text serialization preserves portability. A dedicated block editor is deferred.
- Provider credentials belong in Keychain for this local desktop architecture, replacing the obsolete web server-only implementation detail. Private lore still leaves the machine only on explicit provider submission.
- The canonical snapshot remains independent from the mutable draft. Exact-version review is mandatory; the model has no approval tools.
- Actual native window captures replace browser screenshots because the shipping target is macOS. A 390-point capture checks compact layout; it is not an iOS or browser build.

Earlier Next.js/Drizzle and Markdown-only design choices were superseded by the owner's native complete-rebuild directive. They do not describe the current app.
