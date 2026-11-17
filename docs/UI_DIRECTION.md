# Design direction

The accepted graphite foundation, applied as one system. Tokens live in `Theme.swift`; shared pieces in `Components.swift`. A screen that needs a colour, radius or control not found there is a signal to extend the system, not to improvise.

## Shell

- Native titled window, content under a transparent title bar. Traffic lights centred in a 56-point integrated header; no separate OS title bar.
- Navigation: default 284-point labelled panel (resizable 240–360) or 72-point rail with tooltips. World switcher at the top, seven workspaces (Review shows a count when something waits), category lenses with counts, recent conversations, Settings.
- Every workspace begins with `WorkspaceBar`: icon and title on the left, workspace actions, then the persistent AI Assisted / Manual switch and search. Titles truncate; when the full bar does not fit, labelled actions become icons.
- ⌘K opens the command palette. Removal shows a toast with Undo.

## Tokens

- Dark graphite surfaces #111315 / #1A1D21 / #24282E, stroke #353B43; text #E6E9EF, secondary #B6BBC5, muted #8F96A3; accent #A9C7FF. OLED is an explicit true-black option. Light counterparts cover every token.
- Semantic accents are muted and limited: characters, factions, places, power systems, cosmology; canon green, warning amber, danger red.
- Bundled Inter is shared by native views and Canvas. Semantic `TextRole` values live in Typography.swift: title 30, section 20, card title/body 16, control 14, label 13, caption 12, section label 11. Rich document text retains the creator’s saved formatting. Monospace is for code.
- `Metric` centralizes radii, control heights, reading widths and page insets; `Space` defines the four-point spacing rhythm. `Elevation` distinguishes cards, floating controls, companions and composers. Surface, stroke opacity and interaction colors resolve through Theme. Shared controls use these tokens; dimensions inherent to map/graph geometry remain local.

## Workspaces

- Conversation: 720-point reading column, bottom composer, explicit provider disclosure. Assistant output is labelled "Suggestion · not canon".
- Canvas: saved board on the Excalidraw engine, themed with the graphite tokens. 300-point record cards (category, 20-point title, 14-point text, state line) in the application palette; relationship arrows in the accent colour. Empty boards stay empty. Synthesis toolbars dock at the edges; the compact composer floats bottom-centre; the companion resizes from 320–600 points while reserving working space, or takes over below 860.
- Graph: derived from stored relationships, never saved. Layout is deterministic and shaped to the window.
- Library, Timeline, Atlas: lists and cards use the same tiles, badges and empty states.
- Editor: writing column up to 780 points with a resizable 260–480-point details inspector (300 by default). The inspector floats when docking would leave less than 480 points for writing. Canon review is a diff.

## Behaviour

Short transitions (0.14–0.2 s), no looping animation beyond the system progress indicator, reduced motion respected. Save failures stay visible. Authored capture fixtures are labelled and never presented as model output. No performance claim without a measurement.

### Historical 2026-11-15 refinement

The current shell uses flat neutral charcoal, restrained blue selection, 248-point grouped navigation (64-point rail), real world categories and recent conversations. At that checkpoint Lucide replaced SF Symbols; the current native and Canvas icon family is Phosphor, with no generated icons. Shared native light/dark tokens remain authoritative. Canvas has compact edge-docked tools, a Synthesis-owned drawing style panel, and smaller filled relationship arrowheads with monotonic tangent routes. The owner design brief remains unmodified. Exact match to the latest mentioned attachment cannot be certified because no file arrived with that message.
