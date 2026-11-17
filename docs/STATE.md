# Current state — 2026-11-16

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`; build `dist/Synthesis.app` here. Native SwiftUI/AppKit + SQLite, with an offline Excalidraw Canvas. Development prerelease 0.0.1 is owner-authorized; the 1.0 public product launch remains later. The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` remains untouched and excluded from commits. AGENTS.md changes only the former no-releases sentence to reflect that explicit authorization.

## Follow-up on main — Atlas interaction audit

After the published release, corrected Atlas button zoom drift after panning. Graph and Atlas now share `SpatialViewport`, with separate zoom limits and guards against invalid gesture coordinates. Atlas retains its decoded image between loads/replacements so pan/zoom renders no longer decode the base64 payload repeatedly. The accepted sidebar composition is unchanged.

Verified `./scripts/check.sh`: strict lint, **124 tests / 27 suites**, optimized build. Ten focused geometry/approval tests passed; marker acceptance now has explicit regression coverage for both switching to an affected map and refreshing the already-active map while retaining artwork, source records and other maps. **12 native captures** inspected at 1440×900 and 1024×768 across dark/light/Manual Atlas, empty child map and Graph. [Evidence](verification/atlas-followup). No foreground input, animation benchmark or live provider call. No user-data edits or app restart. The Aeronia attachment remains a private reference. AGENTS.md unchanged in this follow-up; the published tag/assets below remain intact, so these additional fixes are on main and in the local development build.

## 0.0.1 — connected interaction fixes

