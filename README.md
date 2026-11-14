# Synthesis

A native macOS worldbuilding studio built with SwiftUI, AppKit and SQLite. **Conversation, Canvas, Library, Graph, Timeline, Atlas and Review** are views of one saved world, sharing one design system.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
./scripts/build.sh release
open dist/Synthesis.app
```

Requires macOS 14+ and Swift 6 Command Line Tools. The canvas bundle is committed; Node is only needed to change it (`cd CanvasWeb && npm install && npm run build`). Third-party notices: [THIRD_PARTY.md](THIRD_PARTY.md). Scripts select the compatible installed SDK. This is a development build, ad-hoc signed; no releases or deployment.

## Workspaces

- **Conversation** is the assisted entry point. Pick a mode (Create, Develop, Critique, Simulate, Canonize) and type `@` to reference lore. Each answer shows which records were read. When the assistant proposes changes they arrive as a review card: accept or dismiss each new record, revision, relationship or event; accepted ones become drafts. Chats persist and can be renamed or archived. Without a configured provider the app says so and keeps your message.
- **AI Assisted / Manual** sits in every workspace bar and is independent of navigation. Manual persists, cancels active work and blocks provider requests in the native core. Every other tool keeps working.
- **Canvas** runs on the [Excalidraw](https://github.com/excalidraw/excalidraw) engine: draw freely, add shapes, text, images and frames, and place record cards that stay linked to your library. Relationships between entities appear as labelled arrows, and an arrow you draw between two entity cards can become a relationship. It works offline; nothing is loaded from the network. Synthesis supplies the visible graphite cards, colored connection ports, image previews and compact toolbars; Excalidraw supplies gestures and history. A compact composer expands into a resizable docked companion that shares the conversation.
- **Graph** draws itself from entity relationships. Select an entity for its details, edit relationships, or copy a neighbourhood into an editable board.
- **Library** holds every document, entity and idea with full-text search, filters and an archive. The editor has rich text, a details inspector (tags, aliases, links, relationships, timeline) and canon review as a line diff.
- **Timeline** orders sourced events with free-form dates. **Atlas** pins records to a map image you supply or explicitly choose from the bundled GPT illustration library. Replacing a map offers Undo.
- **Review** gathers what is waiting on you: AI proposals from every conversation, drafts that have moved past accepted canon, and a local consistency check (clashing names, unlinked mentions, unconnected entities) that needs no model.

Nothing is hard-deleted: removing a record, conversation, board, event or relationship archives it and offers Undo. No AI output becomes canon without your explicit acceptance of an exact revision.

## Keys

| Shortcut | Action |
| - | - |
| ⌘K | Search and commands |
| ⌘1 – ⌘7 | Conversation, Canvas, Library, Graph, Timeline, Atlas, Review |
| ⌘N / ⇧⌘N | New record / new conversation |
| ⇧⌘I | Import Markdown or text files |
| @ in a message | Reference lore; ↑↓ choose, ↵ insert |
| ⌘\ | Toggle navigation |
| ⇧⌘M | Toggle AI Assisted / Manual |
| ⌘[ | Back from a record |
| Canvas | Excalidraw's shortcuts: 1–0 tools, V select, H hand, A arrow, ⌫ delete, ⌘Z undo, ⌘D duplicate, ⌘G group |

On Canvas, double-click a card to open its record. Draw an arrow from one entity card to another to propose a relationship. Select cards and choose Reference to mention them in the conversation; Add ▸ Artwork puts a picture on the selected card. "Show on canvas" in a record's menu finds or places its card.

## Development checks

```sh
./scripts/check.sh                                # strict lint, tests, optimized build
./scripts/verify-ui.sh docs/verification/latest   # captures every state; stays in the background
./scripts/selftest-ui.sh docs/verification/latest # posts real pointer and key events to the app
uv run --with pillow python scripts/contact-sheets.py docs/verification/latest --prune
```

The native suite (51 tests; includes preserved, uncommitted rules work) covers persistence, world isolation, canon approval, cancellation, reversible archive, audited relationships, retrieval, the proposal approval boundary, import and export, board layout and undo, mention tokens, Markdown parsing, canon diffing and graph layout. Six additional Node tests cover canvas geometry, relationship state, nested groups and session isolation (`cd CanvasWeb && npm test`). Visual checks use the real native window and bundled WebKit engine, never HTML previews. The background runner builds a temporary app, requires a fresh isolated database and refuses model requests. It does not overwrite the running bundle. Background sheets render their real content inline to avoid modal activation; native modal interaction requires the explicit foreground test. The self-test needs its window to be key for a few seconds and reports skipped checks if focus is taken. Current status is in [STATE](docs/STATE.md); the current audit and evidence are in [REFINEMENT_AUDIT](docs/verification/REFINEMENT_AUDIT.md). The full strict lint currently reports eight pre-existing formatting errors in unfinished core rules work; scoped UI/app lint, tests and release build pass independently.

The assistant uses Claude Code or Codex with your subscription by default (no API key), or an OpenAI key if you prefer; see [AI setup](docs/AI_SETUP.md).

Data: `~/Library/Application Support/Synthesis/synthesis.sqlite`, overridable with `SYNTHESIS_DATABASE_PATH`. Keys remain in macOS Keychain. See [AI setup](docs/AI_SETUP.md), [architecture](docs/ARCHITECTURE.md), [design direction](docs/UI_DIRECTION.md), [roadmap](docs/ROADMAP.md).

Typing in ⌘K also offers to capture the text as an idea. Worlds export as a folder of Markdown files or as complete JSON; Markdown and text files import as drafts.

Current limits: Claude’s earlier handoff records one live request per subscription harness; this audit makes no model-provider calls. Live streaming/Stop UI, large boards/graphs, trackpad and VoiceOver remain unverified. PNG export uses engine-rendered cards and does not yet reproduce the DOM card material exactly. Bundled GPT artwork is optional; on-demand image generation is not implemented. Earlier evidence under `docs/verification` is historical.

To build a separate review bundle without replacing a running app: `./scripts/build.sh release dist/Synthesis-review.app`. The active continuation checkout is `/Users/desenyon/.zeron/worktrees/synthesis/swift-falcon`; do not use the superseded main-checkout build.
