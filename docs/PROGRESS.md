# Development progress

## 2026-11-15 — continuation

Baseline: main at `353728c`; owner's `docs/DESIGN_AGENT_BRIEF.md` remains untracked and untouched. No releases. Verification uses temporary databases and background windows; the user's running application is not restarted.

### Checkpoint A — Canvas dependency maintenance (verified)

Observed 12 npm audit findings in the Excalidraw dependency tree. Retain Excalidraw 0.18.1. Test narrowly pinned patched dependencies instead of npm's breaking engine downgrade. Rebuild the committed offline bundle, run engine integration checks, and remove obsolete generated chunks through Vite's managed output cleanup. Upstream React/Radix peer warnings remain. Verified: zero npm audit findings, typecheck, eight Node tests, rebuilt offline bundle, 19 passing background engine checks including PNG export and persistence. No foreground activation or model call.

### Checkpoint B — editable entity sections (verified; follow-ups in AUDIT.md)

Characters, Systems, Places, power systems and cosmology need creator-defined sections. Build these as ordered child lore records, with a world-scoped membership table, rather than opaque UI-only fields. Each section keeps its own revision history, source link, FTS entry and explicit canon approval. The parent's accepted text is not implicitly changed by editing a section. Membership removal archives the association, with Undo; content remains in Library.

Native entity pages get Writing / Sections navigation, readable cards, create/edit/open/reorder/remove controls and optional blank section-name suggestions. No generated lore or compulsory template. The shared contextual assistant sees section records and can propose a section through existing per-change review. Portable archives, JSON and Markdown must preserve content and membership.

Acceptance: restart/round-trip persistence; world isolation; atomic creation; stale-save rejection and unchanged canon; archive/restore; reviewed agent creation; background dark/light/compact rendering. Images, map geometry and full specialized studios remain later slices.


Observed checks so far: the proposal test failed because `add_section` was not recognized, then passed after integration. Persistence tests exposed missing snapshot/JSON/Markdown membership and missing selected-entity context; those are fixed. A malformed import regression exposed acceptance of lore-as-parent membership; the transaction now rejects it. Portable format v3 accepts v1/v2, JSON export is schema 7, and Markdown uses relative section links. Full strict lint, 78 native tests in 17 suites and optimized development build passed before the final joined section-hydration refinement; final checks follow capture review.

Cleanup: removed the unreferenced `Assets/landscape.png` and `scripts/render-scenery.py`. Kept the used sample cover and its generator. No user content, design brief or historical verification evidence removed. Current docs are being reconciled; historical decisions remain dated history.

