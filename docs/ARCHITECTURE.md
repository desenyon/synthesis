# Architecture

## Application shell

`SynthesisApp` hosts `ConnectedRoot` (Shell.swift) in `StudioWindow`, a titled window with full-size content and a transparent title bar. The window keeps native controls, resizing, full screen and frame autosave; `layoutTrafficLights()` centres the buttons in the 56-point header and is reapplied from `update()`.

`ConnectedRoot` lays out the navigation (`Sidebar`), the active workspace and global overlays: the command palette, toasts and the error alert. Navigation, assistance mode and the open record are independent pieces of `Studio` state. A record opens over the current workspace (`selectedRecord`), so closing it returns to where the creator was.

## Design system

`Theme.swift` holds colour tokens for both themes, shared metrics and vocabulary (categories, modes, state labels). `Components.swift` holds the pieces every screen uses: `WorkspaceBar` (context, actions, the persistent `ModeSwitch`, search), `BarTitle`, `BarAction`, `QuietButton`, `IconButton`, `PlainMenu`, `FilterChip`, `SearchField`, `FormField`, `StateBadge`, `CategoryTile`, `EmptyState`, `SheetScaffold`, `ZoomControls` and the floating-panel surface. `WorkspaceBar` uses `ViewThatFits` to collapse labelled actions to icons when space is short.

## Workspaces

- `Conversation.swift`: `ConversationStudio` (full width or companion), `ChatRow`, `UnifiedComposer`. The composer owns keystrokes locally, measures its own height and debounces draft persistence. `Markdown.swift` parses answers into blocks with a pure, tested parser.
- `CuratedCanvas.swift` with `BoardController`: cards reference records; positions, groups, board-only links and viewport serialize to the boards table. Card sizes are measured and feed connector routing (`EdgeGeometry`). `CanvasInputSurface` (TextEditing.swift) supplies pan, pointer-anchored zoom, marquee and keys. Save guards prevent leaving on failure; undo is bounded to 60 steps. Canonical relationships cannot be edited directly.
- `Graph.swift`: `GraphLayout` is a deterministic Fruchterman–Reingold layout inside a frame shaped like the window. Nothing is stored. Copying to canvas creates a separate board referencing the same records.
- `Library.swift`, `Editor.swift`: list with full-text search and archive; editor with `RecordInspector` and `TextDiff`-based canon review. `Timeline.swift`, `Atlas.swift`: sourced events and map markers.
- `CommandPalette.swift`, `Sheets.swift`: ⌘K and the settings, new-record, new-world and rename sheets.
- `CaptureFixtures.swift`, `SelfTest.swift`: authored fixtures and the interaction self-test. Both refuse to run outside the isolated runner (`SYNTHESIS_CAPTURE_DIR`).

## Removal

Migration 0004 adds `archived` to records, conversations, boards and events. Archived rows keep their IDs, revisions, canon snapshots and links; they are excluded from lists, full-text search, relationships and linked-record queries, and included in export. `Studio.archive` shows an Undo toast. Relationships keep their earlier audited archive and restore.

## Runtime

Swift package, macOS 14+, SwiftUI presentation with AppKit window/menu integration and NSTextView rich editing. No WebView, Next.js runtime, Rust dependency or hosted service. The installed command-line Swift toolchain builds against macOS 26.5 SDK; scripts avoid the default 27 SDK's unavailable SwiftUI macro plugin. Development bundle is ad-hoc signed.

- `SynthesisCore`: SQLite C driver, migrations, domain operations, full-text retrieval, agent cancellation, provider transport and Keychain credentials.
- `SynthesisUI`: observable Studio state, design system, shell and the six workspaces.
- `SynthesisApp`: NSApplication lifecycle, native menu shortcuts, window and screenshot harness.
- `Tests/SynthesisCoreTests`: disk persistence, world isolation, canon/revision boundary, reversible archive and injected transport tests.
- `Tests/SynthesisUITests`: Studio navigation and archive, board controller, Markdown, diff, connector and graph layout.

SQLite lives at `~/Library/Application Support/Synthesis/synthesis.sqlite`; `SYNTHESIS_DATABASE_PATH` overrides it for isolated tests. Foreign keys, WAL and migrations are enabled. Original v1 tables remain; additive v2 tables hold conversations/messages, rich documents, preferences, native revision snapshots and boards. The superseded TypeScript domain scaffold is preserved under `legacy/web`; it is not the application.

Records carry world ID, kind, title, plain text, category, state, origin and version. RTF is stored separately so plain text remains recoverable. Accepted canon is a snapshot independent from working content. Saves use version checks; navigation and quit flush editor changes, and failures keep the active draft open. History records exact versions. Failed-save recovery across a process crash is not yet implemented.

All domain operations validate local world ownership and membership. FTS5 is world-scoped. Entity relationships and chronology reference actual records. Boards store versionable JSON. Exports include records, conversations, revisions, relations, events and boards. PostgreSQL would require a new driver and search implementation; this is not a drop-in migration.

## AI boundary

OpenAI Responses API adapter supports SSE text streaming, cancellation and explicit error states. API keys are kept in macOS Keychain; only model ID is a preference. Sending explicitly discloses that message and selected-world context leave the device. Requests use `store:false`; there is no background generation. Manual mode is persisted and checked inside AgentEngine before transport invocation. Cancellation invalidates a generation ID and prevents late answers from being saved. UI request tokens prevent stale completions from replacing a newer request.

Context is currently bounded recent lore (up to 24 records), labeled with draft/canon status and stable source URLs, plus conversation history. It is not a multi-step autonomous retrieval agent. Provider output can be saved as an AI-origin draft; canon approval is exclusively a separate user review. No live provider call has been made during implementation.

## Data notes

Page references use the world-scoped `links` table; incoming references are queried independently of semantic relationships. Tags and aliases participate in FTS and versioned snapshots. Canvas and atlas serialize typed Codable documents into world-scoped boards; images are bounded base64 inside the local board. World covers are scoped preferences. Exports (schema version 3) include records, conversations, revisions, relationships and their history, events, boards, links and everything archived.
