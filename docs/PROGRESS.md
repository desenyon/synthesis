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
