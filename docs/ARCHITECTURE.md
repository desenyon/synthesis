# Architecture

## Application shell

`SynthesisApp` hosts `ConnectedRoot` (Shell.swift) in `StudioWindow`, a titled window with full-size content and a transparent title bar. The window keeps native controls, resizing, full screen and frame autosave; `layoutTrafficLights()` centres the buttons in the 56-point header and is reapplied from `update()`.

`ConnectedRoot` lays out the navigation (`Sidebar`), the active workspace and global overlays: the command palette, toasts and the error alert. Navigation, assistance mode and the open record are independent pieces of `Studio` state. A record opens over the current workspace (`selectedRecord`), so closing it returns to where the creator was.

## Design system

`Theme.swift` holds colour tokens for both themes, shared metrics and vocabulary (categories, modes, state labels). `Components.swift` holds the pieces every screen uses: `WorkspaceBar` (context, actions, the persistent `ModeSwitch`, search), `BarTitle`, `BarAction`, `QuietButton`, `IconButton`, `PlainMenu`, `FilterChip`, `SearchField`, `FormField`, `StateBadge`, `CategoryTile`, `EmptyState`, `SheetScaffold`, `ZoomControls` and the floating-panel surface. `WorkspaceBar` uses `ViewThatFits` to collapse labelled actions to icons when space is short.

## Workspaces

- `Conversation.swift`: `ConversationStudio` (full width or companion), `ChatRow`, `UnifiedComposer`. The composer owns keystrokes locally, measures its own height and debounces draft persistence. `Markdown.swift` parses answers into blocks with a pure, tested parser.
- `CuratedCanvas.swift` with `CanvasSession` (CanvasHost.swift): the board is the Excalidraw editor, built from `CanvasWeb/` into `CanvasBundle` and loaded in a `WKWebView` from the application bundle through the `synthesis-canvas://` scheme. A content security policy and the navigation delegate forbid every other origin; nothing is fetched from the network. A JSON bridge loads scenes, syncs record cards and relationship arrows, and receives changes, link activations and connection requests. Board rows store `{format:"excalidraw", scene, hiddenRelations, legacy?}`; earlier `CanvasDocument` layouts are converted on first open and kept. One session lives for the whole run so late edits still save; quitting waits for a flush. Canonical relationships cannot be relabelled from the canvas. Details: HANDOFF.md.
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

`ModelTransport` is the provider boundary. `ProviderRouter` sends each request to the provider selected at that moment: `ClaudeCodeTransport` or `CodexTransport` (HarnessTransport.swift), which run a local agent harness the creator has signed in to with a subscription, or `OpenAITransport` (Responses API, SSE, `store:false`, key in Keychain). A harness is the default when one is installed. Each harness call is a fresh process in an empty scratch folder with the prompt on standard input; Claude Code runs with no tools, MCP servers, slash commands or user settings, Codex in a read-only sandbox without user config, rules, apps or plugins. Inherited API-key variables are stripped. Cancelling the task terminates the process. Synthesis holds no harness credentials. Sending explicitly discloses who receives the message; there is no background generation. Manual mode is persisted and checked inside AgentEngine before transport invocation. Cancellation invalidates a generation ID and prevents late answers from being saved. UI request tokens prevent stale completions from replacing a newer request.

Context comes from `WorkspaceStore.contextRecords` (Retrieval.swift): records referenced in the message, full-text matches for its terms, relationship and link neighbours of those, then recent work, capped at 16 and never crossing worlds or including archived records. Each entry carries the reason it was chosen. The list sent is saved in `message_context` with the answer and shown in the transcript. It is single-shot retrieval, not an autonomous tool loop.

A model answer may end with one fenced `synthesis-proposal` JSON block. `ProposalParser` removes it from the transcript; `stageProposal` validates every change against the selected world (unknown IDs, cross-world IDs and unknown actions are dropped) and stores it pending in `proposals`. `resolveChange` applies or dismisses one change and requires the proposal's own ID as confirmation, mirroring `promote`; `AgentEngine` has no path to it. Accepted changes call the ordinary draft operations with origin `ai-proposed`, inside a transaction (the database supports nested transactions through savepoints). Nothing in this path sets canon. No live provider call has been made during implementation.

## Data notes

Page references use the world-scoped `links` table; incoming references are queried independently of semantic relationships. Tags and aliases participate in FTS and versioned snapshots. Canvas and atlas serialize typed Codable documents into world-scoped boards; images are bounded base64 inside the local board. World covers are scoped preferences. Exports (schema version 3) include records, conversations, revisions, relationships and their history, events, boards, links and everything archived.
