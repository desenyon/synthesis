# Handoff — 2026-11-13 reference and feature audit

Read `AGENTS.md`, `STATE.md` and `verification/REFINEMENT_AUDIT.md`. Continue in **`/Users/desenyon/.zeron/worktrees/synthesis/swift-falcon`**, branch `zeron/you-are-an-elite-product-designer-ux`. Claude’s `4ab3f73` app is the baseline; do not revive the main-checkout SwiftFlow UI. The owner has now authorized iterative audits and implementation, superseding the earlier request to wait for review.

## Preserve these unfinished owner changes

These were already dirty before this audit and were not edited or staged by it:

- `Sources/SynthesisCore/{AgentEngine,Portability,WorkspaceStore}.swift`
- `Tests/SynthesisCoreTests/StoreTests.swift`
- Untracked `Sources/SynthesisCore/Rules.swift` and `Migrations/0006_rules.sql`

They contain the unfinished rules lab. They compile and their tests ran as part of the 51-test suite, but full strict lint reports eight formatting errors in that work. Do not mistake them for committed audit changes or silently discard them. The review binary includes the current working tree, including these files; the audit commits do not.

## Implemented

- `CanvasWeb/src/StudioOverlay.tsx` owns visible custom cards, artwork, ports and tools. Excalidraw remains the scene/gesture/history engine. Card bodies are pointer-transparent. Record actions and connection ports invoke the native bridge. Escape cancels connecting. No fake lore or second scene store.
- `cards.ts` tracks innermost card groups and updates archived/renamed relationships. `sceneRules.ts` tests pan/zoom transforms, culling, session identity, rotation and group/relationship rules. Card engine parts are transparent during display and restored for export.
- Both bridge sides scope every load/message with a session ID. Opening another board flushes first; failed acknowledgement stops navigation. A cancellable timeout belongs to one flush. Quit/window-close use the acknowledgement result and keep the app open on failure. Images install after resetting the engine scene. Undo/redo key events go to `.excalidraw`, not `document`.
- `Artwork.swift` provides two optional GPT illustrations. Source/provenance: `Assets/GENERATED_ARTWORK.md`. New sample worlds use them; existing worlds are unchanged. Atlas replacement offers Undo. Browser images normalize TIFF/HEIC to PNG and enforce input/dimension/output bounds.
- `RecordPicker.swift` replaces capped menus in editor links, Timeline and Atlas. Timeline actions are visible. Theme/composer surfaces follow the graphite reference.
- Background verification builds into a temporary bundle, demands a new database and rejects all model requests. Capture windows cannot become key/main, ignore pointer events and stay below ordinary windows. `SynthesisApplication` blocks framework activation requests during background captures. Native sheet presentation can independently activate the app, so `SheetPresentation.swift` renders the same content inline only during background snapshots. Normal use and the explicit foreground runner retain actual modal sheets. The capture check still asserts inactive/non-key state.

## Builds and evidence

Separate review bundle: `dist/Synthesis-review.app`. It was built, **not opened over the owner’s work**. Do not overwrite or restart their running `dist/Synthesis.app` to test. No foreground self-test, live provider call, release or push occurred.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
swift format lint --strict --recursive Sources/SynthesisUI Sources/SynthesisApp Tests/SynthesisUITests
./scripts/test.sh
(cd CanvasWeb && npm run typecheck && npm test && npm run build)
SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_STATES=canvas,companion,light,manual,sheet-artwork SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 ./scripts/verify-ui.sh test-results/review
./scripts/build.sh release dist/Synthesis-review.app
python3 scripts/check-capture-isolation.py dist/Synthesis-review.app/Contents/MacOS/Synthesis
```

Observed: scoped lint; 51 native tests; six Node tests; TypeScript/bundle build; optimized native build; 17 WebKit/native-save checks. The 78-image broad sweep (`test-results/refinement-final`) has 20 inspected contact pages. Focused sweeps correct stacking, duplicate text, mobile chrome and picker clipping; final evidence is linked from the audit ledger. Captured conversations/proposals are authored test fixtures, never presented as real model execution. Engine dragging uses internal synthetic pointer events; it is not a physical mouse/trackpad test.

## Continue in this order

1. Canvas connection-port → native relationship review → persistence; arrow relabel/hide/restore; drawing-style panel and keyboard/context menus. Add controlled engine/native checks, not foreground events while the owner works. Inspect curve routing: tightly spaced cards can produce awkward bends with engine binding adjustments. Export retains content but does not yet match DOM materials; resolve this before calling visual parity complete.
2. Measure and optimize large boards/graphs. Current offscreen culling/indexing is an improvement, not an FPS benchmark. Compact fitted boards show an overview; full card text needs zoom. Derived Graph remains native deterministic force layout, separate from curated Canvas.
3. Controlled streaming/Stop UI and cancellation races. Do not invoke paid/provider calls without authorization. Earlier Claude evidence records one live request per subscription harness; this audit made none.
4. Editor crash recovery, long/Unicode content, all record-picker interactions, keyboard/VoiceOver, real trackpad testing during an agreed review window.
5. Timeline era/reordering/canon behavior and Atlas multiple maps/marker dragging. Runtime image generation is still absent; bundled illustrations must not be described as live generation.

AGENTS.md was read and **not changed**. Detailed durable findings are in LEARNINGS.md. Existing historical verification documents describe earlier versions; use the current ledger for current acceptance status.
