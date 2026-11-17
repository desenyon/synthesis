# Changelog

All notable changes to Synthesis are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). 0.0.x versions are early releases: usable, tested on the development Mac, and not yet the 1.0 launch.

## [Unreleased]

### Added
- Shared World assistant composer with expandable writing space, removable context chips and matching full, companion and compact layouts.
- Real record, Canvas, Atlas and history attachments; a local context inspector showing source reasons, excerpts and structured workspace data before Send.
- Per-world Explore/Propose, World/Attachments-only scope, record exclusions, selection/history controls and 8/16/32-record excerpt limits. These are device-local request preferences, not exported lore.
- Explore enforced in the core: model proposal blocks are discarded with a notice. Propose still stages draft changes for explicit review; neither mode changes canon.

### Fixed
- Restricted context filters indexed rules, relationships and placements as well as retrieved records, and withholds prior messages that could reintroduce excluded lore.
- Exclusions survive archive/Undo; unreadable saved context preferences restore restricted access instead of silently broadening it.
- Attached boards/history receive priority before index limits. Truncated board placements retain their real total count.
- Selected and attached entity context retains relevant sections and graph neighbours in World scope.
- Disappearing composers and stale draft debounces cannot overwrite a newer shared draft.

## [0.0.3] — 2026-11-16

### Added
- **What-if worlds.** Copy a world into a separate what-if, explore freely, then send its clean changes back to the original's Review as one proposal. Text edited in both worlds is listed and never sent; accepted changes arrive as drafts.
- **Technique trees.** Techniques and progression steps can require one another; Mechanics draws the tree, refuses loops and archives removed requirements.
- **Atlas regions.** Draw outlines linked to records on any map, reshape them by dragging their points, and toggle marker and region layers. Every change has Undo.
- **Timeline views.** Detailed, Compact and By era, with jump chips between eras. Events can be moved earlier or later with Undo.
- **Review checks** for one-way relationships recorded both ways, dates out of order within the same era, and tags spelt more than one way, with a reversible **Merge tags**.
- **Crash recovery.** Editor text that never reached a saved revision is kept on the device and offered back with Restore or Discard.
- **Finder integration.** `.synthesis` world files open from Finder after a confirmation, as new independent worlds.
- **Generate with Codex** in the illustration library (Canvas and Atlas): one explicit request per press, carrying only the typed description. Chat never generates images.
- Performance measurements for large worlds ([docs/PERFORMANCE.md](docs/PERFORMANCE.md)).

### Changed
- Portable `.synthesis` format v7 (imports v1–v6) and JSON export schema 10 carry technique requirements.
- The command palette ranks matching commands and lore above "Capture as an idea".
- Graph layout accepts node size and spacing, used by the technique tree.

### Fixed
- Return in the welcome sheet's name field now starts creating.
- Typing a command name in ⌘K and pressing Return runs the command instead of capturing the text.
- The Canvas top bar is verified opaque and theme-matched in the live window (audit A2).

## [0.0.2] — 2026-11-16

### Added
- Reviewed edits to existing events, history branches and periods, maps and relationship labels, with before/after fields and stale-change rejection.
- Requests carry the current workspace, selected entity, map or board and history branch.
- Collapsible, editable nested chronology; floating contextual companion that keeps its width.

### Fixed
- Unfinished responses and unsent prompts survive Stop; retry keeps newer draft text.
- Canvas viewport loss after first fit and after repeated approval and reload.
- Close parallel relationship arrows and intervening-card detours on Canvas; Graph zoom keeps its focal point.
- Provider and model settings are isolated per app instance, so background checks cannot change an open workspace.

## [0.0.1] — 2026-11-16

First published build of the native studio.

### Added
- Conversation, Canvas (Excalidraw engine), Library, Graph (Dagre), Timeline, Atlas, Review and Worlds as views of one SQLite world.
- AI Assisted / Manual mode enforced in the core; Claude Code or Codex through the creator's own subscription, with no tools, files or host configuration.
- Proposals reviewed change by change; canon requires a separate, explicit acceptance of an exact revision.
- Entity sections, creative components (notes, facts, checklists, progression), Mechanics with rule history, named Atlas maps with place hierarchy, portable `.synthesis` world files, reversible archive with Undo everywhere.

[Unreleased]: https://github.com/desenyon/synthesis/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/desenyon/synthesis/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/desenyon/synthesis/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/desenyon/synthesis/releases/tag/v0.0.1
