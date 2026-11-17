# Current state — 2026-11-15

## Connected presentation — 2026-11-16

Shared full, companion and compact composers now use one lore-aware control system. The conversation home places writing beside its heading and real references. App dropdowns use a themed popover; workspace/companion transitions respect Reduce Motion. Native Kokonut-inspired activity reports actual retrieval, response and proposal validation, with observed timings and no demo playback. Usage: [AI_COMPONENTS](AI_COMPONENTS.md).

Graph now renders entity cards from stored records and uses bundled Dagre 3.1.3 for directed layout. Ports open relationship creation; labels open editing; neighbourhood selection and copy-to-Canvas remain connected to the same IDs. Canvas adds an explicit undoable Arrange command. PNG export paints the visible Synthesis card typography, state and local artwork instead of hidden engine text; stale exports after switching boards are rejected.

Verification: `./scripts/check.sh` passed strict lint, **102 tests / 23 suites**, and the optimized development build. Canvas typecheck, **9 Node tests**, and offline bundle build passed. The background WebKit audit passed **22 checks**, including arrangement/undo, PNG export, reload, ownership, relationship edits and save retry. Inspected 28 native state captures at 1440×900 and 1024×768, plus the real exported PNG. Graph fitting and export colours were corrected after inspection; final evidence is in `verification/connected-presentation`. README screenshots were refreshed from those states.

Limits: themed popover keyboard/pointer behaviour and live subscription streaming have not been exercised in a foreground session. No paid generation, native file-dialog walkthrough or foreground self-test ran. The owner's running app and database were untouched. Dedicated creative components and deeper specialized studios are next; this is not completion of the full feature request. AGENTS.md unchanged. C2 remains unapproved; the owner's latest composer directive supersedes the earlier request to skip composer work, without adopting C3's specific 36-point-pill proposal.

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`. Build/open `dist/Synthesis.app` here. SwiftUI/AppKit + SQLite and the offline Excalidraw Canvas. Development only; no release or deployment. The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` is preserved and excluded from commits.

## README screenshots

The README now shows the native Canvas and an expandable five-view gallery. Six fresh 1440×900 captures from `0148d8a` were inspected; image paths and PNG dimensions validated. Capture assets, provenance and regeneration steps live in `docs/screenshots`. Documentation/assets only; the capture build passed, with no new runtime changes or test-suite rerun.

## Settings refinement

Settings is now one searchable native workspace: General, Writing, Assistant, This world and Data. Compact windows use a section menu; provider details are collapsed by default. Chat setup links open Assistant settings. Onboarding shares the connection control; the obsolete Settings modal/provider cards and unused secure-field branch are removed.

- Twelve validated device preferences control writing size/width, spelling and substitutions, word counts, Library summaries, sidebar counts/history limits, launch destination and send keys. Existing rich formatting survives size changes.
- Two per-world defaults set the initial entity type and conversation mode. They round-trip in `.synthesis` v4; v1–v3 imports remain supported. Device/provider settings stay excluded.
- World name/description save atomically. New record accepts custom entity types. Data gives each import/export format an explained action.
- Provider selection makes no implicit status check or generation request. Manual/canon safeguards remain unchanged.

`./scripts/check.sh` passed on final source: strict lint, **94 tests in 21 suites**, optimized ad-hoc development build. **40 final background captures** were inspected in contact sheets: 17 states each at 1440×900 and 1024×768, plus six at 720×800. Coverage includes every section, provider disclosure, search/results/empty, Manual, collapsed navigation, light theme, onboarding, custom entity creation and changed preferences in editor/Library. Evidence: `verification/settings-refinement`. Native file dialogs, live provider calls, keyboard-focus traversal and physical pointer/scroll interaction were not exercised; background captures do not certify those. The earlier preference foundation passed 91 tests and two inspected editor/Library captures, committed and pushed as `6819302`.

## Audit repair pass

Worked in the exact [AUDIT](AUDIT.md) master order, with one commit and push per item. [PROGRESS](PROGRESS.md) records commands, outcomes and limits; evidence is in `docs/verification/audit-<item>`.

