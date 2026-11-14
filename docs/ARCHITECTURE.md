# Architecture

## Connected entry point

`SynthesisApp` hosts `ConnectedRoot`, using the existing `Studio` observable state and `WorkspaceStore`. Navigation and assistance mode are independent. `ConversationStudio` is used full-width or as a resizable docked companion; both use the same persistent conversation. `UnifiedComposer` owns keystrokes locally and debounces draft persistence. The native window remains borderless with an integrated draggable header.

`CuratedCanvas` owns a world-scoped `BoardController`: source record references, card artwork, manually arranged positions, groups, local board edges and viewport serialize to the existing boards table. Old board documents decode with optional new fields. Save guards prevent leaving on failure; explicit flush cancels delayed saves. Undo/redo applies to board changes without deleting lore. Semantic edges read the relationships table; v3 adds audit history and reversible archival. Canonical relationships are blocked from direct edits.

`RelationshipGraph` uses vendored SwiftFlow at revision 3515701fad73d3c6f8722bd65c22ef0813dc11a0. `GraphEngine` projects world-scoped entities and valid relationship endpoints to engine nodes/edges, computes layout off the main actor and supplies neighborhoods. SwiftFlow owns paths, handles, selection and viewport interaction. Engine removal is disabled; connection gestures open a Synthesis draft form before any write. Relationship state is now exposed in the read model so canonical relationships do not offer edit/archive controls. SQLite validation remains authoritative. Graph node positions are derived, not saved edits. Canvas auto-arrange explicitly uses the same layout utility; existing canvas gestures remain native Synthesis code.

`RelationshipGraph` derives its visualization from actual entities/relationships. Copying a graph neighborhood creates a separate board referencing the same records. Moving those cards never modifies the graph. Empty boards do not seed template nodes.

The earlier `CanvasDesignRoot`/`CanvasDesignModel` are retained source history, never the primary route or capture target. Their transient study behavior is superseded. The ASCII landscape is not rendered behind the connected canvas. World covers and card images are optional, bounded local data; no external image request is implicit.

## Runtime

Swift package, macOS 14+, SwiftUI presentation with AppKit window/menu integration and NSTextView rich editing. No WebView, Next.js runtime, Rust dependency or hosted service. The installed command-line Swift toolchain builds against macOS 26.5 SDK; scripts avoid the default 27 SDK's unavailable SwiftUI macro plugin. Development bundle is ad-hoc signed.

- `SynthesisCore`: SQLite C driver, migrations, domain operations, full-text retrieval, agent cancellation, provider transport and Keychain credentials.
- `SynthesisUI`: observable Studio state, theme tokens, native navigation, chat, manual library/editor, settings and connected workspaces.
- `SynthesisApp`: NSApplication lifecycle, native menu shortcuts, window and screenshot harness.
- `Tests/SynthesisCoreTests`: disk persistence, world isolation, canon/revision boundary and injected transport tests.

SQLite lives at `~/Library/Application Support/Synthesis/synthesis.sqlite`; `SYNTHESIS_DATABASE_PATH` overrides it for isolated tests. Foreign keys, WAL and migrations are enabled. Original v1 tables remain; additive v2 tables hold conversations/messages, rich documents, preferences, native revision snapshots and boards. The superseded TypeScript domain scaffold is preserved under `legacy/web`; it is not the application.

Records carry world ID, kind, title, plain text, category, state, origin and version. RTF is stored separately so plain text remains recoverable. Accepted canon is a snapshot independent from working content. Saves use version checks; navigation and quit flush editor changes, and failures keep the active draft open. History records exact versions. Failed-save recovery across a process crash is not yet implemented.

All domain operations validate local world ownership and membership. FTS5 is world-scoped. Entity relationships and chronology reference actual records. Boards store versionable JSON. Exports include records, conversations, revisions, relations, events and boards. PostgreSQL would require a new driver and search implementation; this is not a drop-in migration.

## AI boundary

OpenAI Responses API adapter supports SSE text streaming, cancellation and explicit error states. API keys are kept in macOS Keychain; only model ID is a preference. Sending explicitly discloses that message and selected-world context leave the device. Requests use `store:false`; there is no background generation. Manual mode is persisted and checked inside AgentEngine before transport invocation. Cancellation invalidates a generation ID and prevents late answers from being saved. UI request tokens prevent stale completions from replacing a newer request.

Context is currently bounded recent lore (up to 24 records), labeled with draft/canon status and stable source URLs, plus conversation history. It is not a multi-step autonomous retrieval agent. Provider output can be saved as an AI-origin draft; canon approval is exclusively a separate user review. No live provider call has been made during implementation.

## Connected workspaces

Page references use the existing world-scoped `links` table; incoming references are queried independently of semantic entity relationships. Tags/aliases participate in FTS and versioned snapshots. Graph and timeline query stored entities, relationships and sourced events. Canvas and atlas serialize typed Codable document shapes into world-scoped boards; images are stored as bounded base64 data inside the local board. Canvas undo/redo is bounded to 60 session snapshots. Board save failures keep the workspace open rather than navigating away. Canvas viewport and positions persist; Graph layout is derived and temporary. Relationship archive/history is included in JSON export. World-cover images are scoped preferences; canvas images are included in board export.

## Unattended verification

`scripts/verify-background.sh` runs bounded low-priority checks and hidden native captures. `verify-ui.sh` builds a separate temporary verification bundle and fresh DB; normal `dist/Synthesis.app` stays untouched. Capture startup sets prohibited activation before the app event loop, never orders the window, skips menus/alerts, avoids normal model preferences and Keychain checks, and injects a transport that rejects model calls. Every capture asserts no visible/key window or active application; an activation notification observer detects transient activation. Screenshots use the actual NSHostingView, not a screen recording or user input.

SwiftFlow localization bundles are copied into Contents/Resources. A documented vendored lookup patch searches that signed-bundle location before SwiftPM's normal test/development fallback. MIT notices ship with the app.
