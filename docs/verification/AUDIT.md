# Product audit checklist

Audit of the native SwiftUI/AppKit application, started 2026-11-12 against commit d02798b. Status values: **fixed** (implemented and observed in the running app), **partial**, **open**. Evidence lives in [audit-2026-11-12](audit-2026-11-12/): contact sheets of 32 states at four window sizes, 20 sheet captures, the capture log and the interaction self-test log.

## P0 — structural

| # | Problem found | Cause | Resolution | Status |
| - | - | - | - | - |
| 1 | No window controls; the window could not be closed, minimised, zoomed or made full screen from the UI, and native automation saw no window. | Borderless `NSWindow`. | Titled window with full-size content and a transparent title bar; traffic lights centred in the 56-point header and re-laid out after appearance changes. Frame is restored between launches. | fixed |
| 2 | Two stacked 56-point headers on every screen, and world identity shown twice. | Global header and workspaces designed separately. | One `WorkspaceBar` per workspace carries context, actions and the persistent AI Assisted / Manual switch. The world switcher lives once, at the top of the navigation. | fixed |
| 3 | Six workspaces used three unrelated header styles and names that did not match navigation ("Knowledge Graph", "Universal history", "Beyond the horizon."). | No shared chrome or tokens. | `Theme` + `Components` (buttons, chips, fields, badges, empty states, sheets, floating panels). Every workspace is named as in navigation and uses the same bar, type scale and radii. Serif and system-default styles removed. | fixed |
| 4 | ⌘K was a modal sheet titled "Find a thread." with no keyboard navigation or actions. | Search built as a form. | Command palette overlay: navigation, creation, full-text lore search, conversations, worlds and preferences; arrow keys, Return, Escape. | fixed |
| 5 | Nothing could be removed; boards could not be renamed. | Store had no reversible removal path. | Migration 0004 adds `archived` to records, conversations, boards and events. Archive hides without discarding; every removal offers Undo, and Library, conversation history and the board menu list archived items for restore. Archived material stays in export. | fixed |
| 6 | Opening a record from Canvas, Graph, Timeline or chat always "returned" to Library. | `openRecord` overwrote the destination. | Records open over the current workspace; Back names and returns to where the creator was. Last workspace is restored at launch. | fixed |
| 7 | About 2,000 lines of superseded UI compiled into the app. | Kept as "source history". | Removed RootView, ChatWorkspace, CanvasDesign, DesignSurface, CanvasScreen, ManualHome and WorldArt. Git history retains them. | fixed |

## P1 — workspace quality

