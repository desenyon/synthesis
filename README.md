# Synthesis

A native macOS worldbuilding studio built with SwiftUI, AppKit and SQLite. **Conversation, Canvas, Library, Graph, Timeline and Atlas** are six views of one saved world, sharing one design system.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
./scripts/build.sh release
open dist/Synthesis.app
```

Requires macOS 14+ and Swift 6 Command Line Tools. Scripts select the compatible installed SDK. This is a development build, ad-hoc signed; no releases or deployment.

## Workspaces

- **Conversation** is the assisted entry point. Pick a mode (Create, Develop, Critique, Simulate, Canonize), reference lore with `@ Lore`, and save any answer as an AI-proposed draft. Chats persist and can be renamed or archived. Without a configured provider the app says so and keeps your message.
- **AI Assisted / Manual** sits in every workspace bar and is independent of navigation. Manual persists, cancels active work and blocks provider requests in the native core. Every other tool keeps working.
- **Canvas** is arranged by hand. Add records, notes, entities or images; drag cards, marquee-select, group, arrange and connect them. Relationships between entities appear as connectors. A compact composer expands into a resizable docked companion that shares the conversation.
- **Graph** draws itself from entity relationships. Select an entity for its details, edit relationships, or copy a neighbourhood into an editable board.
- **Library** holds every document, entity and idea with full-text search, filters and an archive. The editor has rich text, a details inspector (tags, aliases, links, relationships, timeline) and canon review as a line diff.
- **Timeline** orders sourced events with free-form dates. **Atlas** pins records to a map image you supply.

Nothing is hard-deleted: removing a record, conversation, board, event or relationship archives it and offers Undo. No AI output becomes canon without your explicit acceptance of an exact revision.

## Keys

| Shortcut | Action |
| - | - |
| ⌘K | Search and commands |
| ⌘1 – ⌘6 | Conversation, Canvas, Library, Graph, Timeline, Atlas |
| ⌘N / ⇧⌘N | New record / new conversation |
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

The suite (32 tests) covers persistence, world isolation, canon approval, cancellation, reversible archive, audited relationships, board layout and undo, Markdown parsing, canon diffing and graph layout. Visual checks use the real native window, never HTML previews. The self-test needs its window to be key for a few seconds and reports skipped checks if focus is taken. Current status is in [STATE](docs/STATE.md); the audit checklist and evidence are in [AUDIT](docs/verification/AUDIT.md).

Data: `~/Library/Application Support/Synthesis/synthesis.sqlite`, overridable with `SYNTHESIS_DATABASE_PATH`. Keys remain in macOS Keychain. See [AI setup](docs/AI_SETUP.md), [architecture](docs/ARCHITECTURE.md), [design direction](docs/UI_DIRECTION.md), [roadmap](docs/ROADMAP.md).

Current limits: no live provider call has been made during development; structured multi-record proposals and autonomous tool use are future work; large boards and graphs are unmeasured. Earlier UI studies under `docs/verification` are historical.
