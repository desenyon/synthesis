# Current state — 2026-11-15

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`. Build/open `dist/Synthesis.app` here. SwiftUI/AppKit + SQLite, offline Excalidraw Canvas. Development only. The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` is preserved and excluded from commits.

## This pass

- Phosphor replaces authored Lucide controls in native UI and Canvas. Inter is bundled for both renderers and new editor/composer text; existing rich-text formatting survives. Black workspace, native sidebar glass (Liquid Glass on macOS 26+, material fallback, opaque accessibility fallback), capitalized brand and collapse-after-brand header.
- Fixed the opaque native workspace background covering WebKit. **Live on-screen inspection confirmed actual cards/toolbars render**, and native Fit changes the viewport. This corrects the earlier unsupported claim that blank native Canvas pixels were only a screenshot limitation.
- Canvas syncs newly saved records before placement, queues additions during loading, surfaces PNG export errors and routes overlapping cards outside their content. The integration audit verifies actual PNG encoding, reviewed placement, image reload and save failure handling.
- Contextual composer/companion in Library, records, Graph, Timeline, Atlas and Review. Open records enter request context. Compact companions collapse navigation or take over the content area. Manual still cancels and blocks providers in the core.
- World dashboard, first-install-only setup, full-page application/current-world settings, Codex recommendation, native world open/save/export menus. Systems navigation includes existing Factions records without rewriting categories. Removed persistent provider and browsing draft badges; review/editor canon state remains explicit.
- Portable `.synthesis` version 2 snapshots and transactional import into a new world; v1 import supported. IDs and internal references are remapped. Includes rich text, images, boards, conversations, rules, proposals, archived content and history; excludes device/provider preferences. Explicit snapshots, not filesystem sync. Markdown, JSON and image-only export controls remain available.
- FTS matches hydrate in one query; Library/quick-open cache results across hover/selection redraws. Review has search and oldest/newest proposal sorting. Graph can save independently labelled reverse relationships atomically and uses outside curves for close nodes.
- Migration 0007: nested timeline branches/periods and event membership, free-form date boundaries, reversible lane archive. User edits are atomic. Assistant can propose branches/periods and events in an existing lane, with explicit approval. This is chronology organization, **not branching canon, simulation, or merging**.

## Verification

- `./scripts/check.sh`: strict Swift lint, **70 tests / 14 suites**, optimized development build passed after the final native-glass, compact layout and export-path corrections.
- `cd CanvasWeb && npm run typecheck && npm test && npm run build`: passed, **8 Node tests**. A tuple-inference error in new routing was fixed before this successful run.
- Search fixture: 20 indexed queries over 2,000 records took **25.95 ms total** in one local run. This is not a large-world performance guarantee.
- `check-capture-isolation.py`: fresh-path/existing-path refusal passed.
- Background captures: **30 states** across 1440×900 and 1024×768 inspected as contact sheets. Found and corrected compact Library companion clipping and the old Claude recommendation badge; **12 targeted recaptures** were inspected and confirmed the corrections. Contact sheets contain both initial and updated states.
- Background Canvas audit: **19 passing checks**, including real PNG export, card drag/undo/redo, stored relationship updates, image retention, Manual AI removal, blocked unacknowledged save and reviewed placement reaching the engine.
- The actual native app was reopened and Canvas pixels inspected with computer use. No live model call, foreground pointer self-test suite, or native export/save-dialog walkthrough was run. Background screenshots composite WebKit and cannot establish native occlusion; that specific fix was separately inspected live.

## Remaining scope and risks

[Next-pass ledger](NEXT_PASS.md) preserves the full request. Runtime subscription image generation, lore-coherent map generation/hierarchy, customizable entity subcards, dedicated power-system/cosmology workspaces, richer global/world preferences, timeline zoom and canon branches, full autonomous tools and exhaustive interaction coverage remain incomplete. PNG export works but does not yet reproduce every DOM card decoration.

Dependency follow-up: `npm audit` now reports **zero findings** after pinning patched lodash-es, KaTeX and Nano ID transitive dependencies, retaining Excalidraw 0.18.1. Canvas typecheck, eight tests, rebuilt offline bundle and 19 background engine checks passed. React 19 / older Radix peer warnings remain; this is not a claim of complete upstream compatibility or a security audit of bundled vendor internals. See [DEPENDENCIES](DEPENDENCIES.md).

Next: review the running studio, then finish explicit-use image transport and editable map geometry as separate verified slices. Preserve canon approval and avoid subscription usage without an explicit user generation action. AGENTS.md unchanged.

Implementation checkpoint: `536b37a`. Final review build compiled from the canonical checkout. Markdown category paths are sanitized and covered by a traversal regression test.


## Update — entity sections and audit (2026-11-15)

- Entity sections are implemented: migration 0008, ordered child lore records with their own history and canon review, Overview / Sections tabs, create, open, reorder, remove with Undo, reviewed `add_section` proposals, and membership preserved in `.synthesis` v3, JSON schema 7 and Markdown export.
- Checks observed: `./scripts/check.sh` passed with **78 tests / 17 suites**; **47 states × 2 sizes** captured and inspected.
- The same review produced [AUDIT.md](AUDIT.md): 22 open defects with fix prompts. The critical ones are the sidebar and Canvas bar rendering in the wrong theme (seen in background captures; confirm in the running window) and section records counted as top-level Library items. The audit ledger below tracks the current repair pass.
- Active repair order: the master prompt in AUDIT.md; C2/C3 remain excluded.

## Audit repair pass

A1 completed and pushed with live theme checks and pixel assertions. A2 implemented and ten captures inspected, but its live check is blocked by macOS capture error -3812; checkbox remains open. Per-item checks and evidence are in PROGRESS.md and verification/audit-*. Next: B1 section hierarchy.

- Audit B1: Active world-scoped section memberships drive top-level navigation, Library counts and Conversation suggestions; Sections filter preserves access and labels parents. Search, mentions and retrieval retain child records. ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Library, conversation-home and sections captured at both sizes and both contact sheets inspected; sample Characters now shows 2, Library shows 9 top-level items.

- Audit B2: Entities default to Overview with per-record session tab memory. Sections shows its count and omits duplicated parent prose; fixtures explicitly select that tab. ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Editor, sections and light-sections captured at both sizes; both contact sheets inspected.

- Audit C1: Shared ContentColumn and ContentHeader align Library, Review, Timeline, Sections, Settings and Worlds at 880 pt with 28 pt side padding. Corrected the history menu centering after the first visual pass. Final ./scripts/check.sh passed: lint, 80 tests / 17 suites, optimized build. Seven requested states at both sizes recaptured and both final contact sheets inspected. Editor reading width and unapproved C2/C3 unchanged.