Final checks for Checkpoint B, run after the joined section-hydration change: `./scripts/check.sh` passed (strict lint, 78 tests in 17 suites, optimized development build). All 47 capture states were rendered at 1440×900 and 1024×768 and inspected. Sections, the section editor, the creation sheet, light and Manual variants and the companion layout render as built. The `empty-sections` capture is wrong (it shows the empty world's Library), so the empty Sections state is not verified.

### Checkpoint C — full visual and behaviour audit (list saved, fixes not started)

The capture review found defects that earlier passes missed, most seriously the sidebar and the Canvas top bar rendering in the opposite theme, and section records flooding Library and category counts. The full list, with cause, exact fix and a paste-ready prompt for each item, is in [AUDIT.md](AUDIT.md). No fixes from that list are applied yet. No live model call, pointer self-test or native sheet walkthrough was run in this pass.

### Audit A1 — completed

Opaque sidebar and explicit NSWindow appearance at all background assignments. `./scripts/check.sh`: lint, 78 tests / 17 suites, optimized build passed. Seven requested 1440×900 captures inspected; pixel assertion failed on the prior light capture and passed all seven corrected captures. Running app toggled light/dark/light and inspected, then restored dark. Initial live views were Stage Manager thumbnails; raised the actual window for full-size inspection. Evidence: `docs/verification/audit-A1`. No model requests.

### Audit A2 — implemented, live verification blocked

Opaque Canvas header and companion divider; initial engine theme comes from the native URL before React renders. Canvas typecheck, eight tests and bundle build passed. `./scripts/check.sh` passed: lint, 78 tests / 17 suites, optimized build. All five requested states at both sizes captured and both contact sheets inspected: header and titles correct. Live inspection retried with path and bundle ID after capture runner exit, but macOS returns `SCStreamErrorDomain -3812` (invalid parameter). A2 remains unticked pending that check. Evidence: `docs/verification/audit-A2`.

### Audit B1 — completed

Active world-scoped section memberships drive top-level navigation, Library counts and Conversation suggestions; Sections filter preserves access and labels parents. Search, mentions and retrieval retain child records. ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Library, conversation-home and sections captured at both sizes and both contact sheets inspected; sample Characters now shows 2, Library shows 9 top-level items. Evidence: `docs/verification/audit-B1`.

### Audit B2 — completed

Entities default to Overview with per-record session tab memory. Sections shows its count and omits duplicated parent prose; fixtures explicitly select that tab. ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Editor, sections and light-sections captured at both sizes; both contact sheets inspected. Evidence: `docs/verification/audit-B2`.

### Audit C1 — completed

Shared ContentColumn and ContentHeader align Library, Review, Timeline, Sections, Settings and Worlds at 880 pt with 28 pt side padding. Corrected the history menu centering after the first visual pass. Final ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Seven requested states at both sizes recaptured and both final contact sheets inspected. Editor reading width and unapproved C2/C3 unchanged. Evidence: `docs/verification/audit-C1`.

### Audit B4 — completed

Fit uses Excalidraw canvasOffsets for initial layout, native Fit and engine Fit. Native measures the collapsed composer and reserves its height + 24 pt, its 76 pt dock offset, and toolbar space (76 top, 80 right). ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Canvas typecheck, eight Node tests and bundle build passed; 20 WebKit integration checks passed including fitted bounds clearing overlays. Canvas/collapsed/manual captured at both sizes and inspected: no card beneath composer or toolbars. Evidence: `docs/verification/audit-B4`.

### Audit B5 — completed

Canvas cards show their normalized category once and Draft/Canon/Idea/Hypothetical state in the footer. Engine export and overlay share category/state wording. Canvas typecheck, eight Node tests and rebuilt bundle passed; ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Canvas and light captured at both sizes; both contact sheets inspected, including Systems and visible Canon/Draft footers. Evidence: `docs/verification/audit-B5`.

### Audit B6 — completed

Centralized display-only Factions → Systems naming across Library, editor category menus, palette, reference picker/groups, Graph and other record labels; saved categories are untouched. ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Library/editor/graph-selected/palette captured at both sizes and inspected. README updated with the current repairs. Evidence: `docs/verification/audit-B6`.

### Audit B3 — completed

Timeline now enables Event in empty worlds and offers a new source-document option. The required source constraint is preserved: draft record and event save in one transaction, with rollback tested. Saving reloads shared records immediately. Final ./scripts/check.sh passed: lint, 81 tests / 17 suites, optimized build. A prior build rejected a concurrent copy edit; rerun completed on final sources. Empty-timeline/timeline captured at both sizes and both contact sheets inspected. Evidence: `docs/verification/audit-B3`.

### Audit B7 — completed

Editor and world Markdown export share a per-record writer with metadata, rules and native rich-text conversion (headings, bold/italic, underline, links). Single entity exports embed active sections with local anchors; filenames share a sanitizer and Untitled fallback. ./scripts/check.sh passed: lint, 83 tests / 18 suites, optimized build. Regression tests cover untitled/slash names, section contents and both rich-text export paths. Editor/sections captured at both sizes and inspected. Native save-panel interaction was not exercised. Evidence: `docs/verification/audit-B7`.

### Audit B8 — completed

Added saved world summaries, optional cover headers, current-world marking and an editable description in Settings. Added world-isolation, active-count and description-persistence tests. ./scripts/check.sh passed (84 tests in 19 suites, strict lint and optimized development build). Captured worlds/settings at 1440x900 and 1024x768 and inspected both contact sheets; cards use actual data and wrap cleanly. Native file dialogs were not exercised. Evidence: `docs/verification/audit-B8`.

### Audit B9 — completed

Restricted the entity Rules group to Power systems, Cosmology, Systems/Factions or records with existing rules. Added a shared labeled multiline field with a placeholder and accessibility label. The rule capture now opens an actual power system. ./scripts/check.sh passed (84 tests / 19 suites, lint and optimized build). Inspected sheet-rule/editor at both sizes: the character has no Rules group and the power-system rule field is labeled. Sheet captures remain inline pending D2. Evidence: `docs/verification/audit-B9`.

### Audit C4 — completed

Added a breadcrumb component that reads WorkspaceBar compact mode at the correct environment level. Compact headers keep only the back chevron, prioritized title and a save-status dot with tooltip. ./scripts/check.sh passed (84 tests / 19 suites, strict lint and optimized build). Captured sections-companion/editor at 1024x768 and inspected the contact sheet: Mira Vale is readable in both, including beside the open companion. Evidence: `docs/verification/audit-C4`.

### Audit C5 — completed

Extracted reusable SegmentedSwitch and used it for assistance and labeled Light/Dark appearance, retaining persisted theme changes. This world now orders Name, Description, Cover, Import, Export; four export formats share one row with format-specific help. ./scripts/check.sh passed (84 tests / 19 suites, lint and optimized build). Inspected settings/sheet-settings captures at both sizes. Desktop shows the full reordered group; smaller and sheet layouts scroll. Real modal and save-dialog interaction not exercised. Evidence: `docs/verification/audit-C5`.

### Audit D1 — completed

Renamed empty-sections to sections-empty and selected Oren Ashe in the sample world with Sections explicitly open. ./scripts/check.sh passed (84 tests / 19 suites, strict lint and optimized build). Captured both sizes and inspected the contact sheets: Oren Ashe shows Sections 0 and Make room for the details, rather than an empty Library. Evidence: `docs/verification/audit-D1`.

### Audit D2 — completed

Opaque inline panels now have a shared theme surface, hairline and shadow. Fixed WebKit screenshot compositing to respect actual sheet bounds and dim the canvas behind the scrim. Final ./scripts/check.sh passed (84 tests / 19 suites, lint and optimized build); first compile used the wrong Theme initializer and was corrected. All eight sheet states captured at both sizes and both final contact sheets inspected; artwork no longer bleeds through the picker. Added a real New record modal/Escape self-test, including an attached-sheet snapshot. That foreground step was compiled but deliberately not run, preserving the owner background-testing preference; native modal interaction remains unverified. Evidence: `docs/verification/audit-D2`.

### Audit B10 — completed

Kept Review badge scoped to pending proposals plus canon decisions and added a pluralized breakdown tooltip on its navigation row. Checks now uses a muted count even when selected. ./scripts/check.sh passed (84 tests / 19 suites, strict lint and optimized build). Captured review/review-checks at both sizes and inspected both contact sheets. Hover tooltip wiring was inspected in source; no live pointer tooltip check was run. Evidence: `docs/verification/audit-B10`.

### Audit B11 — completed

Replaced the three vendor-specific illustration labels with Sample illustrations and the requested bundled AI-generated artwork/canon disclosure. Updated matching README wording. ./scripts/check.sh passed (84 tests / 19 suites, strict lint and optimized build). Captured empty-atlas/sheet-artwork at both sizes and inspected both contact sheets; labels fit and the image picker remains opaque over Canvas. Evidence: `docs/verification/audit-B11`.

### Audit C6 — completed

Onboarding retains world name, assistance mode, labeled appearance and provider/sign-in choices. Added the Assistant heading, removed model editing and the image-generation note from onboarding, and kept them in Settings. Assistance/appearance reuse the shared segmented controls. ./scripts/check.sh passed (84 tests / 19 suites, strict lint and optimized build). Captured onboarding plus Settings at both sizes and inspected both contact sheets; onboarding fits at 1024x768 and advanced fields remain in Settings. Evidence: `docs/verification/audit-C6`.

### Audit C7 — completed

Added a shared 16 pt bottom fade driven by measured content/viewport bounds, disappearing when no content remains below. Sidebar footer uses a full-width one-pixel theme hairline. ./scripts/check.sh passed (84 tests / 19 suites, strict lint and optimized development build). Captured conversation/library at 1024x768 and 1440x900 and inspected both contact sheets; compact navigation stays scrollable and the footer separator is consistent. No foreground scroll gesture was exercised. Evidence: `docs/verification/audit-C7`.

### Settings iteration — preference foundation

Added 12 typed device preferences and two world creation defaults, connected to native editor/composer/navigation/Library behavior. World defaults round-trip in v4 archives; older imports remain supported. Added seven tests for restart persistence, normalization, world isolation, export privacy/import rollback, atomic identity changes, launch defaults and native key behavior. Fixed a Swift throwing-coalescence compile error, then `./scripts/check.sh` passed (91 tests / 21 suites, lint, optimized build). Inspected editor/Library background contact sheet at 1440×900. Replacement Settings controls follow in the next stage. Evidence: `verification/settings-foundation`.

### Settings iteration — searchable workspace and connected controls

Replaced the long nested form with General, Writing, Assistant, This world and Data sections. Search uses the rendered control inventory and useful aliases; model/privacy searches reveal connection details. Compact windows use a section menu. Added shared preference rows/menus, a writing preview, custom entity types, atomic world identity save, separate explained exports and explicit sign-in checks. Chat setup links now open Assistant settings; onboarding shares its provider control. Removed the old Settings modal, `sheet-settings` fixture, duplicated provider cards, dead local state, unused secure-field branch and a redundant Library title wrapper. Corrected stale setup documentation that recommended Claude by default.

Added three tests for actual NSTextView settings/RTF preservation, settings search and provider/settings behavior in Manual. Corrected compile errors in the view closure annotation and native-editor test initializer, then final `./scripts/check.sh` passed: strict lint, **94 tests / 21 suites**, optimized development build. Initial 26 captures informed cleanup of the obsolete modal and excessive top spacing. Final `verify-ui.sh` runs produced **40 captures**, all inspected in contact sheets: 17 states at each of 1440×900 and 1024×768; six at 720×800. Changed-preference captures show 20 pt writing, a narrower column, hidden word counts, compact Library rows and hidden category counts/recent chats. Evidence: `verification/settings-refinement`.

No foreground automation, native file-dialog walkthrough, live provider calls or paid generation ran. C2/C3 remain unapproved; A2's prior native capture blocker is not resolved by this work. AGENTS.md unchanged. The owner's untracked design brief remains untouched and excluded. Next: focused keyboard/accessibility and preference interaction coverage, then editor recovery and the remaining connected-workspace audit.

### README app screenshots

Added a current Canvas hero and expandable gallery for Conversation, editor, Graph, Atlas and Settings. Captured all six from the native app at `0148d8a` with isolated sample data at 1440×900; inspected the contact sheet. Original 2× PNGs, provenance, refresh command and capture log are in `docs/screenshots`. Verified README image paths, alternative text and PNG dimensions; `git diff --check` passed. The capture command rebuilt the optimized temporary app successfully. Documentation/assets only: native tests were not rerun, and no browser, foreground interaction or model call was claimed.

## 2026-11-16 — connected conversation, Canvas and Graph

Rebuilt the shared composer hierarchy and theme-aware menus; connected native loading/tool rows to real core activity. Imported Kokonut ai-loading through the requested shadcn command in an isolated staging project, then adapted the interaction to SwiftUI (MIT attribution retained). No React chat runtime or fabricated tool playback.

Bundled Dagre for both native Graph and explicit Canvas Arrange. Removed the old force layout. Tests exposed missing JavaScriptCore structuredClone support; the fixed-script bridge now supplies JSON-safe cloning and a directed-chain test distinguishes Dagre from fallback. Real entity cards, port actions and readable edges replace abstract Graph circles. Inspection exposed clipped fitting and incorrect PNG image inversion; both were repaired. Custom Canvas PNG export preserves artwork colours and actual card content, with world/session guards.

Checks: strict lint, 102 native tests in 23 suites, optimized build; Canvas typecheck, 9 Node tests, bundle build; 22 background WebKit audit checks. Captured and inspected 28 native states at two sizes and the real PNG. Final fitting captures rerun without the audit's viewport mutations. No foreground tests, provider calls or user-data edits. Evidence: `verification/connected-presentation`. User's untracked `docs/DESIGN_AGENT_BRIEF.md` preserved.

### Creative components — 2026-11-16

Added a closed native presentation vocabulary over ordinary lore: Notes, Facts, Checklist and Progression, scoped to seven workspaces or an entity. Entity components share section membership. Search, revisions, references, Canvas placement and export use the same underlying record. `create_component` proposals validate kind/scope/parent and require review; invalid or cross-world parents cannot create content. Checklist changes are stale-checked draft revisions that preserve canon. Archived component presentation retains content, with Restore/Undo.

Migration 0009, archive v5 with v1–v4 compatibility, JSON schema 8. 106 tests / 24 suites, strict lint and optimized build passed. Twelve native captures cover both sizes, themes, Manual, empty, creation and entity layouts. Fixed unstable same-second creation order and excessive empty-panel height after inspection. No foreground self-test, external provider or paid usage. Evidence: `verification/creative-components`.

### Mechanics — 2026-11-16

Added the Mechanics entity tab with grouped rules, kind filters, scenarios and creator conclusions, structural considerations, explicit rule canon review and restorable history. Migration 0010 snapshots rules transactionally and preserves earlier accepted wording. Portable format v6 / JSON schema 9 retain history; older archives remain importable. Reviewed `revise_rule` changes capture their exact before-state; `add_scenario` cannot write the creator's verdict. Form choices now share the themed app menu.

Acceptance tests exposed a rule-ID/document-ID mismatch in generic proposal validation; fixed it and verified successful acceptance remains a draft with prior canon intact. Also aligned proposed-rule length with core limits and rejected proposed non-entity parents. Final `./scripts/check.sh` passed strict lint, **109 tests / 25 suites**, optimized build. Inspected **14 native captures** at two sizes, covering dark/light/Manual, empty, scenario, history and canon review. Evidence: `verification/mechanics`. No foreground interactions or model usage. Consolidated stale STATE/README/architecture claims; AGENTS.md unchanged.

### Named and linked Atlas maps — 2026-11-16

Added map selection, naming, place ownership, parent/child navigation, record-to-map links, click-to-move markers, guarded archive/Undo and conflict recovery. Saves now preserve map names and compare exact prior content; Undo captures world/map identity rather than the currently open map. Active Atlas context reaches the assistant, and `create_map` is a reviewed proposal for an empty map with optional links. No image generation or inferred geometry.

Core validation rejects cross-world metadata, cyclic ancestry, duplicate/out-of-bounds markers and stale writes. Portable imports validate embedded Atlas links inside their transaction, including archived map ancestry. Fixed a shared menu-style visibility compile error. Final `./scripts/check.sh` passed: strict lint, **113 tests / 26 suites**, optimized development build. Inspected **14 native captures** at both sizes: dark/light/Manual, details, creation, local and empty states. The final core-only import validation was tested after these captures; it does not change UI rendering. Evidence: `verification/atlas-maps`. README Atlas image refreshed. No foreground input tests, live provider calls or paid generation; user's running app remains untouched.

## 2026-11-16 — owner-directed sidebar refinement

Baseline `3d0d12e`, canonical `main`. Preserved the owner's untracked design brief and all Studio actions. The actual source width was 248pt; normalized to the owner's requested 312pt target with a 72pt compact rail. Native window controls remain native. No route/schema changes, generated content, provider calls or releases.

Implemented shared `SidebarPalette`, `SidebarMetric`, focus/hover/press styling and explicitly themed native vibrancy. Top identity/actions and bottom utilities surround one scrolling middle. World artwork is retained at 40pt; names truncate with one dropdown chevron. New Chat/Search match; category icons are neutral; ordinary counts and Review attention counts are distinct. History reserves its action slot, preventing hover from moving titles. Both sections retain disclosure behavior and all conversation context actions. The rail now exposes Search and appearance too. Removed the obsolete sidebar body from Shell and the unused AppearanceButton; navigation composition lives in Sidebar.swift.

Verification: `./scripts/check.sh` passed strict lint, **115 tests / 27 suites**, and the optimized ad-hoc build. The added tests preserve world content/settings across restart and protect unsaved editors through every destination. Native menu checks validate Search, New Conversation and collapse/expand bindings and dispatch their real actions while the app stays inactive. No foreground keyboard, pointer, VoiceOver or popover interaction coverage is claimed: the non-key SwiftUI accessibility tree was not exposed to the attempted in-process audit, so that unused audit code was discarded.

Visual passes corrected duplicate history selection fills, light metadata contrast, and a stale animation frame in occluded screenshots. Static captures now disable animations; normal app transitions still run at 150ms and respect Reduce Motion. Stress data is isolated: a long world name, 1,024 persisted entity records and eight saved conversations. Current evidence and reproduction commands live in `docs/verification/sidebar` and `docs/SIDEBAR.md`. AGENTS.md and unapproved C2/C3 proposals remain unchanged.

Final visual evidence: 22 dark/light/rail/empty/long-name/history/folded/opaque captures at 1440×900 and 1024×640, plus three 1024×520 minimum-height captures, inspected in all three contact sheets. Twelve screenshot pixel assertions passed. Seven additional native workspace captures were inspected and copied to README; same-viewport baseline sheets and a full-resolution before/after crop are retained. Final checks after the capture-transaction fix again passed 115 tests / 27 suites, lint and optimized build. No source changes followed those checks.

## 2026-11-16 — 0.0.1 connected interaction checkpoint

Narrowed sidebar to 284pt, cleared transient hover state and refined composer/companion transitions. Unified graph zoom around a stable anchor, removed selection-induced resize/refit, made overview labels readable and removed the obsolete docked inspector branch. Stored Canvas links and labels are record-owned; label inspection retains editing and explicit board hiding.

Fixed nested chronology proposal dependencies and atomic draft sources for newly accepted events. Added history hierarchy and review parent/source disclosure. Accepted Atlas changes select their affected map and publish shared refresh. Every request snapshots current workspace; Codex memories/host skills are explicitly disabled and harness environment variables are allowlisted. No extra calls on navigation or autonomous canon writes.

Verified final `./scripts/check.sh` (strict lint, 120 tests/27 suites, optimized build); Canvas typecheck, 9 Node tests and bundle build; 44 actual background captures plus exported PNG inspected; 24 engine audits in the extracted distribution ZIP; four sidebar pixel checks. Regression run caught and repaired missing-source acceptance. No foreground/VoiceOver/live-provider walkthrough; no owner's database access or app restart.

Owner explicitly authorized the 0.0.1 development prerelease. AGENTS changes only that former no-release restriction. Added release packaging, checksum, installation limitations and notes; refreshed eight README screenshots. Untracked DESIGN_AGENT_BRIEF remains untouched. Next: isolated physical gesture/animation verification, opt-in live harness validation, signing/notarization and deeper spatial tools before broader release.

Published v0.0.1 from 88a6c2eef805afa1ae4506596450bc2e78e5b1c6 after all checks above. GitHub confirms prerelease=true, draft=false and three uploaded assets; ZIP digest matches local SHA256SUMS. Release: https://github.com/desenyon/synthesis/releases/tag/v0.0.1. The initial GitHub request rejected an abbreviated target SHA; retry with the full commit ID succeeded. Subsequent documentation-only confirmation does not change the tested release binary.

## 2026-11-16 — Atlas follow-up on main

Audited the repeated interaction request against the published implementation and inspected the supplied Aeronia map as private reference. Reproduced Atlas button zoom drift (a centred landmark moved 50pt after zooming a panned map). Reused one bounded focal transform for Graph/Atlas, added invalid-coordinate guards and retained the decoded map image outside the pan/zoom render path. Preserved the accepted sidebar and all saved world content. Removed the obsolete Graph-only helper name and stale roadmap no-release statement.

`./scripts/check.sh` passed strict lint, 124 tests / 27 suites and optimized build; 10 focused geometry/marker-approval tests passed. The invalid-coordinate regression failed as expected before the fix. The marker test exercises actual Studio approval on a different map and then the active map, preserving artwork, source lore and other maps. Twelve actual background captures inspected in both contact sheets (1440×900 and 1024×768): Atlas dark/light/Manual, empty child map, Graph dark/light. [Evidence](verification/atlas-followup). README, architecture, Atlas guide, release decision and current state updated. AGENTS.md and the owner's untracked brief unchanged.

No live provider usage, foreground gesture/animation testing, user's data writes or app restart. The 0.0.1 prerelease remains immutable; these are subsequent main/local-build fixes, not a replacement release archive. Next: isolated physical trackpad/animation validation and opt-in subscription integration coverage.


## 2026-11-16 — full interaction follow-up, 0.0.2 preparation

Rechecked the entire latest request, then iterated through recovery/context, workspace revision, visual and regression passes. Added Stop/partial response preservation, retry draft protection, active selection/branch context, searchable lore picker, reading-position-aware transcript and floating/resizable companions. Added explicit reviewed event/lane/map/relation edits with before-state checks; manual nested history editing/folding and All history refresh; relation-only Review refresh.

Fixed close/parallel curves and route labels, added basic obstacle detours, and preserved graph viewport through relationship refresh. The actual Canvas capture exposed an additional viewport reset after repeated load/approval despite passing coordinate checks; committed React state before native acknowledgement and added three viewport assertions. Compact companion capture/hit testing excludes the hidden engine. Removed obsolete reference grouping and duplicate companion-width loading.

Final checks: strict lint, **139 native tests/30 suites**, optimized build; Canvas typecheck/**11 tests**/bundle build; **27 native/WebKit checks** and **48 background captures**, both contact sheets inspected. One explicitly approved isolated Codex request passed (9.312s), cited real fixture lore and staged two changes without applying them. No additional subscription calls. Regression failures were repaired, including interrupted response loss, coincident parallel curves, absent workspace editing and final test-macro/tuple typing errors. Evidence: verification/interaction-0.0.2.

Updated README/screenshots, state, architecture, decisions, roadmap and completion ledger. AGENTS adds one evidence-backed viewport-readiness rule; no protected change. Owner brief and live worlds untouched. No foreground automation, physical gesture/VoiceOver result or animation-frame-rate claim. Distribution remains Apple Silicon/ad-hoc signed, not notarized. Preparing a separate 0.0.2 prerelease, preserving 0.0.1.


### 0.0.2 final artifact pass

The first implementation checkpoint was committed/pushed as `2bbff4b`. A new failing engine assertion then exposed first-fit acknowledgement preceding its viewport commit; repaired and rebuilt the bundled engine. Final isolation audit removed shared macOS provider/model defaults in favor of per-Studio state; added a two-instance regression. Owner preferences already matched the saved database settings and were not changed.

Final `./scripts/check.sh`: **140 native tests / 30 suites**, strict lint and optimized build passed. Canvas typecheck, **11 Node tests**, bundle build passed. Packaged and extracted the final Apple Silicon ZIP; strict code signature verification and executable comparison passed. Its real native run passed **28 engine checks** and produced **16 captures** at 1440×900 and 1024×768; inspected both package contact sheets. This supplements the earlier 48 source captures. Exactly one approved live Codex request remains the total. Release publication follows the checked source commit; 0.0.1 stays immutable.

Published [v0.0.2](https://github.com/desenyon/synthesis/releases/tag/v0.0.2) as a non-draft prerelease from `2b792637553ed6d940b0f9d5d4540a6b2b7694a8`. Verified the remote tag, all three uploaded assets and GitHub’s matching ZIP digest `c86f0c3eba8046612d1f3441b22d2aa065b6bddc1bb74bb4e35a440c172e4a89`. The v0.0.1 tag remains unchanged. Final documentation confirmation is a separate commit; owner brief remains untracked and the running app was not interrupted.

## 2026-11-16 — completion pass (no release)

Owner instruction: complete remaining tasks, no new release, launch the app for review. Plan, one verified commit per slice:

1. Extended local checks: contradictory relationships, timeline ordering, tag spellings with reversible merge.
2. Crash recovery for unsaved editor text.
3. `.synthesis` file association (double-click opens import).
4. Large-world performance measurements (search, graph layout, checks).
5. What-if branches: fork a world as a hypothetical branch, then propose its changes back through review.
6. Technique trees in Mechanics (prerequisite graph).
7. Atlas regions: editable polygon areas linked to places.
8. Timeline zoom/density and era navigation.
9. A2 live check, accessibility label audit, app launch for owner review.

C2 (lift the black palette) contradicts the owner's recorded black-studio direction and stays unapproved; C3's pill was superseded by the owner's composer rebuild. Subscription image generation requires a live, billed request and a verified Codex output contract; it is investigated, not assumed.

### Slice 1 — extended consistency checks (verified)

Review → Checks now flags the same relationship recorded twice, a one-way label used in both directions (symmetric labels such as "allied with" are exempt), Timeline order that contradicts comparable dates in the same era, and tag spellings that differ only by case, punctuation or a plural "s". "Merge tags" rewrites spellings in one transaction as new metadata revisions (canon untouched) with Undo. Registered missing Phosphor glyphs; the first capture showed fallback circles, the recapture shows the right icons. Checks: 3 new tests failed-first-free; `./scripts/check.sh` passed with **143 tests / 31 suites**; `review-checks` captured at 1440×900 and 1024×768 and inspected.

### Slice 2 — crash recovery for unsaved editor text (verified)

Migration 0011 adds a device-local `editor_journal`. The editor writes a recovery copy 200 ms after typing stops, immediately when a save fails and when the editor closes dirty; a successful save clears it. Reopening the page shows "Unsaved text was recovered" with Restore (loads the text and saves a new revision; history keeps the earlier one, canon is untouched) or Discard (with Undo). On launch a toast points to recovered pages. The journal is world-scoped, dropped when it matches saved text, and excluded from JSON and `.synthesis` exports. Checks: 2 new tests (restart round trip, world scope and export exclusion); `./scripts/check.sh` passed with **145 tests / 32 suites**; `editor-recovered` captured at both sizes. The first 1024 capture squeezed the banner text beside its buttons; buttons now sit under the message and the recapture was inspected.

### Slice 3 — `.synthesis` file association (verified)

The bundle exports `dev.desenyon.synthesis.world` for `.synthesis` and claims it as owner. Double-clicking a world file, dropping it on the Dock icon or using Open With asks "Open … as a new world?" and then runs the existing transactional import into an independent copy; files opened during launch wait until the studio exists. The Open panel now only offers world files. Checks: `./scripts/check.sh` passed (145 tests); `plutil -lint` passed; after `lsregister -f`, `UTType(filenameExtension: "synthesis")` resolves to the new type and `NSWorkspace` names `dist/Synthesis.app` as its handler. The Finder double-click itself was not performed, to avoid interrupting the running app.

### Slice 4 — large-world performance measurements (verified)

Added `ScaleTests` (2,000 records, 1,500 relationships, 300 events), `GraphScaleTests` (Dagre at 100 and 300 entities, plus a chain test proving Dagre rather than the grid fallback ran) and a Canvas routing benchmark (600 connections over 300 cards). Results are in [PERFORMANCE](PERFORMANCE.md): checks 94 ms, 20 searches 22 ms, 300-entity layout 127 ms, routing 8 ms. The first run failed because the generator created duplicate relationships the schema forbids; the fixture now uses unique pairs. Checks: `./scripts/check.sh` passed with **147 tests / 34 suites** (first run caught one over-long line, fixed); Canvas `npm test` **12 tests** and typecheck passed. WebKit rendering of a dense board was not measured.

### Slice 5 — what-if branches (verified)

"New what-if from …" (world menu and Worlds card) copies the open world through the existing transactional archive import into an independent world labelled "What-if of …". Migration 0012 records the original of every copied record (ID, version, title, body, category) and which relationships/events existed at branch time. "Send changes to …" previews every difference: rewrites, new records, new relationships and events are sent as **one pending proposal in the original's Review** (origin `branch-merge`, shown as "Changes from a what-if"); text edited in both worlds since branching, records archived in either world, and title/category-only edits are listed but not sent. Accepting creates drafts (new records marked Imported); canon in the original is untouched until its own review. Nothing in the original changes when a what-if is created or edited. The merge reuses `stageProposal` validation with a raised limit for creator-owned merges; model proposals keep the 12-change cap.

Checks: 3 new tests (isolation and canon preservation, clean/conflict split with dependency order and acceptance, empty/non-branch refusal); the first run failed on an over-strict order assertion (records list newest first) and now checks the create-before-relate dependency instead. `./scripts/check.sh` passed with **150 tests / 35 suites**. Captured `what-if-new`, `what-if-send`, `review-what-if`, `worlds-what-if` at 1440×900 and 1024×768; both contact sheets inspected. Not built: three-way text merge, deleting what-ifs (worlds have no archive yet) and merging what-ifs of what-ifs back more than one level.

### Slice 6 — technique trees (verified)

Migration 0013 `rule_prerequisites` (archive on removal, unique, no self-edges). `setPrerequisites` keeps requirements inside one system and refuses loops; `saveRule` saves wording and requirements in one transaction so a refused loop rolls back the rename too. The rule editor shows "Requires first" for techniques and progression steps; Mechanics draws a Dagre tree (above the cards under the Techniques/Progression filter, below them under All) and opens a node's editor on click. `GraphLayout` now takes node size and spacing; Graph keeps its defaults. `.synthesis` v7 (imports v1–v6) and JSON schema 10 carry the edges.

Checks: 2 new tests (loops, foreign systems, archive/restore of edges, archived rule, atomic save, portable copy with remapped IDs); the existing schema assertion moved to 10. `./scripts/check.sh` passed with **152 tests / 36 suites**. Captures `mechanics`, `mechanics-tree`, `mechanics-requires`, `graph` at both sizes: the first tree capture put the tree below the fold and the second showed 270 pt gaps from Graph-sized Dagre nodes; both fixed and recaptured.

### Slice 7 — Atlas regions (verified)

Maps can hold up to 500 regions, each 3–200 normalised points linked to a record of the same world (validated in core, including on portable import; older maps decode with no regions). Draw mode, selection with draggable vertex handles, context-menu redraw/remove, marker/region layer switches and Undo through the version-checked map save. `mapsForRecord` also finds maps where a record only has a region. Checks: new `AtlasRegionTests` (valid save, too few points, out-of-range and boolean coordinates, foreign record, portable copy); `./scripts/check.sh` passed with **153 tests / 37 suites**. Captures `atlas`, `atlas-regions`, `atlas-drawing`, `atlas-linked`, `light-atlas-linked`: the first pass showed the record name twice (marker plus region label) and a faint outline in light mode; the label now yields to a marker and a pale under-stroke was added, both recaptured. A first build failed on a CGFloat/Double conversion, fixed. Physical drag of vertex handles was not exercised in the foreground.

### Slice 8 — Timeline zoom and era navigation (verified)

Timeline has three zoom levels in its header: **Detailed** (the existing cards), **Compact** (one line per event with its period and source) and **By era** (events grouped under each top-level period or branch, then "Not in a period", with collapsible sections and jump chips that scroll to an era). The choice is stored in this installation's database, not shared macOS defaults, so background verification cannot change the running app. Era grouping follows each event's placement up to its top-level lane; nothing is reordered or rewritten. Checks: `./scripts/check.sh` passed (153 tests / 37 suites, unchanged count: presentation only); `timeline`, `timeline-compact`, `timeline-overview` captured at both sizes and inspected. The first capture run failed because the formatter had reflowed the capture list my edit targeted; corrected. Dragging events to reorder remains open.

### Slice 9 — Timeline reordering (verified)

Every event menu (Detailed, Compact and By era) has **Move earlier** / **Move later**, with Undo. The first move numbers all active events 1…n in their current order so unordered events gain a stable place; Undo restores the exact previous order, including "no order". Review's new timeline-order check uses this order. Checks: new `EventOrderTests`; `./scripts/check.sh` passed with **154 tests / 38 suites**. The change adds menu items only, which background captures cannot open; drag-to-reorder is not built.

### Slice 10 — explicit Codex image generation (implemented; live run pending approval)

The installed Codex 0.169 lists `image_generation` as stable, and its own tool instructions state that `image_gen` writes to `$CODEX_HOME/generated_images`. `CodexImageGenerator` runs only from **Generate image** in the illustration library (Canvas and Atlas): sign-in check, empty scratch folder, read-only sandbox, shell/apps/plugins/browser/memories disabled, `image_generation` enabled for this request only, description-only prompt treated as data. It imports the newest PNG/JPEG/WebP written during the request (header-checked, ≤ 12 MB) and ignores older files. Chat still passes `--disable image_generation`. Manual mode refuses; injected transports (tests, background capture) get a generator with no executable.

Checks: 3 stand-in tests (arguments, prompt, environment allowlist and CODEX_HOME, old files ignored, missing/non-image output refused, chat flag unchanged); `./scripts/check.sh` passed with **157 tests / 39 suites**. `sheet-generate` and `sheet-artwork` captured at both sizes: the first 1024 capture overflowed the sheet, so the preview and description field were made compact and recaptured. **No live image request was made**: it spends subscription allowance and needs the owner's go-ahead.

### Slice 11 — live window verification and two fixes (verified)

`./scripts/selftest-ui.sh` (real pointer and key events, foreground for a few seconds) passed **19/19**, including the New record sheet presented as a true modal and dismissed with Escape, closing D2's remaining gap. Audit A2 is now live-verified in an isolated instance (see `verification/audit-A2-live`). The live run exposed two bugs, both fixed: Return in the welcome sheet's name field did nothing, and the command palette put "Capture … as an idea" above matching commands, so "light appearance" + Return created an idea instead of switching theme. New `CommandPaletteRankingTests`; `./scripts/check.sh` passed with **158 tests / 40 suites**; the repeated live run switched theme and created no record.

### Accessibility sweep (verified, limited)

An Accessibility-tree script walked an isolated instance with the sample world across all nine workspaces (⌘1–⌘9) and an open record with its inspector: 33–69 interactive controls per screen, none without a title, description, help or value apart from the system minimise/zoom buttons. This checks labels, not VoiceOver reading order or usability; a VoiceOver walkthrough remains open. Canvas's WebKit content was not traversed in depth.

## 2026-11-16 — repository organisation and release 0.0.3

Owner request: full releases for 0.0.1–0.0.3, an organised and professional repository, fresh README screenshots, updated handoff/prompt docs and changelog, better description. Done: GPL-3.0 (owner's choice), community files and templates, CI and Dependabot, docs index and archive, README rewrite with eleven fresh captures (inspected in a contact sheet), stale root `migrations/`, old `RUN_PROMPT.md` and `.env.example` text retired or rewritten. `./scripts/check.sh` passed (158 tests / 40 suites); CI passed on GitHub (both jobs). v0.0.3 published from `cc4ff85` with a verified digest; v0.0.1 and v0.0.2 converted to full releases. Not possible through the API: the repository's social preview image (set it in GitHub → Settings → General if wanted).

## 2026-11-16 — World assistant composer and context (unreleased)

Owner supplied an expansion brief and composer reference. Implemented a bounded connected slice in the actual native app: shared expandable composer, real removable record/board/map/history attachments, local source/index inspection, per-world scope/exclusions, selection/history controls and Explore/Propose. The core enforces Explore even when a test model emits a proposal. Restricted requests omit previous messages and exclude associated index data; no canon boundary or subscription isolation was relaxed.

Regression iteration caught and fixed index limits dropping older attached boards, archiving exclusions silently enabling history again, false placement totals after truncation, invalid preferences broadening access, and selected/attached entities losing section/neighbor retrieval. Screenshot review found fallback icons, a disabled checkbox showing the wrong effective history state, and a disappearing composer overwriting a newer draft. Each was corrected; stale composer/debounce writes now compare against the shared draft they last observed.

Checks: `./scripts/check.sh` passed **174 tests / 41 suites**, strict lint and optimized build. **32 final native captures** at 1440×900 and 1024×768 inspected in two contact sheets; same-viewport Conversation before/after inspected. README includes new composer/context screenshots and refreshed Conversation; current state, architecture, roadmap, handoff, run prompt and Unreleased changelog updated. Evidence: [composer-context](verification/composer-context/README.md). No release, new live model call, foreground self-test or restart of the owner's app. No AGENTS change; owner brief untouched. The broad expansion remains planned, with typed facts/provenance and temporal projections next.

## 2026-11-17 — shared chatbox refinement (unreleased)

Applied the existing app's quieter typography, surfaces and control geometry to the shared Conversation/companion/compact composer. Typed text and placeholder use bundled Inter at 16pt. A single adaptive 32pt toolbar groups attachment, preset and intent controls, with context inspection and Send/Stop at the other end. Reference chips wrap, action feedback is restrained, and the footer carries canon/provider information plus the actual saved send shortcut. Focus, expansion and control transitions respect Reduce Motion; ordinary text growth stays immediate. Sidebar and navigation preserved.

Visual iteration exposed a third attachment clipped in narrow companions and a stale native scroll offset hiding the first line of multiline drafts. Both were corrected and recaptured. The new layout regression was observed failing before the fix and passing afterward; it protects the caret, text and intentional scrolling of longer drafts. No changes to context permissions, draft guards, subscription isolation or canon approval.

`./scripts/check.sh` passed **175 tests / 42 suites**, strict Swift format lint and optimized native build. **40 final states** at 1440×900 and 1024×768 inspected in two contact sheets, including six focused recaptures after the wrapping fix; same-size before/after inspected. README screenshots, composer guide, state, roadmap, handoff, run prompt and changelog updated. [Evidence](verification/composer-polish/README.md).

Launched the rebuilt canonical `dist/Synthesis.app`, opened Conversation and inspected its running window for owner review; left it open without entering a draft or sending a request. Background tests do not establish foreground typing, native popover interactions, animation pacing or VoiceOver. No live provider usage, release, dependency, migration or AGENTS change. Owner brief untouched.

## 2026-11-17 — complete expansion ledger and #1

The owner clarified that all 394 numbered requirements must be implemented individually; the composer was only a slice. Preserved the exact attached source in EXPANSION_SOURCE and created EXPANSION with every original requirement and explicit status/evidence. Unnumbered modules/composer/workflow acceptance is retained too. No unaudited requirement is marked complete.

#1: graphite dark surfaces plus a persistent optional OLED palette, including real Canvas rendering and export. Native checks passed 175 tests / 42 suites, strict lint and optimized build; Canvas typecheck, 13 tests and bundle build passed. Inspected 14 native captures at two sizes. A Settings search description regression was fixed before the passing rerun. [Evidence](verification/expansion-001/README.md). No live calls, release or foreground interruption. Continue #2 in order.

### Expansion #2 — frosted floating surfaces (verified, 2026-11-17)

Shared native in-window vibrancy for floating toolbars, inspectors, popovers and every composer variant. Reduce Transparency and Increase Contrast use opaque fallbacks; nonfloating content remains opaque. Menus inherit the actual graphite/OLED/light theme. Canvas now ignores unrelated preference changes instead of repainting its theme. `./scripts/check.sh`: 175 tests / 42 suites, strict lint and optimized build passed. 16 background captures across two sizes inspected, including opaque, selected Graph, composer context and light variants. No foreground input or model call. [Evidence](verification/expansion-002/README.md). Next #3; the rest of the brief is not complete.

### Expansion #3 — design tokens (verified, 2026-11-17)

Added semantic typography roles over bundled Inter and shared spacing/elevation roles; common page geometry, radii, controls, captions and card headings now resolve through the same definitions. Updated stale UI_DIRECTION values to the actual source. `./scripts/check.sh`: 175 tests / 42 suites, strict lint and optimized build passed. 16 captures inspected across two sizes: editor, Library, Settings, Worlds, Graph, Canvas, and light editor/Library. This is a presentation refactor; saved rich text and layout behavior remain intact. [Evidence](verification/expansion-003/README.md).

### Expansion #4 — entity typography hierarchy (verified, 2026-11-17)

32pt entity-title role, shared identity heading on Sections and Mechanics, quieter section controls and metadata. The editor retains an editable wrapping title; Settings adopts the shared page-title role. `./scripts/check.sh`: 175 tests / 42 suites, lint and optimized build passed. 16 native captures inspected, including long editable titles at 1024×768 and dark/light Overview, Sections and Mechanics. No data schema or authored rich-text change. [Evidence](verification/expansion-004/README.md).

### Expansion #5 — semantic category identity (verified, 2026-11-17)

Removed the divergent Canvas pastel map. Native and Canvas categories use matching colors and Phosphor glyphs; singular/imported visual aliases preserve original stored names. History receives a calendar and understated blue-gray identity. Light Canvas accent corrected to the native value. `./scripts/check.sh`: 175 tests / 42 suites, lint and optimized build. Canvas typecheck, rebuilt bundle, 14 tests including 4.5:1 category text contrast and alias checks. 14 native captures inspected across Canvas, Graph, Library and Timeline in dark/light at both sizes. [Evidence](verification/expansion-005/README.md).

### Expansion #6 — information density (verified, 2026-11-17)

Persisted Compact/Comfortable/Immersive option with shared density environment. Real row heights, thumbnail sizes, card minimum widths, card padding and content gaps adapt across navigation, Library, Worlds, Mechanics and Sections. Existing authored Canvas geometry and rich text remain intact. Disk-reopen and malformed-value preference coverage extended. `./scripts/check.sh`: 175 tests / 42 suites, lint and optimized build. 24 captures across two sizes inspected, including all modes, light extremes, Settings, narrow immersive cards and compact navigation. [Evidence](verification/expansion-006/README.md).

### Expansion #7 — intentional empty profiles (2026-11-17)

Optional writing prompts, artwork, actual relationship navigation and sourced-event creation replace the empty entity editor. Prompts never become lore automatically. Added entity artwork revisions (0014), validation, guarded Undo, v8 portable import/export, JSON11, embedded Markdown imagery and image-export collection. 179 tests / 43 suites, strict lint and optimized build passed; 16 background captures inspected after fixing an icon fallback and cross-state fixture text. No live provider call, foreground automation or AGENTS change. Evidence: verification/expansion-007. Next: #8, shared microinteractions.

### Expansion #8 — shared microinteractions (2026-11-17)

Restrained shared motion for selection, panels, companions, relationship navigation and proposal review; reduced-motion support; transient hover resets on navigation, disabled state and focus loss. Fixed the capture runner suppressing its toast fixture, then a real confirmation/composer overlap. 180 tests / 44 suites, lint and optimized build passed; 20 final captures inspected at both sizes. An unwindowed native regression covers hover lifecycle; physical animation pacing is not claimed. [Evidence](verification/expansion-008/README.md). No model usage or foreground interruption. Next #9.

### Expansion #9 — contextual tools (2026-11-17)

Audited workspace toolbars and fixed conflicting Atlas modes, missing marker Undo, empty marker pickers, stale Graph relationship form settings and ineffective Canvas drawing-style controls. 181 native tests / 45 suites, lint and optimized build; Canvas typecheck, 15 tests, bundle build and 28 embedded engine checks passed. 24 captures inspected at both sizes. [Evidence](verification/expansion-009/README.md). Next #10: optional contextual inspectors across workspaces.

## 2026-11-17 — expansion #10, contextual inspectors

Implemented the optional inspector for every workspace and extended the editor inspector to Mechanics. Read-only projections expose current stored properties and connected records, with explicit Open/Reference actions. A toolbar control and ⌥⌘I toggle visibility; compact windows float the inspector below the toolbar. Tests reject foreign/archived objects and preserve navigation, Manual mode and pending proposals. Canvas selection feeds the same inspector; dock sizing respects companion takeover.

`./scripts/check.sh`: 184 tests / 46 suites, strict lint and optimized build passed. Inspected all 32 initial captures and 8 refinement captures in contact sheets. Fixed a wrapped Conversations label and WKWebView bleed-through found in the first captures; recaptured both sizes. No foreground interaction, provider request, app restart, release or AGENTS edit. [Evidence](verification/expansion-010/README.md). Next: #11 reversible breadcrumbs/history.

## 2026-11-17 — expansion #11, breadcrumbs and navigation history

Added the reversible Mira → Tidekeepers → Glass Sea trail and common Back/Forward controls, context menus and native ⌘[ / ⌘] shortcuts. History covers records, maps, canvas boards, conversations and world switches, with 100-visit bounds. Failed saves preserve both stacks; replay resolves current lore, skips archives and rejects foreign IDs. Atlas restores a valid selected record. Tests also cover branching away after Back, duplicate visits, nested helpers and Manual mode.

`./scripts/check.sh`: 188 tests / 47 suites, strict lint and optimized build passed. Inspected 20 initial and 4 refined captures at 1440×900 and 1024×768. Corrected squeezed Atlas titles with contextual compact actions and inactive-window hover feedback exposed in the captures. The first capture invocation rejected unregistered fixture names; registered them and reran successfully. No foreground desktop events, model call, app restart, release or AGENTS edit. [Evidence](verification/expansion-011/README.md). Next: #12 saved layouts.

## 2026-11-17 — expansion #12, saved workspace layouts

Added named per-universe arrangements for workspaces, selected sources, panels, entity tabs, density and reading width. The manager supports explicit update, rename, archive/restore and guarded Undo; available from View (⌥⌘L), Settings and quick-open. Applying resolves current lore and keeps AI mode and unsent writing. Invalid saved data is preserved; foreign or missing targets and failed saves cannot replace the active view.

`./scripts/check.sh`: 192 tests / 48 suites, strict lint and optimized build passed. All 16 captures at 1440×900 and 1024×768 inspected in contact-sheet rows: populated/empty/long-list/archived managers, Manual, light and applied Writing layouts. README includes the actual layout manager. No foreground input, live model request, app restart, release or AGENTS edit. [Evidence](verification/expansion-012/README.md). Next: #13 dashboard from actual world data.

## 2026-11-17 — expansion #13, welcome dashboard

Added an optional Dashboard with recent entities, unfinished writing, pending proposals, project outlines and latest saved activity. Items open their real source, map, graph/history inspector or proposal review. Projects are revisioned entities with sections and links, preserved through restart and world export/import. No model request or canon change is triggered. Existing keyboard destination numbers remain stable. Settings can select Dashboard on startup.

`./scripts/check.sh`: strict lint, 196 tests / 50 suites and optimized build passed. Four tests cover isolation, archive filtering, actual approval status, project portability, source navigation, failed saves and Manual mode. The first desktop capture exposed unused space beside offscreen activity; moved activity alongside writing, then inspected all 20 final captures in both contact sheets at 1440×900 and 1024×768. README screenshot added. No foreground interaction, live model use, running-app restart, release or AGENTS edit. [Evidence](verification/expansion-013/README.md). Next: #14 light mode.

### 2026-11-17 — Expansion #14, light-mode separation (verified)

Canvas and Graph now use a cool spatial base beneath white entities and floating controls. Shared light secondary/border tokens are stronger; Canvas overlay colors come from the same palette as export and native surfaces. Removed stale green-tinted overlay text. Dark/OLED behavior and data are unchanged.

Checks: Canvas typecheck, 15 tests and bundle build; `./scripts/check.sh` strict lint, 196 tests / 50 suites and optimized build; 28 embedded-engine checks. Compared three before states with same-size after captures. Inspected all 18 final captures at 1440×900 and 1024×768 in six contact-sheet rows: Canvas, Graph, editor, inspector, composer, Library, Dashboard and dark regressions. README light Canvas refreshed. Background verification only; no physical-input/animation claim or live model request. [Evidence](verification/expansion-014/README.md). Next #15.

### 2026-11-17 — Expansion #15, semantic graph zoom (verified)

Graph titles become compact at overview scale, summaries appear closer in, and real artwork plus relationship labels appear in detail. Node positions stay fixed; routing uses visible card bounds. Visible-only bounded thumbnail decoding and a revision cache avoid full-image work during pan/zoom. Artwork indexes respect world, revision and archive state.

`./scripts/check.sh`: strict lint, 200 tests / 51 suites, optimized build. Inspected all 16 refined captures at both sizes plus two corrected selection captures. Visual iterations removed inactive-window hover and overlapping distant relationship labels; selection still exposes the full relation list. README detailed graph added. [Evidence](verification/expansion-015/README.md). No foreground events, model call, release or user-app restart. Next #16.

### 2026-11-17 — Expansion #16, document tabs (verified)

Connected tabs, pins, recent reopening, close-other-unpinned, native menu shortcuts and world-scoped local persistence. Native text views retain caret, scroll, rich text and per-document undo through tab/workspace switching. Fresh reviewed content invalidates old undo; failed saves block switching/closing. Corrupt tab metadata is preserved and cannot prevent opening lore. Closing is not archive.

`./scripts/check.sh`: strict lint, 204 tests / 52 suites, optimized build. Added real native editor retention tests plus disk/world/archive/failure regressions. Corrected reopening order to follow closure. All 16 background captures inspected at both sizes, covering pinned, overflow/long titles, reopened, Sections, recovery, Manual and light states. [Evidence](verification/expansion-016/README.md), [usage](DOCUMENTS.md). No foreground test, live model call or release; owner's app untouched. Next #17.

### Expansion #17 — independent scroll regions (2026-11-17)

Confirmed the existing three native scroll regions against long actual records, linked entities and conversation history. Added a background rendered-scroll audit that rejects movement of neighboring offsets or workspace frames; normalized fixture offsets after retained document state made the initial sequential test a no-op. Final check: strict lint, 204 tests / 52 suites, optimized build. All 36 scroll assertions passed and all 12 captures at 1440×900 / 1024×768 were inspected. No foreground events, user-data changes or model calls. Evidence: `docs/verification/expansion-017`. #18 is next; the full brief remains unfinished.

### Expansion #18 — operation feedback (2026-11-17)

Replaced ambiguous save labels with typed pending/running/committed/failure states and Retry. Search indexing remains part of the successful save transaction. Added named review progress with real commit counts, partial failure and world-switch cancellation; no canon privilege changes. Failed AI activity no longer collapses into a success label, elapsed waiting is visible, and Simulate states that outcomes are hypothetical. Final check passed strict lint, 210 tests / 53 suites and optimized build. All 20 final captures inspected at two sizes; review fixtures reflect actual commits/stale failure. No provider requests or foreground events. Evidence: `docs/verification/expansion-018`; #19 next.

### Expansion #19 — resizable panels (2026-11-17)

Added native nine-point splitters to navigation, record/workspace inspectors and docked/floating chat. Drag, double-click reset, focused arrow keys, accessibility actions and Settings controls share persisted bounds. Saved layouts retain widths; old layouts remain readable. A visual iteration changed narrow editors to float the inspector rather than squeeze writing controls. Defaults and independent scrolling are preserved.

Final `./scripts/check.sh`: strict lint, 215 tests / 54 suites and optimized build. Five meaningful panel tests; eight background rendered accessibility/hit-area assertions and six independent-scroll assertions. Inspected all 24 final captures at 1440×900, 1024×768 and 720×800, with earlier sheets retained as iteration evidence. No physical pointer/VoiceOver/animation claim, model call, release or owner-app restart. [Evidence](verification/expansion-019/README.md). #20 next.

### Expansion #20 — consistent hover and selection (2026-11-17)

Standardized native and Canvas entity surfaces, selected borders and washes; repeat spatial selection keeps its target, Timeline has read-only event selection, and Canvas supports Space/Enter/Escape with actual grouped engine state. Hover clears after focus, selection or workspace changes. Captures exposed default purple Excalidraw handles, then dark-filter inversion; handles now use the same inverse palette as other engine elements. Light Atlas markers gained opaque backplates for map contrast. The theme assertion now waits for the real border transition rather than sampling its intermediate colour; capture framing resets the audit-only pan after persistence checks.

Final `./scripts/check.sh`: strict lint, 216 tests / 54 suites and optimized build. Canvas: typecheck, 15 tests, offline bundle and 37 embedded-engine/native checks. Inspected 22 final states at 1440×900 and 1024×768, with earlier iterations retained. No physical pointer, animation-pacing or VoiceOver claim; no provider request, owner-app restart or release. AGENTS unchanged. [Evidence](verification/expansion-020/README.md). #21 next.

### Expansion #21 — universal command palette (2026-11-17)

Added real saved maps/boards, scene records, category tools, individual Settings controls and recent object changes to ⌘K. Full-text and metadata matches stay world-scoped; navigation resolves current sources and preserves failed-save guards. Search does not call a model. Split the catalog from the view; actual buttons, bounded keyboard movement and query-result scroll reset replace fragile row behavior. Screenshot iterations corrected compressed right-hand labels, excess height in short lists and compact-window title-bar overlap.

`./scripts/check.sh` passed strict lint, **219 tests / 55 suites** and optimized build. Four focused palette tests passed. **30 final native states** inspected: 22 main, four narrow and four body-only/search follow-ups. README includes the new palette screenshot; [SEARCH](SEARCH.md) documents real semantics and the latest-object limitation of recent changes. [Evidence](verification/expansion-021/README.md). No foreground events, live request, release or owner-app restart. Continue #22; all later unverified requirements remain open.

### Expansion #22 — advanced search syntax (2026-11-17)

Implemented both supplied examples in the shared core query path, plus category/tag/alias/related/created filters, quoted names, Unicode name matching and local syntax examples. Structured palette queries cannot fall through to unrelated commands or Capture; Library reports invalid queries and uses actual archived FTS data. Library category/kind/canon/section controls apply before the result limit. Saved drafts with older canon snapshots remain drafts for explicit status queries.

The complete check exposed an FTS LEFT JOIN performance regression (26 seconds for 20 searches). EXPLAIN showed a repeated virtual-table scan; materializing candidates fixed it. Final `./scripts/check.sh`: strict lint, **227 tests / 57 suites**, optimized native build. Ordinary/filtered 20-query benchmarks over 2,000 records: **66/76 ms**. Eight new regression tests cover the required examples, boundaries, injection-like input, quotes/aliases, archive/world isolation, current canon state, large-result Library scopes and Manual palette navigation. **20 final native states** inspected, with ten additional intermediate captures; README/search guide updated. [Evidence](verification/expansion-022/README.md). No migration, dependency, foreground input, subscription call or release. Continue #23.
