# Synthesis

A native macOS worldbuilding studio built with SwiftUI, AppKit and SQLite. **Conversation, Canvas, Library, Graph, Timeline, Atlas and Review** are views of one saved world, sharing one design system.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
./scripts/build.sh release
open dist/Synthesis.app
```

Requires macOS 14+ and Swift 6 Command Line Tools. Scripts select the compatible installed SDK. This is a development build, ad-hoc signed; no releases or deployment.

## Workspaces

- **Conversation** is the assisted entry point. Pick a mode (Create, Develop, Critique, Simulate, Canonize) and type `@` to reference lore. Each answer shows which records were read. When the assistant proposes changes they arrive as a review card: accept or dismiss each new record, revision, relationship or event; accepted ones become drafts. Chats persist and can be renamed or archived. Without a configured provider the app says so and keeps your message.
- **AI Assisted / Manual** sits in every workspace bar and is independent of navigation. Manual persists, cancels active work and blocks provider requests in the native core. Every other tool keeps working.
- **Canvas** is arranged by hand. Add records, notes, entities or images; drag cards, marquee-select, group, arrange and connect them. Relationships between entities appear as connectors. A compact composer expands into a resizable docked companion that shares the conversation.
- **Graph** draws itself from entity relationships. Select an entity for its details, edit relationships, or copy a neighbourhood into an editable board.
- **Library** holds every document, entity and idea with full-text search, filters and an archive. The editor has rich text, a details inspector (tags, aliases, links, relationships, timeline) and canon review as a line diff.
- **Timeline** orders sourced events with free-form dates. **Atlas** pins records to a map image you supply.
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
| Canvas: V, H, C | Select, pan, connect |
| Canvas: ⌫, arrows, ⌘A, ⌘Z | Remove from board, nudge, select all, undo |

On Canvas, drag empty space to marquee-select; scroll to pan; pinch or ⌘-scroll to zoom toward the pointer. Drag a card's edge handle onto another card to connect them. Double-click a card to open its record.

## Development checks

```sh
./scripts/check.sh                                # strict lint, tests, optimized build
./scripts/verify-ui.sh docs/verification/latest   # captures every state; stays in the background
./scripts/selftest-ui.sh docs/verification/latest # posts real pointer and key events to the app
uv run --with pillow python scripts/contact-sheets.py docs/verification/latest --prune
```

The suite (41 tests) covers persistence, world isolation, canon approval, cancellation, reversible archive, audited relationships, retrieval, the proposal approval boundary, import and export, board layout and undo, mention tokens, Markdown parsing, canon diffing and graph layout. Visual checks use the real native window, never HTML previews. The self-test needs its window to be key for a few seconds and reports skipped checks if focus is taken. Current status is in [STATE](docs/STATE.md); the audit checklist and evidence are in [AUDIT](docs/verification/AUDIT.md).

Data: `~/Library/Application Support/Synthesis/synthesis.sqlite`, overridable with `SYNTHESIS_DATABASE_PATH`. Keys remain in macOS Keychain. See [AI setup](docs/AI_SETUP.md), [architecture](docs/ARCHITECTURE.md), [design direction](docs/UI_DIRECTION.md), [roadmap](docs/ROADMAP.md).

Typing in ⌘K also offers to capture the text as an idea. Worlds export as a folder of Markdown files or as complete JSON; Markdown and text files import as drafts.

Current limits: no live provider call has been made during development, so streaming and the model's use of the proposal format are untested against a real model; there is no autonomous multi-step tool use; large boards and graphs are unmeasured. Earlier UI studies under `docs/verification` are historical.
