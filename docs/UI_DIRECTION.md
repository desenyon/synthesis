# Design direction

The accepted graphite foundation, applied as one system. Tokens live in `Theme.swift`; shared pieces in `Components.swift`. A screen that needs a colour, radius or control not found there is a signal to extend the system, not to improvise.

## Shell

- Native titled window, content under a transparent title bar. Traffic lights centred in a 56-point integrated header; no separate OS title bar.
- Navigation: 220-point labelled panel or 56-point rail with tooltips. World switcher at the top, six workspaces, category lenses with counts, recent conversations, Settings.
- Every workspace begins with `WorkspaceBar`: icon and title on the left, workspace actions, then the persistent AI Assisted / Manual switch and search. Titles truncate; when the full bar does not fit, labelled actions become icons.
- ⌘K opens the command palette. Removal shows a toast with Undo.

## Tokens

- Dark surfaces #17191C / #1D2024 / #262A30 / #30353D; text #ECEBED, secondary #BEC5CE, muted #929CAA; accent #A9C7DB. Light counterparts cover every token.
- Semantic accents are muted and limited: characters, factions, places, power systems, cosmology; canon green, warning amber, danger red.
- Type is the system sans at 11.5–17 for interface text, 26–32 for the two display lines. No serif. Monospace only for code.
- Radii: 7–8 controls, 12 cards, 14 panels. Controls are 28–30 points tall.

## Workspaces

- Conversation: 720-point reading column, bottom composer, explicit provider disclosure. Assistant output is labelled "Suggestion · not canon".
- Canvas: saved, manually arranged board. 300-point cards with 17-point titles, 14-point text and a state badge. Connectors join facing sides with an arrowhead at the target; board-only links are dashed. Empty boards stay empty. Floating toolbar, zoom and compact composer; the companion docks at 320–460 points or takes over below 860.
- Graph: derived from stored relationships, never saved. Layout is deterministic and shaped to the window.
- Library, Timeline, Atlas: lists and cards use the same tiles, badges and empty states.
- Editor: writing column up to 780 points with a 300-point details inspector. Canon review is a diff.

## Behaviour

Short transitions (0.14–0.2 s), no looping animation beyond the system progress indicator, reduced motion respected. Save failures stay visible. Authored capture fixtures are labelled and never presented as model output. No performance claim without a measurement.