Published [v0.0.1](https://github.com/desenyon/synthesis/releases/tag/v0.0.1), prerelease (not draft), from `88a6c2eef805afa1ae4506596450bc2e78e5b1c6`. Apple Silicon ZIP, SHA256SUMS and third-party notices uploaded. GitHub's ZIP digest matches the tested local artifact: `ff22a54271450d77df5d3cb078a35fa054343c3a1ffb164a721af5e12d76a67a`.

- Sidebar narrowed to 284pt without changing its composition. Hover cleanup, composer focus/height feedback and workspace/companion transitions retain Reduce Motion behavior.
- Graph uses one bounded, focal-point-preserving zoom transform for buttons and gestures. Fit and zoom share the 10% minimum. Selected details float over the graph without resizing its viewport; overview titles retain a readable minimum size.
- Stored Canvas relationship arrows and labels are locked to world records. Click the label to inspect/edit; Hide on board remains separate from world archive. Newly converted connections use the same routing/styling as existing links.
- One reviewed proposal can create nested chronology branches/periods and their events by dependency. Accepting an event without an existing source atomically creates a draft source. All history exposes a selectable hierarchy including empty branches. Review explains parent placement and implicit draft creation.
- Accepted map/marker changes select their affected Atlas map; existing worldRevision observers reload the data. Tests exercise actual Studio acceptance through history and map selection. Canon stays unchanged.
- Each request snapshots the active workspace; navigating alone makes no model calls. Codex memories/external memories/host skill discovery are disabled. A runtime/authentication environment allowlist excludes unrelated agent sessions, prompts, API keys and project variables. Authentication stays with the user's CLI.

Verified: strict lint, **120 native tests / 27 suites**, optimized build, Canvas typecheck/build and **9 Node tests**. **44 native captures** were inspected (26 initial, 14 final refinements, 3 README, 1 packaged-app audit), plus the actual PNG export. The extracted distribution ZIP passed signature validation and **24 Canvas engine checks**; four final sidebar pixel checks passed. Eight README screenshots refreshed. Verification and release evidence: `verification/prerelease-0.0.1`. The archive is Apple Silicon, ad-hoc signed, not notarized. No live subscription request, foreground interaction/animation walkthrough, Intel build or macOS 14 hardware test was performed. Background tests do not interrupt the user's running app. See [release notes](releases/0.0.1.md).

## Earlier sidebar checkpoint

The owner-directed sidebar is implemented in the actual native shell: 312pt expanded / 72pt rail, graphite vibrancy with explicit appearance and opaque accessibility fallbacks, 40pt world artwork, matched New Chat/Search actions, monochrome 38pt navigation, aligned counts, scrolling history with stable action slots, and persistent Settings/current-appearance controls. Existing Studio navigation, world files, conversation management and data are preserved. [Design details](SIDEBAR.md).

Latest check: `./scripts/check.sh` passed strict lint, **115 tests / 27 suites** and the optimized development build. New regressions cover preference restart/content preservation and unsaved-editor guards across sidebar destinations. **25 sidebar captures** at 1440×900, 1024×640 and 1024×520 were inspected, alongside seven refreshed README screens. **12 native screenshot pixel checks** and four shortcut-registration/action checks passed. Evidence is in `verification/sidebar`; visual verification does not establish foreground Tab, pointer, popover or VoiceOver behavior. No model calls or user-database access occurred. The working application was not restarted.

## Current implemented slices

- Shared full, companion and compact lore-aware composers; themed app menus and form choices; Reduce Motion-aware workspace transitions. Native Kokonut-inspired activity uses actual retrieval, response and proposal events, never demo playback. [Usage](AI_COMPONENTS.md).
- Graph uses bundled Dagre 3.1.3 with native entity cards, ports, relationship editing and neighbourhood selection. Canvas uses the same IDs, explicit undoable Arrange and PNG export containing actual card text, state and local artwork. Graph remains derived; Canvas remains manually curated.
- Notes, Facts, Checklist and Progression components use ordinary searchable, revisioned lore across workspaces and entity Sections. Manual creation and reviewed `create_component` proposals share validated descriptors. Checklist edits preserve canon and reject stale/rich-text replacement. No model-supplied code runs. [Component contract](CREATIVE_COMPONENTS.md).
- Entity **Mechanics** provides kind-filtered rules, scenarios, explicit canon review and restorable history. Rule revisions retain accepted wording; stale acceptance is rejected. Agent rule/scenario proposals require review, cannot approve canon and cannot invent creator verdicts. [Mechanics guide](MECHANICS.md).
- Atlas supports named maps, place/parent links, child navigation, record-to-map navigation and click-to-move markers. Save/Undo target the original world/map and reject stale content. Reviewed `create_map` proposals create empty maps; the creator chooses imagery. Structured references are validated on portable import. [Atlas guide](ATLAS.md).
- Searchable Settings, device writing/navigation preferences, portable per-world defaults, Worlds, rich editor, entity sections, source links, nested chronology branches/periods, reversible archive and Manual-mode cancellation remain connected to the same database.

Migrations 0009 (components) and 0010 (rule history) are additive. Portable `.synthesis` format **v6** imports v1–v5 as independent copies; JSON export is **schema 9**. History starts on the first edit/promotion for legacy rules. Archives include lore and history, never provider/device credentials.

## Earlier feature verification

- `./scripts/check.sh`: strict Swift lint, **113 tests / 26 suites**, optimized ad-hoc development build passed. Tests cover map hierarchy, stale Undo, world isolation, reviewed map creation and import rollback, alongside rule-history round trip, earlier canon preservation, stale rule proposals, successful draft acceptance, invalid parents and empty scenario verdicts. They caught and fixed a rule-ID/document-ID mismatch in proposal acceptance.
- **14 Atlas captures** at 1440×900 and 1024×768 inspected: linked maps in dark/light/Manual, map details, creation, local and empty states. Evidence: `verification/atlas-maps`. The last core-only import-validation change did not alter the captured UI.
- **14 Mechanics captures** at 1440×900 and 1024×768 inspected in both contact sheets: populated, light, Manual, empty, scenario creation, canon review and history. Evidence: `verification/mechanics`.
- README refreshed with seven inspected native screenshots across these checkpoints, including Mechanics and the linked Atlas. Capture notes are in `docs/screenshots`.
- Earlier slices this session: **12 component captures** (`verification/creative-components`) and **28 connected presentation captures** plus actual exported PNG (`verification/connected-presentation`), inspected at their respective checkpoints.
- Canvas typecheck, **9 Node tests**, bundle build and **22 native/WebKit audit checks** passed for the connected-presentation slice. These were not rerun for later Swift-only Mechanics changes.
- Checks/captures use isolated databases and background windows. No foreground self-test, live subscription request, paid image generation, native save-dialog walkthrough or owner's data edits. The running user app was not quit or relaunched. Captures establish layout, not physical interaction or animation smoothness.

## Remaining acceptance and scope

The prior master audit completed 19 items; A2 remains unticked because the required live Canvas check failed at macOS screen capture (`SCStreamErrorDomain -3812`). C2 is unapproved. The latest explicit composer instruction authorizes the shared composer rebuild, but the older C3-specific 36-point pill proposal was not adopted or ticked. History is in [PROGRESS](PROGRESS.md).

Native popover keyboard/pointer behaviour, live streaming/Stop, large-board/graph performance, dense obstacle routing, trackpad and VoiceOver need further interaction coverage. No arbitrary generated UI, spatial technique simulator, canonical branch merge, editable lore-coherent map geometry or on-demand subscription image generation is claimed. Creative components are an initial closed vocabulary, scoped per world/workspace rather than per individual conversation or board.

Next: richer chronology and specialized spatial studios; editable map layers, technique trees and expanded interaction/accessibility coverage remain open. Continue the ledger in [NEXT_PASS](NEXT_PASS.md); preserve existing lore and the canon boundary.
