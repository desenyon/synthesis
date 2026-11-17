# Current state — 2026-11-17

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`; build `dist/Synthesis.app` here. Native SwiftUI/AppKit + SQLite, with an offline Excalidraw Canvas. 0.0.x versions are published as full GitHub releases (owner instruction); v0.0.3 is the latest. Licensed GPL-3.0. The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` remains untouched and excluded from commits.

## Active — complete expansion brief

The owner requires all 394 items, individually and in numerical order. [EXPANSION](EXPANSION.md) is the acceptance ledger; [EXPANSION_SOURCE](EXPANSION_SOURCE.md) preserves the exact brief. **#1–#29 verified; #30 keyboard-first creation is next.** The full expansion is unfinished.

Latest: [global Back/Forward](NAVIGATION.md) restores entity tabs, both editor panes, map/board/chat addresses, Settings sections/search, Library query/filter/sort, chronology branches, Review focus and inspected sources. Same-mounted editors retain their save callback. Native captures exposed and verified fixes for category-search collation, compact Library overflow and two icon aliases.

`./scripts/check.sh` passed **267 tests / 65 suites**, strict lint and optimized ad-hoc build. **33 final native frames inspected** across 1440×900, 1024×768 and 720×800; **66 native-menu assertions** verify Back/Forward/Back, restored addresses, unchanged lore/mode and inactive-window execution. [Exact evidence](verification/expansion-029/README.md). README includes the returned Library. No live request, foreground input, owner-app restart or release; AGENTS.md unchanged.

Earlier slices include split editing, record drag and per-map Atlas context; #27 retains 17 Canvas tests and 49 engine checks. Physical keyboard/trackpad feel, popovers, animation pacing and VoiceOver remain unverified by background checks. Full session restoration remains #33.

## Latest — chatbox refinement (unreleased)

The shared composer now follows the rest of the app: 16pt bundled Inter for placeholder and typed text, quiet reference chips, one adaptive 32pt toolbar, restrained focus and Send/Stop feedback, and a send-shortcut hint matching the saved preference. Preset/intent controls sit together; context inspection remains beside Send. Canon protection and provider disclosure sit below the writing surface. Sidebar, navigation, model requests, draft ownership and context permissions are unchanged.

Screenshot iteration found two layout defects: a third attachment could wrap outside the narrow field, and a multiline draft could retain a clipped first line after resizing. Attachment rows now measure their actual available width; the native text scroll view remeasures after layout and clears stale offsets only when all text fits. A regression preserves the caret and the scroll position of genuinely overflowing drafts.

`./scripts/check.sh` passed **175 tests / 42 suites**, strict Swift format lint and the optimized ad-hoc native build. **40 final native capture states** at 1440×900 and 1024×768 were inspected in contact sheets, with focused recaptures after the wrapping fix and a same-size before/after comparison. README images refreshed. [Evidence and exact commands](verification/composer-polish/README.md).

No new dependencies, migrations, live model request or release. Background captures establish rendering; foreground typing, native popover interaction, animation pacing and VoiceOver were not retested in this pass. AGENTS.md unchanged.

Launched the rebuilt canonical `dist/Synthesis.app`, opened Conversation and inspected the running window for the owner's review. No draft was entered or message sent; the app is left open.

## Shared composer and context — 2026-11-16

Implemented the supplied World assistant reference in the actual native app: expanding input, real removable lore/map/board/history chips, Explore/Propose, canon explanation and local context inspection. Full Conversation, floating companions and compact workspace bars use the same composer and per-world persisted choices. The sidebar and navigation model are unchanged. [Usage and scope](COMPOSER_CONTEXT.md).

One core context builder serves preview and Send. Exclusions filter the world index as well as record excerpts; restricted scope omits earlier conversation messages. Explore discards proposal blocks regardless of model behavior. Attached boards/history are prioritized before index bounds; archived exclusions survive Undo; unreadable preferences restore restricted access. Selected entities retain their sections and graph neighbours. Screenshot iteration also exposed and fixed a stale composer overwriting a newer shared draft on disappearance.

Verified `./scripts/check.sh`: **174 tests / 41 suites**, strict Swift format lint and optimized ad-hoc build. **32 final native captures** at 1440×900 and 1024×768 inspected in both contact sheets, covering attached/context/browser/overflow/expanded composers, dark/light, active/loading chat, Manual, companions and compact Graph/editor bars. README now includes the new composer/context and refreshed conversation screenshot, explicitly labelled as main after 0.0.3. [Evidence](verification/composer-context/README.md).

No new release, live provider request, foreground pointer/keyboard test or restart of the owner's app. The current build is `dist/Synthesis.app`. Captures verify rendering, not animation pacing, native popover interaction or VoiceOver. Context filtering is record-level, not redaction of secrets repeated in allowed prose. Historical full context snapshots, typed fact/provenance foundations, temporal world projections and the larger expansion brief remain open; see ROADMAP. AGENTS.md unchanged.

## Release 0.0.3 and repository organisation (2026-11-16)

