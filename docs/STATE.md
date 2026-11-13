# Implementation state — 2026-11-12

Active: complete native rebuild, development only. Baseline preserved in `02a93e3`.

## Verified so far

- Real `dist/Synthesis.app` builds, is ad-hoc signed and launches. SwiftUI/AppKit, not GPUI or HTML.
- New light chat-first shell, 240/68-point navigation, persisted dark theme and AI/Manual mode, native menus, ASCII orbital art.
- SQLite worlds, persistent chat history, rename/search, missing-provider error path; OpenAI streaming transport implemented but no live API call made.
- Manual library, capture, native rich editor, autosave, version history, explicit canon review, Markdown and JSON export.
- `./scripts/test.sh`: 8 tests passed (disk reopen, world isolation, canon approval and stale saves, relationships, boards/RTF, Manual blocking, in-flight cancellation, stubbed reply persistence).
- `./scripts/build.sh`: debug native bundle build/sign passed. Release build not yet run.
- First actual native screenshot round generated all six requested states. All 24 images inspected in contact sheets; desktop/home/manual and compact/home also inspected larger. Found and fixed compact art overflow and duplicate native menu indicators. 1920 captures were constrained by the physical display; the harness now rejects incorrect dimensions and allows offscreen native rendering. Corrected round pending.

## Limits / remaining gates

Functional mouse/keyboard walkthrough and second visual round pending. Canvas, graph, timeline, atlas are currently honest unavailable destinations. Core tables/operations exist; UI work follows primary-workspace validation. Rich chat tables/images, structured proposal diffs, tags/aliases UI, source/backlink inspector and crash-safe recovery need further work. No claims of live AI, browser testing, iOS support, GPUI, production release or notarization.

Discovery: repository had no actual frontend or route, only black three-pane HTML studies and a partial TypeScript domain scaffold. Preserved under `legacy/web`. Native app is the new actual entry point. No push, release, tag or paid provider usage this session.

## Owner steering — UI-first reset

The owner rejected this light editorial redesign and reports sluggishness. New references request a compact modular, canvas-first native UI with a Zeron-style floating composer, integrated window chrome and guided creation. Feature expansion is paused. The running UI is being replaced again; earlier screenshots document rejected iterations, not approved design. Backend/domain work stays preserved. Independent review found and fixes were applied for queued cancellation, canonical context projection and metadata restoration; queued-cancellation regression was observed fail before the fix.
