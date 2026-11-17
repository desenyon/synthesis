# Atlas follow-up verification — 2026-11-16

Follow-up on main after the published 0.0.1 tag; the existing release and its assets are unchanged.

The Atlas zoom buttons changed scale without adjusting pan. A map landmark at world coordinate -200, with pan +200 at 100%, moved from screen centre to -50pt after zooming to 125%. Buttons and pointer gestures now use the same focal transform, shared with Graph and retaining each workspace's zoom range. Invalid gesture coordinates are ignored. Atlas holds its decoded NSImage between loads/replacements rather than decoding base64 on each pan/zoom render.

Executed:

- `./scripts/test.sh --filter invalidGestureCoordinatesCannotPoisonTheViewport`: observed the expected two assertion failures before the fix; saved in `regression-before-fix.log`.
- `./scripts/test.sh --filter 'GraphGeometryTests|acceptedMarkersRefreshTheActiveAtlas'`: 10 tests passed after the fix. Covers centred landmarks, pointer anchoring at Atlas limits, Graph layout/routing, and actual Studio marker acceptance. The acceptance test updates a different map then the already-active map, checking refresh, image preservation, source preservation and untouched other maps.
- `./scripts/check.sh`: strict lint, 124 native tests / 27 suites, optimized build passed. The existing SwiftPM native-build deprecation warnings remain.
- `SYNTHESIS_CAPTURE_STATES=atlas-linked,light-atlas-linked,manual-atlas-linked,atlas-local,graph,light-graph SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 ./scripts/verify-ui.sh /tmp/synthesis-atlas-followup`: 12 native captures completed in an isolated database.
- `uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-atlas-followup`: both contact sheets inspected. Maps and markers remain visible in dark/light/Manual, the empty child map has its own state, and Graph remains fitted at both sizes. No overlapping controls or changed sidebar composition observed.

No foreground gestures, animation timing benchmark, live subscription call, owner's world modification or app restart. Captures use existing sample artwork; the owner's Aeronia attachment was inspected as reference and is neither imported into lore nor published here. Canvas source was unchanged; its Node/engine tests were not rerun in this follow-up. This does not certify physical trackpad behavior or dense-graph performance.