[v0.0.3](https://github.com/desenyon/synthesis/releases/tag/v0.0.3) is published as the latest full release from `cc4ff853e133014fbfdf551b43739f60286295dc`, with the Apple Silicon ZIP, SHA256SUMS, LICENSE and THIRD_PARTY notices. GitHub's ZIP digest matches the tested archive: `9eaa1965ce47c328c4533ae027888499da516eecbc3dd59a1a96d7cd4f45244d`. The extracted archive passed `codesign --verify --deep --strict`, matched the checked binary byte for byte, reported 0.0.3, and rendered four capture states. v0.0.1 and v0.0.2 were converted from pre-releases to full releases with refreshed notes. CI (GitHub Actions: Canvas on Ubuntu, lint/tests/build on a macOS 26 runner) passed on that commit.

The repository now has the GPL-3.0 license, CHANGELOG, CONTRIBUTING, SECURITY (private vulnerability reporting enabled), CODE_OF_CONDUCT, issue and PR templates, Dependabot, `.editorconfig`, a rewritten README with eleven fresh screenshots, a docs index, a current HANDOFF and RUN_PROMPT, and an archive for superseded plans. Description, topics and homepage were updated; the unused wiki was disabled.

## Latest — completion pass (before 0.0.3)

Eleven verified slices, each committed and pushed: extended Review checks with reversible tag merge; editor crash recovery (migration 0011); `.synthesis` file association; large-world measurements ([PERFORMANCE](PERFORMANCE.md)); what-if world branches with reviewed merge-back (0012); technique trees (0013, `.synthesis` v7, JSON schema 10); Atlas regions; Timeline zoom and era overview; event reordering; explicit-click Codex image generation; live A2 verification with two bugs fixed (welcome-sheet Return, palette command ranking).

Checks observed: `./scripts/check.sh` **158 tests / 40 suites**, strict lint, optimized build; Canvas `npm test` **12** and typecheck; foreground `selftest-ui.sh` **19/19** (includes the real modal sheet + Escape); live window captures in dark and light (isolated database); an Accessibility sweep of all nine workspaces plus the editor found no unlabeled controls beyond the system window buttons; background captures inspected for every new state at 1440×900 and 1024×768. Details per slice are in [PROGRESS](PROGRESS.md).

Not done or not verified: a live Codex image generation (needs owner approval to spend allowance); VoiceOver itself, trackpad feel and animation pacing; three-way text merge for what-ifs; drag-to-reorder events; agent proposals for prerequisites and regions; cosmology-specific tools; continuous file sync. C2 (lighter palette) stays unapproved because it reverses the owner's black-studio direction.

## Current checkpoint — 0.0.2 interaction completion pass

Expanded the audit beyond the prior Atlas-only fix. Shared composers now expose current selection context and searchable lore; stopped/interrupted responses and unsent/retry drafts survive. Reading older messages suspends automatic scrolling. Context follows the selected Graph/Atlas entity, Timeline branch, Canvas selection and open editor at submission. One owner-approved isolated Codex request returned cited prose and a staged proposal; no personal lore or second request was used.

Added before/after reviewed edits to existing events, history branches/periods, map metadata and relationship labels, with stale-state rejection and archive portability coverage. Timeline has manual editing, collapsible nested history and descendant counts; accepted chronology changes reset filtering to All history. Atlas acceptance selects/refreshes its target map. Relation-only changes now refresh Review checks. Contextual companions float above secondary workspaces and retain width without resizing their viewport. Canvas retains its dock/takeover.

Fixed close parallel relationships, label placement and basic intervening-card detours. Fixed a real Canvas viewport-loss bug during repeated approval/reload: readiness now waits for committed React app state. Added explicit viewport checks beyond element coordinates, including the first-fit acknowledgement. Provider/model caches now belong to each Studio instance, backed by its database; background verification cannot overwrite the running app’s selection through shared macOS defaults. Hidden Canvas no longer participates in compact companion hit testing/capture. Accepted 284pt sidebar appearance remains intact.

Verified **140 native tests / 30 suites**, strict lint and optimized build; **11 Canvas tests**, typecheck and bundle build; **28 engine/native checks**; **48 native captures inspected in both contact sheets**, plus **16 extracted-package captures inspected in two more sheets**; **one live Codex test passed**. [Full evidence](verification/interaction-0.0.2/README.md). Eight README screenshots refreshed. AGENTS adds one operational requirement for Canvas viewport readiness/reload verification; the learning ledger records evidence and rollback. Owner brief untouched. v0.0.1 remains intact; [v0.0.2](https://github.com/desenyon/synthesis/releases/tag/v0.0.2) is published from `2b792637553ed6d940b0f9d5d4540a6b2b7694a8` with the tested Apple Silicon ZIP, checksums and third-party notices. GitHub’s ZIP digest matches `c86f0c3eba8046612d1f3441b22d2aa065b6bddc1bb74bb4e35a440c172e4a89`.

Physical trackpad feel, animation frame pacing, VoiceOver, dense-board routing/performance and live-CLI Stop remain unverified. Runtime image generation, advanced spatial techniques/cosmology simulation, editable lore-coherent map layers and canon branch merging remain incomplete. Next: isolated physical interaction/accessibility verification and the deeper tools listed in NEXT_PASS. No claim of complete 1.0 product acceptance.

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