| # | Problem found | Resolution | Status |
| - | - | - | - |
| 8 | Canvas letterboxed 160 points above the composer; edges ran centre-to-centre under cards; edges did not follow a dragged card. | Board fills the workspace with floating controls. Connectors leave and enter on facing card sides using measured card sizes, with arrowheads at the target and separate lanes for parallel links. Cards and connectors move together during a drag. | fixed |
| 9 | No marquee, no keyboard, zoom ignored the pointer, new cards ignored the viewport, no ungroup. | Marquee selection; Delete, Escape, Return, ⌘A, arrow-key nudge, V/H/C tools; zoom anchored to the pointer; new cards land in view without overlapping; group/ungroup; row/column arrange; tidy grid. | fixed |
| 10 | Connect affordance was an unexplained icon; grouping hidden in a menu. | Drag a card's handle onto another card, or use the Connect tool; a selection bar offers Group, Row, Column, Connect, Remove. Relationship labels suggest ones already used in the world. | fixed |
| 11 | Conversation empty state clipped behind the composer; modes were an unexplained menu; composer height guessed from character count. | Empty state explains the five modes and offers real records to reference; composer measures its own text; Manual shows a calm paused state. | fixed |
| 12 | Markdown renderer lacked lists, quotes, heading levels and rules, and broke fenced code containing blank lines; streaming text scrolled out of view. | Line-based block parser with unit tests; transcript follows streamed text. | fixed (streaming follow not exercised with a live provider) |
| 13 | Library showed one icon for every entity; search ignored tags and aliases; no hover, context menu, dates or badges. | Category tiles and colours, state badges, relative dates, kind/canon/archived filters with counts, sort, full-text search, hover and context actions. | fixed |
| 14 | Canon review and links hidden in an overflow menu and sheet; canon review showed two unlabelled text blocks; category was an unmarked text field. | "Review for canon" is a visible action. Review shows a line diff against accepted canon. A details inspector shows status, origin, tags, aliases, relationships, links, backlinks and timeline events. Category is a menu. | fixed |
| 15 | Graph used a fixed circle with edges through nodes; no pan or node drag; relationships not editable. | Deterministic force-directed layout shaped to the window; pan, pointer-anchored zoom, draggable nodes; neighbourhood emphasis; docked details; create, relabel and remove relationships with Undo. | fixed |
| 16 | Timeline events could not be edited or removed; "±" changed row spacing. | Edit and remove (with Undo); date rail; source chips open the record; unknown dates stay explicitly unknown. | fixed |
| 17 | Atlas markers could not be removed, the map could not be replaced, markers had no labels. | Labelled markers, remove with Undo, replace map, scroll/pinch zoom, selected-record card. | fixed |
| 18 | Sheets had whimsical, unclear titles and mixed fonts. | One `SheetScaffold`; plain titles; Settings grouped into Appearance, This world, Assistant. | fixed |
| 19 | Sidebar section labels centred over left-aligned rows; no counts; no row actions. | Aligned sections, category counts, shortcut hints on hover, conversation rename/archive. | fixed |
| 20 | Notices were an unstyled bar with "Dismiss". | Auto-dismissing toasts with Undo. | fixed |
| 21 | Window size and last workspace not restored. | Frame autosave; last workspace persisted. | fixed |
| 22 | Found in pass 2: long conversation and board titles widened their bars and pushed the companion off-screen. | Title menus truncate; bars collapse labels to icons when space is short. | fixed |
| 23 | Found in pass 2: the companion divider was a 1-point target that could not be dragged. | 9-point grab column. Verified by self-test. | fixed |
| 24 | Found in pass 3: in a narrow window the docked companion crushed the canvas. | Below 860 points the companion takes over the workspace instead of docking. | fixed |
| 25 | Found in pass 3: a card's connection handle vanished as the pointer reached its outer half. | Hover region widened to include the handle. | fixed (hover itself not automatable; drag-to-connect verified) |

## Verification evidence

- `./scripts/check.sh`: strict format lint clean, 32 tests in 3 suites passed, optimized build produced.
- `./scripts/verify-ui.sh docs/verification/audit-2026-11-12`: 148 captures from the release build (32 states × 1440×900, 1920×1080, 1024×768, 720×800, plus 20 sheets) at 2× backing scale. All four contact sheets and the sheet panel were inspected; 1440, 1024 and 720 were also inspected at full size during the passes. The final captures predate fix 25, which changes no resting state.
- `./scripts/selftest-ui.sh`: 13 of 13 checks passed in one run on the release build (`selftest.log`). It posts real pointer and key events to the app's own window: header button under the title bar, palette row tap, card drag with persisted position, undo, drag-to-connect opening the label sheet without creating a relationship, marquee, Delete keeping source records, arrow-key nudge, double-click to open, Back to Canvas, companion resize, graph pan leaving relationships untouched.

- Upgrade check: a database built from migrations 0001–0003 with one world, record, conversation, board and event was opened by the release build. Migration 0004 applied, every existing row was kept with `archived = 0`, and the sample fixtures were added as separate worlds without touching the existing one.

## Remaining work

Not done in this audit, in rough priority order:

1. **Live provider path.** Streaming, stop and error states were not exercised against a real model; no key was configured and no paid call was made. The offline transport tests still pass.
2. **Structured proposals.** Model output can only be saved as an AI-proposed draft. Multi-record proposals with a reviewable change set are not built.
3. **Inline `@` mentions.** Lore references use a menu; typing `@` does not autocomplete.
4. **Scale.** Canvas and Graph were checked with 4–7 items. Large boards and graphs are unmeasured; graph layout is O(n²) per iteration.
5. **Trackpad gestures.** Two-finger pan and pinch zoom are implemented but cannot be posted by the self-test.
6. **Accessibility pass.** Controls carry labels and selected traits, but VoiceOver and full keyboard traversal of cards and graph nodes were not walked.
7. **Canvas depth.** No card resize, snapping or alignment guides; group frames cannot be named.
8. **Timeline and Atlas depth.** No drag reordering of events, no canon state for events, one map per world, markers cannot be dragged.
9. **Light theme.** Seven light states were captured and inspected; sheets were captured in dark only.
10. **Crash recovery.** A failed save is kept in the open editor but not recovered across a process crash.
