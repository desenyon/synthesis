# Changelog

All notable changes to Synthesis are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). 0.0.x versions are early releases: usable, tested on the development Mac, and not yet the 1.0 launch.

## [Unreleased]

- Optional Dashboard: actual recent entities, unfinished writing, pending proposals, project outlines and saved world activity. Project outlines reuse revisioned entities, sections and portable exports; no generation or canon changes occur on opening.

- Saved workspace layouts (⌥⌘L): per-world views, panels, density, reading width and entity tabs, with rename, update, archive and Undo. Applying uses current lore and preserves Manual mode.

- Reversible entity breadcrumbs and shared Back/Forward history (⌘[ / ⌘]) across records, maps, boards, conversations and worlds. Stale sources resolve current lore; archived and foreign targets cannot be reopened accidentally. Compact Atlas actions preserve the map title; inactive-window hover highlights clear.

- Optional contextual inspectors across workspaces, with real linked object properties, world isolation, independent scrolling and compact-window presentation. Toggle with ⌥⌘I; record editing keeps its existing inspector.

- Empty entity profiles now offer optional writing prompts, portraits, relationship navigation and sourced history. Artwork revisions persist with guarded Undo and portable v8 / JSON11 exports; accepted prose stays unchanged.


### Added

- Expansion #22: structured local search in ⌘K and Library for types, current canon state, real faction/entity relationships, tags, aliases and saved-edit dates. Quoted names, honest query errors, archive scope and pre-limit Library filters preserve result accuracy.

- Expansion #21: universal ⌘K search for lore, scenes, maps/boards, category tools, individual settings and recent world changes. Guarded source navigation, keyboard results and compact sizing preserve Manual mode and unsaved writing.

- Expansion #20: common entity selection and transient hover across Graph, Canvas, Atlas, Library and Timeline. Engine resize handles match the application accent; keyboard Canvas selection and map marker contrast improved.
- Expansion #19: persisted resizable navigation, inspectors and conversation panels, with native splitters, keyboard/accessibility adjustment, Settings controls and saved-layout support. Narrow editors float the inspector to preserve writing space.
- Expansion #18: accurate autosave/search feedback, named review progress and partial-failure counts, visible AI failures and elapsed hypothetical generation. World changes stop unapplied review decisions.
- Expansion #16: per-world document tabs, pins, recent reopening and keyboard cycling. Tab/workspace changes retain native caret, scroll, formatting and independent undo; failed saves keep the current document open.
- Expansion #15: graph semantic zoom from compact titles through summaries to stored artwork and relationship labels. Ports follow visible cards; offscreen culling and bounded thumbnails avoid repeated image decoding.
- Expansion #6: persisted Compact, Comfortable and Immersive density in Settings. Navigation and history rows, Library previews, Worlds/Mechanics cards and entity-section spacing adapt together.
- Shared World assistant composer with expandable writing space, removable context chips and matching full, companion and compact layouts.
- Real record, Canvas, Atlas and history attachments; a local context inspector showing source reasons, excerpts and structured workspace data before Send.
- Per-world Explore/Propose, World/Attachments-only scope, record exclusions, selection/history controls and 8/16/32-record excerpt limits. These are device-local request preferences, not exported lore.
- Explore enforced in the core: model proposal blocks are discarded with a notice. Propose still stages draft changes for explicit review; neither mode changes canon.

### Fixed
- Expansion #17: background regression audit verifies independent sidebar, document and inspector scrolling while toolbar and composer frames stay fixed.
- Expansion #14: light Canvas and Graph have a distinct spatial base, white entity/tool surfaces and clearer shared text and boundaries. Native and bundled Canvas palettes agree; dark/OLED styling stays intact.
- Expansion #9: Atlas drawing and marker tools cannot conflict; marker placement supports Undo. New relationships clear prior reverse settings. Canvas styles target editable drawings only and adapt to selection.
- Expansion #8: transient hover feedback clears after navigation, disabling and focus loss. Shared restrained transitions honor Reduce Motion; confirmation toasts stay above compact composers.
- Expansion #5: Canvas category accents now match native views, including readable light colors; Graph and Canvas use consistent Phosphor category glyphs. Historical events share a calendar identity across Library and Timeline.
- Restricted context filters indexed rules, relationships and placements as well as retrieved records, and withholds prior messages that could reintroduce excluded lore.
- Exclusions survive archive/Undo; unreadable saved context preferences restore restricted access instead of silently broadening it.
- Attached boards/history receive priority before index limits. Truncated board placements retain their real total count.
- Selected and attached entity context retains relevant sections and graph neighbours in World scope.
- Disappearing composers and stale draft debounces cannot overwrite a newer shared draft.
- Narrow composers measure attachment wrapping instead of hiding a third chip. Multiline input remeasures after native layout and clears a stale scroll offset when the whole draft fits, preserving the caret and longer drafts' scroll positions.

### Changed
- Expansion #4: entity identity stays prominent across Overview, Sections and Mechanics; a shared 32pt title, quieter metadata and long-name wrapping preserve page hierarchy.
- Expansion #3: semantic typography and shared spacing, radii and elevation tokens replace repeated control/card/page constants. Existing sidebar geometry and rich document formatting are preserved.
- Expansion #2: shared native frosted materials for floating toolbars, inspectors, menus and composers, with opaque Reduce Transparency and Increase Contrast fallbacks.
- Expansion #1: graphite dark surfaces by default with a persistent true-black OLED option shared by native workspaces, Canvas and board image export.
- Refined the shared chatbox to match the app's controls: larger Inter writing text, quieter references, an adaptive toolbar, subtle Send/Stop feedback and a shortcut hint that follows the saved preference. Canon protection and provider disclosure remain available below the writing surface.
- Composer placeholder and typed text now use the same bundled font; ordinary line growth responds immediately, and shared hover feedback honors Reduce Motion.

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
