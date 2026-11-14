# Handoff — main consolidation, 2026-11-13

**Use `/Users/desenyon/Developer/synthesis` on `main`.** The owner selected the reviewed Claude-based app as the primary implementation, authorized pushing it to GitHub and removing the other worktrees. Build and launch `dist/Synthesis.app` from this checkout. The old `swift-falcon` path is retired; do not recreate it or launch its archived binaries.

The merge retains both histories while using the reviewed source tree, not the superseded SwiftFlow frontend. The unfinished rules backend formerly left uncommitted is now checkpointed at `7e8b5d3`, with formatting corrected and tests retained. It includes migration 0006, rules/scenarios, assistant-context/Markdown support and export schema 5. This does not complete a Rules Lab UI.

Private recovery copies (Git bundle, original unfinished files, SQLite snapshot and retired worktree/build artifacts) live outside the repository under `~/Library/Application Support/Synthesis/Development Archives/`. Do not publish them. No lore was replaced and no provider request was sent.

Read `AGENTS.md`, `STATE.md` and `verification/MAIN_CONSOLIDATION.md` first. The earlier reference audit remains in `verification/REFINEMENT_AUDIT.md`; it describes that session's limits, including a lint failure subsequently resolved during consolidation.

## Implemented

- `CanvasWeb/src/StudioOverlay.tsx` owns visible custom cards, artwork, ports and tools. Excalidraw remains the scene/gesture/history engine. Card bodies are pointer-transparent. Record actions and connection ports invoke the native bridge. Escape cancels connecting. No fake lore or second scene store.
- `cards.ts` tracks innermost card groups and updates archived/renamed relationships. `sceneRules.ts` tests pan/zoom transforms, culling, session identity, rotation and group/relationship rules. Card engine parts are transparent during display and restored for export.
- Both bridge sides scope every load/message with a session ID. Opening another board flushes first; failed acknowledgement stops navigation. A cancellable timeout belongs to one flush. Quit/window-close use the acknowledgement result and keep the app open on failure. Images install after resetting the engine scene. Undo/redo key events go to `.excalidraw`, not `document`.
- `Artwork.swift` provides two optional GPT illustrations. Source/provenance: `Assets/GENERATED_ARTWORK.md`. New sample worlds use them; existing worlds are unchanged. Atlas replacement offers Undo. Browser images normalize TIFF/HEIC to PNG and enforce input/dimension/output bounds.
- `RecordPicker.swift` replaces capped menus in editor links, Timeline and Atlas. Timeline actions are visible. Theme/composer surfaces follow the graphite reference.
- Background verification builds into a temporary bundle, demands a new database and rejects all model requests. Capture windows cannot become key/main, ignore pointer events and stay below ordinary windows. `SynthesisApplication` blocks framework activation requests during background captures. Native sheet presentation can independently activate the app, so `SheetPresentation.swift` renders the same content inline only during background snapshots. Normal use and the explicit foreground runner retain actual modal sheets. The capture check still asserts inactive/non-key state.

## Builds and evidence

Primary review bundle: `dist/Synthesis.app` in the main checkout. The owner explicitly requested launching it for this review. Future automated checks stay in the background and must not restart the user’s running app. A separate `dist/Synthesis-review.app` remains an optional build target, not the primary launch path. No release or live provider call is authorized by this consolidation.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
swift format lint --strict --recursive Sources/SynthesisUI Sources/SynthesisApp Tests/SynthesisUITests
./scripts/test.sh
(cd CanvasWeb && npm run typecheck && npm test && npm run build)
SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_STATES=canvas,companion,light,manual,sheet-artwork SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 ./scripts/verify-ui.sh test-results/review
./scripts/build.sh release dist/Synthesis-review.app
python3 scripts/check-capture-isolation.py dist/Synthesis-review.app/Contents/MacOS/Synthesis
```

Observed in the consolidation: full strict lint; 51 native tests; six Node tests; TypeScript/bundle build; optimized native build; 17 WebKit/native-save checks. The 78-image broad sweep (`test-results/refinement-final`) has 20 inspected contact pages. Focused sweeps correct stacking, duplicate text, mobile chrome and picker clipping; final evidence is linked from the audit ledger. Captured conversations/proposals are authored test fixtures, never presented as real model execution. Engine dragging uses internal synthetic pointer events; it is not a physical mouse/trackpad test.

## Continue in this order

1. Canvas connection-port → native relationship review → persistence; arrow relabel/hide/restore; drawing-style panel and keyboard/context menus. Add controlled engine/native checks, not foreground events while the owner works. Inspect curve routing: tightly spaced cards can produce awkward bends with engine binding adjustments. Export retains content but does not yet match DOM materials; resolve this before calling visual parity complete.
2. Measure and optimize large boards/graphs. Current offscreen culling/indexing is an improvement, not an FPS benchmark. Compact fitted boards show an overview; full card text needs zoom. Derived Graph remains native deterministic force layout, separate from curated Canvas.
3. Controlled streaming/Stop UI and cancellation races. Do not invoke paid/provider calls without authorization. Earlier Claude evidence records one live request per subscription harness; this audit made none.
4. Editor crash recovery, long/Unicode content, all record-picker interactions, keyboard/VoiceOver, real trackpad testing during an agreed review window.
5. Timeline era/reordering/canon behavior and Atlas multiple maps/marker dragging. Runtime image generation is still absent; bundled illustrations must not be described as live generation.

AGENTS.md was read and **not changed**. Detailed durable findings are in LEARNINGS.md. Existing historical verification documents describe earlier versions; use the current ledger for current acceptance status.
