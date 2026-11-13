# Architecture

## Actual runtime

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

Page references use the existing world-scoped `links` table; incoming references are queried independently of semantic entity relationships. Tags/aliases participate in FTS and versioned snapshots. Graph and timeline query stored entities, relationships and sourced events. Canvas and atlas serialize typed Codable document shapes into world-scoped boards; images are stored as bounded base64 data inside the local board. Canvas undo/redo is bounded to 60 session snapshots. Board save failures keep the workspace open rather than navigating away. Graph positions and spatial viewport transforms are currently session UI state.
