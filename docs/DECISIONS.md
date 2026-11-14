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

## 2026-11-13 — non-disruptive testing and open-source graph engine

Owner requirement: verification must not switch away from their current work. Default unattended checks render to a never-ordered native window under prohibited activation, using isolated bundle/DB/preferences and no desktop input. Foreground gesture testing is a separate explicit activity, not a default verification step.

Use MIT SwiftFlow as the native graph interaction engine, pinned at 3515701fad73d3c6f8722bd65c22ef0813dc11a0. Compared with Grape (force visualization) and Dagre (layout), it also supplies handles, connection callbacks, selection and viewport behavior. Keep Synthesis's visual components, shared storage and canon approval boundary above the engine. The dependency is vendored for an auditable resource-path patch required by our command-line .app packaging. No upstream algorithm changes. Updates must re-run upstream tests and background capture checks.