- **Completed:** A1, B1–B11, C1, C4–C7, D1–D2 (19 items).
- **A2 implemented, still unticked:** opaque Canvas chrome and initial theme delivery passed ten background captures. The required live check could not complete because macOS Computer Use returned `SCStreamErrorDomain -3812` / invalid parameter. Background evidence does not replace that live check.
- **C2 and C3 skipped:** not approved. No broad dark-theme depth change or global composer redesign was made.
- **D2 boundary:** all eight sheet states now capture on opaque panels, including over WebKit. The New record modal/Escape self-test and attached-modal snapshot were added and compiled, but the foreground runner was not invoked because it takes focus. Native modal interaction remains unverified.

## What changed

- Sidebar uses an opaque theme surface and explicit native window appearance; A1 was also checked live through three theme toggles. Compact navigation has a conditional 16 pt scroll fade and a full-width hairline footer. Phosphor icons, Inter typography, the black workspace and native titled window remain.
- Entity sections are excluded from top-level Library/navigation counts and suggestions, while search, mentions and retrieval still include them. Library has a Sections filter and parent labels. Records open on Overview and remember their tab during the session. Stored Factions categories display consistently as Systems.
- Shared content columns align Library, Review, Timeline, Sections, Worlds and Settings. Compact editor headers prioritize the record title when the companion is open. Rules appear on power systems, cosmology, systems, or existing rule holders; the rule field is labeled.
- Canvas Fit reserves measured composer and toolbar space. Cards show one category and an explicit state; PNG labels share that wording. Sheet capture compositing protects panel bounds from WebKit pixels.
- An empty world can create its first Timeline event and a source draft in one transaction. The required source constraint remains intact.
- Record and world Markdown exports share metadata and native rich-text conversion. Entity export includes sections and local anchors; filenames are sanitized with an Untitled fallback.
- Worlds shows saved covers, descriptions, counts, activity timestamps and the current-world marker. Description is editable. The earlier audit grouped Settings world/import/export controls; the new searchable Settings refinement above supersedes that layout. Onboarding keeps model editing and the image note in Settings. Review explains the decisions badge and separates local check counts. Sample illustration copy is provider-neutral.

## Verification observed

- `./scripts/check.sh` passed after every item's final code change: strict Swift lint, native tests and optimized ad-hoc development build. Latest: **84 tests in 19 suites**.
- `cd CanvasWeb && npm run typecheck && npm test && npm run build` passed for Canvas changes: **8 Node tests**, committed offline bundle.
- The B4 native/WebKit audit passed **20 checks**, including fitted card bounds clearing overlays.
- **117 final per-item background state captures** were inspected in contact sheets, primarily at 1440×900 and 1024×768. These are staged evidence for each commit, not a claim that every app state was rerun on the final commit. D1 now captures the actual empty Sections state.
- A1's sidebar pixel assertion failed against the old light capture and passed seven repaired captures. A1 live theme checks succeeded; A2 live inspection failed as described above.
- No live provider requests, foreground pointer self-test suite, native save/export-dialog walkthrough or paid generation ran in this audit. Tests/captures use isolated databases and reject model requests. Capture jobs remain in the background.

## Existing capabilities and limits

Connected documents, entities, links, typed relationships, conversations, draft proposals, explicit canon approval, reversible archive, world-scoped search and Manual cancellation remain. Sections use migration 0008 and portable `.synthesis` v4 / JSON schema 7; older world imports remain supported. Nested chronology branches/periods organize events but do not branch or merge canon. The full request and future feature gaps remain in [NEXT_PASS](NEXT_PASS.md).

On-demand subscription image generation, lore-coherent editable map geometry/hierarchy, dedicated power-system/cosmology studios, exhaustive large-board, accessibility and trackpad coverage remain incomplete. PNG output now reproduces card content and artwork; editor-only connection handles and controls are intentionally excluded. Dependency evidence in [DEPENDENCIES](DEPENDENCIES.md) is from the earlier scoped audit, not a new security audit in this repair pass.

Next: expand preference interaction coverage and writing recovery, then finish A2's live dark/light check when native capture is available; run the opt-in modal Escape check when foreground testing will not interrupt the owner. Keep C2/C3 excluded until explicitly approved, then continue the owner-prioritized feature ledger. AGENTS.md unchanged.
