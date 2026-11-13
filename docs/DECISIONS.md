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

## 2026-11-12 — latest owner direction (protected)

UI first: pause broader application feature development. Replace the light serif welcome composition with an infinite canvas, reference-matched modular navigation (power systems, universal history and related sections), customized guided chat, fluid interactions and no separate macOS title bar. The newly supplied three screenshots and Zeron composer are the current visual reference set. This supersedes the earlier light chat-home visual specification where they conflict; data ownership, explicit canon approval and privacy boundaries remain.

## 2026-11-12 — connected workspace refinement (owner-protected)

The owner accepted the graphite foundation and explicitly authorized integration into the real application. This supersedes the UI-study pause: independent persisted assistance mode, Conversation as assisted entry, compact canvas composer with resizable docked companion, actual source-backed records, curated Canvas separate from derived Graph, and shared Library/Timeline/Atlas. Empty boards remain empty. Templates and guided prompts are optional. No model call without deliberate submission; no implicit canon promotion.

## 2026-11-12 — product audit implementation choices

- **Titled window instead of borderless.** A borderless window had no close, minimise, zoom or full screen and was invisible to native automation. A titled window with full-size content and a transparent title bar keeps the integrated 56-point header the owner asked for while restoring standard behaviour. The traffic lights are re-centred by resizing the title-bar container; AppKit resets them on appearance changes, so `StudioWindow.update()` reapplies the layout. Alternative considered: an empty unified toolbar, rejected because toolbar hit-testing blocks controls drawn beneath it.
- **Archive, never delete.** Records, conversations, boards and events gain an `archived` flag (migration 0004). Archived rows keep IDs, history, canon snapshots and links, are excluded from lists, search, relationships and the graph, and remain in export. This satisfies the reversible-removal contract without a trash table.
- **Records open over the current workspace.** `openRecord` no longer changes the destination, so Back returns to Canvas, Graph or wherever the creator was.
- **One bar per workspace.** The global header merged into `WorkspaceBar` to remove a second 56-point row and the duplicated world name. World identity stays persistent in navigation; the assistance switch stays persistent in every bar.
- **Superseded UI removed.** The earlier studies (RootView, CanvasDesign and others) were deleted rather than kept compiling; git history is the archive. This reverses the earlier "retained source history" note in ARCHITECTURE.
- **Graph layout is derived.** Fruchterman–Reingold inside a frame shaped like the workspace, seeded deterministically from sorted record IDs. Positions are not stored; dragging a node is a temporary adjustment.
- **Verification without taking over the machine.** Captures render the window frame while the app stays behind other windows. Pointer checks post events to the app's own window; because SwiftUI gestures only respond in the key window of the active app, that runner comes forward briefly and reports skipped checks if focus is taken.

## 2026-11-12 — safe AI depth

- **Proposals ride in the answer text.** The provider adapter streams plain text, so a change set is one fenced JSON block at the end of the answer rather than provider-specific tool calls. This keeps the adapter boundary thin and lets any text model participate. The cost is that a model may ignore or malform the block; malformed blocks are dropped and the prose still shows.
- **Per-change review, drafts only.** Accepting a proposed change calls the same draft operations a creator uses, with origin `ai-proposed`. There is deliberately no "accept as canon"; canon keeps its own exact-revision review.
- **Confirmation by ID.** `resolveChange` requires the proposal's ID, as `promote` requires the record's, so the approval boundary is a property of the store API and is covered by a test.
- **Context is recorded, not just sent.** Every answer stores the records it was given and why, satisfying traceability and making the privacy disclosure concrete.
- **Mentions are tokens over Markdown.** The stored message keeps `[Title](synthesis://record/id)`; the composer shows a token. Old drafts and transcripts need no migration.
