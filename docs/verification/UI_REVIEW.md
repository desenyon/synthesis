# Native UI review — 2026-11-12

Current target: the optimized `dist/Synthesis.app`, SwiftUI/AppKit. No HTML preview. The previous connected application is preserved at `f35e968`; this pass intentionally implements a transient UI study.

## Captures inspected

`canvas-final/` contains canvas, conversation, power-system, detail, collapsed and light states at 1440×900, 1920×1080, 1024×768 and 390×844 logical points. The harness asserted native content bounds; the contact-sheet script asserted every bitmap is exactly 2× those dimensions. All 24 final states were inspected through four contact sheets; the main 1440 canvas was also inspected at larger size. `canvas-pass1/` is diagnostic, not the final composition.

[Canvas](canvas-final/canvas-1440x900.png) · [Conversation](canvas-final/conversation-1440x900.png) · [Power systems](canvas-final/power-system-1440x900.png) · [Light](canvas-final/light-1440x900.png)

Corrections from inspection: full world-name menu label, separated starter cards/composer, quieter light shadow, fit-to-window initial framing, module-specific starter chips. Spatial cards shrink in the compact overview; individual module views preserve readable cards. This is not an iOS build.

## Native interaction evidence

- Launched the optimized native window: integrated header, no separate macOS title bar.
- Selected Power Systems: source question and relevant source chips appeared.
- Typed “Power is drawn from the memories stored in ancient trees.” and pressed Return: a draft fragment appeared and the guide advanced to expression.
- Opened that fragment, renamed it “Memory roots,” and closed the inspector: card/sidebar updated.
- ⌘K searched “Memory”: one matching fragment remained; opening it returned to its inspector.
- Selected Universal History: beginning-of-history question and ancient-age/civilization/myth chips appeared.
- Selected Manual notes: guided question/chips disappeared.
- ⌘N opened a new editable fragment; theme and hide-chat controls visibly changed state.
- Earlier in the same UI pass: custom Languages module creation, conversation view, sidebar collapse and zoom-button changes were observed.
- Restarted the process and left the clean canvas open for owner review. Study state resets by design.

Drag automation returned `noWindowsAvailable` twice for the borderless window. Do not count card dragging, pan gestures, pinch or header dragging as manually verified. Their implementations remain available for direct review. No FPS or latency measurement was performed.

## Commands actually run

- `./scripts/test.sh`: 13 tests, two suites passed. Covers persistence, isolation, explicit canon boundary, cancellation, context projection and metadata restoration in preserved core.
- `swift format lint --strict --recursive Sources Tests Package.swift`: passed.
- `./scripts/build.sh release`: passed; development bundle ad-hoc signed. SwiftPM emitted its known native-build-system deprecation warning.
- `git diff --check`: passed.
- Native capture executable with isolated temporary `SYNTHESIS_DATABASE_PATH` and `SYNTHESIS_CAPTURE_DIR=.../canvas-final`: completed all 24 captures.
- `uv run --with pillow python scripts/contact-sheets.py docs/verification/canvas-final`: passed all dimension assertions and generated four inspected sheets.

No provider request, browser test, deployment, release, notarization or push. UI fragments are not saved to lore; user data and canon remain untouched. Readiness means ready for visual review, not completion of the full application.
