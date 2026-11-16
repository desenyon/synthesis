# Current state — 2026-11-15

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`. Build/open `dist/Synthesis.app` here. SwiftUI/AppKit + SQLite and the offline Excalidraw Canvas. Development only; no release or deployment. The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` is preserved and excluded from commits.

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
- Worlds shows saved covers, descriptions, counts, activity timestamps and the current-world marker. Description is editable. Settings orders world details, import and four export formats consistently, with a shared Light/Dark switch. Onboarding keeps model editing and the image note in Settings. Review explains the decisions badge and separates local check counts. Sample illustration copy is provider-neutral.

## Verification observed

- `./scripts/check.sh` passed after every item's final code change: strict Swift lint, native tests and optimized ad-hoc development build. Latest: **84 tests in 19 suites**.
- `cd CanvasWeb && npm run typecheck && npm test && npm run build` passed for Canvas changes: **8 Node tests**, committed offline bundle.
- The B4 native/WebKit audit passed **20 checks**, including fitted card bounds clearing overlays.
- **117 final per-item background state captures** were inspected in contact sheets, primarily at 1440×900 and 1024×768. These are staged evidence for each commit, not a claim that every app state was rerun on the final commit. D1 now captures the actual empty Sections state.
- A1's sidebar pixel assertion failed against the old light capture and passed seven repaired captures. A1 live theme checks succeeded; A2 live inspection failed as described above.
- No live provider requests, foreground pointer self-test suite, native save/export-dialog walkthrough or paid generation ran in this audit. Tests/captures use isolated databases and reject model requests. Capture jobs remain in the background.

## Existing capabilities and limits

Connected documents, entities, links, typed relationships, conversations, draft proposals, explicit canon approval, reversible archive, world-scoped search and Manual cancellation remain. Sections use migration 0008 and portable `.synthesis` v3 / JSON schema 7; older world imports remain supported. Nested chronology branches/periods organize events but do not branch or merge canon. The full request and future feature gaps remain in [NEXT_PASS](NEXT_PASS.md).

On-demand subscription image generation, lore-coherent editable map geometry/hierarchy, dedicated power-system/cosmology studios, richer world preferences and exhaustive large-board, accessibility and trackpad coverage remain incomplete. PNG output does not reproduce every DOM card decoration. Dependency evidence in [DEPENDENCIES](DEPENDENCIES.md) is from the earlier scoped audit, not a new security audit in this repair pass.

Next: finish A2's live dark/light check when native capture is available; run the opt-in modal Escape check when foreground testing will not interrupt the owner. Keep C2/C3 excluded until explicitly approved, then continue the owner-prioritized feature ledger. AGENTS.md unchanged.
