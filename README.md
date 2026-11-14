# Synthesis

A native macOS worldbuilding studio built with SwiftUI, AppKit and SQLite. The graphite shell now connects **Conversation, Canvas, Library, Graph, Timeline and Atlas** to the same saved world.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
./scripts/build.sh release
open dist/Synthesis.app
```

Requires macOS 14+ and Swift 6 Command Line Tools. Scripts select the compatible installed SDK. This is a development build, ad-hoc signed; no releases or deployment.

## Connected workflow

- **Conversation** is the assisted entry point. Chats persist, can be renamed/reopened, cite local lore, stream with a configured provider, and show honest connection/error states otherwise.
- **AI Assisted / Manual** is independent of navigation. Manual persists, cancels active work and blocks provider requests in the native core. Editing and spatial tools remain available.
- **Canvas** is manually curated. Add actual library records, notes, entities or images. Positions, viewport, groups and connections save locally. A compact composer expands into a resizable docked companion sharing the same conversation.
- **Graph** derives from entity relationships. Copy a selected neighborhood into an independent editable canvas.
- **Library** includes rich editing, source links, search, tags, aliases, history and explicit canon review. Timeline and Atlas open real source records.

New boards are empty. Templates and guided prompts are optional. Canvas removal keeps the source record; entity relationship removal is archived and restorable. No AI output becomes canon automatically.

## Controls

⌘K opens global navigation/search; ⌘N creates a draft. Use the canvas toolbar for creation, selection, pan, connections and undo/redo. ⌘-click selects multiple cards; the selection menu groups or aligns them. Double-click or use the arrow to open a card's source. Drag empty space or scroll to pan, pinch/⌘-scroll to zoom, and use Fit for framing. Right-click exposes local actions. World artwork is optional in Settings; card artwork is available in its context menu.

## Background verification

```sh
./scripts/verify-background.sh
```

Runs strict lint, tests, an optimized build and native screenshots without activating an app or showing a window. Uses a temporary app bundle, fresh database, separate preferences and a disabled model transport. It never replaces or restarts the app you are using. Captures and logs go to `test-results/background/`. Builds default to two workers at reduced CPU priority; override with `SYNTHESIS_BUILD_JOBS=4` if desired. This is a one-shot command, not a background watcher.

For a detached terminal run: `./scripts/verify-background.sh > /tmp/synthesis-verification.log 2>&1 &`.

## Graph engine

Knowledge Graph uses [SwiftFlow](https://github.com/aaurelions/SwiftFlow) for native nodes, routed labeled edges, connection handles, selection, pan/zoom and fitting. Its layout utilities also power explicit canvas auto-arrange and graph-to-canvas transfer. Synthesis owns records and approvals: drawing a connection opens a labeled draft form, and graph delete shortcuts cannot delete lore. Canvas remains a separately persisted creative board; its existing card gestures are not migrated to SwiftFlow in this change.

The MIT source is pinned under `Vendor/SwiftFlow`, including upstream tests and a small app-bundle resource lookup patch. See [provenance](Vendor/SwiftFlow/UPSTREAM.md) and [notices](THIRD_PARTY_NOTICES.md).

## Development checks

```sh
./scripts/test.sh
swift format lint --strict --recursive Sources Tests Package.swift
./scripts/build.sh release
./scripts/verify-ui.sh docs/verification/latest
```

The suite covers persistence, world isolation, canon approval, cancellation, audited relationships, board layout/undo and companion save protection. Visual checks use actual native windows, never HTML previews. Current verification is recorded in [STATE](docs/STATE.md) and the [background graph review](docs/verification/BACKGROUND_GRAPH_REVIEW.md): 23 app tests, 291 upstream engine tests, two startup-isolation checks and 27 inspected hidden native captures. Direct drag/resize gesture acceptance remains pending; foreground automation is intentionally excluded while you work.

Data: `~/Library/Application Support/Synthesis/synthesis.sqlite`, overridable with `SYNTHESIS_DATABASE_PATH`. Keys remain in macOS Keychain. See [AI setup](docs/AI_SETUP.md), [architecture](docs/ARCHITECTURE.md), [design direction](docs/UI_DIRECTION.md), [roadmap](docs/ROADMAP.md).

Current limits: model output supports text streaming, inline lore links, Markdown/code and tables; autonomous multi-step tool execution and structured multi-record proposals remain future work. The provider boundary is tested offline; no paid live-provider test is claimed. Older UI studies and captures remain historical and are not the current application.
