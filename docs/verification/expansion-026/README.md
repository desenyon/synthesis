# Expansion #26 — split workspace

Verified 2026-11-17 in the native app, against isolated databases.

- A real native record editor opens beside Atlas, Timeline, Graph, Canvas or another record. Both panes retain independent text views, caret/undo, formatting, sections, mechanics, revisions and canon review. Opening the same record in another pane moves it; no competing editors are mounted.
- Both save callbacks guard navigation, archive, swapping, closing and world changes. Focus routes ⌘W/inspector commands. Closing the main record preserves the secondary. Per-world secondary addresses and device-wide widths survive restart; saved layouts and Back/Forward resolve fresh sources. Manual blocks AI as before.
- The shared composer is below both panes. Short windows stack and scroll content; compact bars retain all utilities in a menu. Initial captures exposed collapsed titles, composer obstruction, repeated breadcrumbs and clipped controls. Follow-up captures verify those fixes.
- Canvas remains the same mounted engine. Precise fit bounds avoid Excalidraw's 10-percent floor rounding; short drawing toolbars become horizontal. No lore or canonical state is changed by opening or fitting a view.
- `./scripts/check.sh`: strict lint, **251 tests / 62 suites**, optimized ad-hoc build. Seven new native tests cover the boundaries above, including two actual native text views and independent undo.
- Canvas: **17 tests**, typecheck and rebuilt offline bundle. **37 embedded-engine checks** passed in `corrected/capture.log`, including persistence, viewport reload, image export, drag/undo and failed-save recovery.
- **37 final captures inspected:** all 26 cells in `verified`; five 720×800 cells plus ordinary Canvas at 1440×900 and 1024×768 in `compact-fix`; four 1920×1080 cells in `final`. All corresponding contact-sheet cells were inspected. Earlier `main`, `refined`, `corrected` and intermediate final/compact states preserve the refinement trail; the `corrected` ordinary 1024 Canvas frame retained a prior split and is superseded by the reset fixture in `compact-fix`.
- README screenshot is `verified/split-atlas-1440x900.png`, copied before PNG pruning.

```sh
./scripts/check.sh
cd CanvasWeb && npm test && npm run typecheck && npm run build
# From repository root:
SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=canvas,split-canvas,split-closed ./scripts/verify-ui.sh docs/verification/expansion-026/corrected
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,1920x1080,720x800 SYNTHESIS_CAPTURE_STATES=canvas,split-atlas,split-closed,split-canvas ./scripts/verify-ui.sh docs/verification/expansion-026/final
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=canvas,split-atlas,light-split-atlas,split-closed,split-canvas ./scripts/verify-ui.sh docs/verification/expansion-026/compact-fix
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=split-atlas,light-split-atlas,manual-split-atlas,split-timeline,split-graph,split-editor,light-split-editor,split-picker,split-inspector,split-closed,split-swapped,split-long,split-canvas ./scripts/verify-ui.sh docs/verification/expansion-026/verified
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-026/verified --prune
```

No live provider request, foreground input, owner-data mutation, owner-app restart or release. Native captures and state/engine checks do not establish physical input feel, animation pacing or VoiceOver. AGENTS.md unchanged. Continue #27; the full expansion remains unfinished.
