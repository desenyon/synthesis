# Current state — 2026-11-16

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`; build `dist/Synthesis.app` here. Native SwiftUI/AppKit + SQLite, with an offline Excalidraw Canvas. Development only. The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` remains untouched and excluded from commits. AGENTS.md is unchanged.

## Current implemented slices

- Shared full, companion and compact lore-aware composers; themed app menus and form choices; Reduce Motion-aware workspace transitions. Native Kokonut-inspired activity uses actual retrieval, response and proposal events, never demo playback. [Usage](AI_COMPONENTS.md).
- Graph uses bundled Dagre 3.1.3 with native entity cards, ports, relationship editing and neighbourhood selection. Canvas uses the same IDs, explicit undoable Arrange and PNG export containing actual card text, state and local artwork. Graph remains derived; Canvas remains manually curated.
- Notes, Facts, Checklist and Progression components use ordinary searchable, revisioned lore across workspaces and entity Sections. Manual creation and reviewed `create_component` proposals share validated descriptors. Checklist edits preserve canon and reject stale/rich-text replacement. No model-supplied code runs. [Component contract](CREATIVE_COMPONENTS.md).
- Entity **Mechanics** provides kind-filtered rules, scenarios, explicit canon review and restorable history. Rule revisions retain accepted wording; stale acceptance is rejected. Agent rule/scenario proposals require review, cannot approve canon and cannot invent creator verdicts. [Mechanics guide](MECHANICS.md).
- Searchable Settings, device writing/navigation preferences, portable per-world defaults, Worlds, rich editor, entity sections, source links, nested chronology branches/periods, reversible archive and Manual-mode cancellation remain connected to the same database.

Migrations 0009 (components) and 0010 (rule history) are additive. Portable `.synthesis` format **v6** imports v1–v5 as independent copies; JSON export is **schema 9**. History starts on the first edit/promotion for legacy rules. Archives include lore and history, never provider/device credentials.

## Latest verification

- `./scripts/check.sh`: strict Swift lint, **109 tests / 25 suites**, optimized ad-hoc development build passed. New tests cover rule-history round trip, earlier canon preservation, stale rule proposals, successful draft acceptance, invalid parents and empty scenario verdicts. They caught and fixed a rule-ID/document-ID mismatch in proposal acceptance.
- **14 Mechanics captures** at 1440×900 and 1024×768 inspected in both contact sheets: populated, light, Manual, empty, scenario creation, canon review and history. Evidence: `verification/mechanics`.
- README refreshed with seven inspected native screenshots from this checkpoint, including Mechanics. Capture notes are in `docs/screenshots`.
- Earlier slices this session: **12 component captures** (`verification/creative-components`) and **28 connected presentation captures** plus actual exported PNG (`verification/connected-presentation`), inspected at their respective checkpoints.
- Canvas typecheck, **9 Node tests**, bundle build and **22 native/WebKit audit checks** passed for the connected-presentation slice. These were not rerun for later Swift-only Mechanics changes.
- Checks/captures use isolated databases and background windows. No foreground self-test, live subscription request, paid image generation, native save-dialog walkthrough or owner's data edits. The running user app was not quit or relaunched. Captures establish layout, not physical interaction or animation smoothness.

## Remaining acceptance and scope

The prior master audit completed 19 items; A2 remains unticked because the required live Canvas check failed at macOS screen capture (`SCStreamErrorDomain -3812`). C2 is unapproved. The latest explicit composer instruction authorizes the shared composer rebuild, but the older C3-specific 36-point pill proposal was not adopted or ticked. History is in [PROGRESS](PROGRESS.md).

Native popover keyboard/pointer behaviour, live streaming/Stop, large-board/graph performance, dense obstacle routing, trackpad and VoiceOver need further interaction coverage. No arbitrary generated UI, spatial technique simulator, canonical branch merge, editable lore-coherent map geometry or on-demand subscription image generation is claimed. Creative components are an initial closed vocabulary, scoped per world/workspace rather than per individual conversation or board.

Next: named Atlas maps and reliable map-specific operations, then richer chronology and specialized spatial studios. Continue the ledger in [NEXT_PASS](NEXT_PASS.md); preserve existing lore and the canon boundary.
