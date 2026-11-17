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
