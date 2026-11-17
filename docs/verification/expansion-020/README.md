# Expansion #20 — shared hover and selection

Graph, Canvas, Atlas markers/regions, inspected Library rows and Timeline events now use the same accent boundary and quiet selected fill. Semantic category colours remain separate. Hover/selection never changes card dimensions. Native hover clears on focus, workspace, availability and selection changes; Canvas clears on pointer exit, focus loss, tool/viewport/selection changes. Repeated spatial selection preserves the target. Library retains its existing single-click open behavior. Timeline selection is a validated read-only preview; editing remains explicit. Canvas Space selects the actual grouped engine elements, Enter opens the record, and Escape clears selection.

Verification:

- `./scripts/check.sh`: strict Swift format lint, **216 tests / 54 suites**, optimized ad-hoc build.
- Canvas `npm run typecheck`, `npm test` (**15**) and `npm run build` passed.
- **37 embedded-engine/native checks** passed, including selection colours and unchanged geometry in dark/light/OLED, keyboard selection, focus cleanup, drag/undo, locked relationships, offline export and repeated persistence/reload. These invoke engine/DOM handlers in the actual bundled WKWebView; they do not establish physical pointer behavior.
- **22 final native states** inspected at 1440×900 and 1024×768. Use `final/` for Graph (dark/light/Manual), Library and Timeline; use `verified/` for Canvas (selected/unselected, light/dark), Atlas markers and regions. Contact sheets were inspected, including all earlier iterations in `final/` and `refined/`.

Iteration evidence: `probe/` and `diagnostic/` recorded a colour assertion sampled halfway through the 180 ms border transition. The assertion now waits for the actual animation. Screenshots then exposed Excalidraw's default purple handles and its dark-canvas inversion; handles use the shared inverse-filter palette. Light Atlas markers needed a surface behind their glyphs to remain visible over artwork. The capture runner reframes after the audit deliberately pans to check persistence. `refined/` preserves that intermediate appearance, superseded by `verified/`.

```sh
./scripts/check.sh
cd CanvasWeb && npm run typecheck && npm test && npm run build
# From repository root:
SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=canvas,selection-graph,light-selection-graph,manual-selection-graph,selection-canvas,light-selection-canvas,selection-atlas,light-selection-atlas,selection-regions,selection-library,selection-timeline ./scripts/verify-ui.sh docs/verification/expansion-020/final
SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=canvas,selection-canvas,light-selection-canvas,selection-atlas,light-selection-atlas,selection-regions ./scripts/verify-ui.sh docs/verification/expansion-020/verified
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-020/verified --prune
```

No foreground activation/events, subscription request, owner-data changes, release or owner-app restart. Motion pacing and VoiceOver remain outside these checks. #21 follows; the full expansion brief remains unfinished.
