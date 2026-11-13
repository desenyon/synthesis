# Current state — UI first

## Latest owner direction

Pause application feature expansion. The previous light serif redesign was rejected. Match the latest three references with an infinite canvas, compact modular sidebar, a Zeron-style floating chat composer, guided world creation, fluid interaction and no separate native title bar.

## Current executable

`dist/Synthesis.app` now opens **CanvasDesignRoot**, an optimized SwiftUI/AppKit UI study. The prior application is preserved in source and commit `f35e968`; its lore/database/schema remain intact. This is not GPUI and contains no WebView or HTML preview.

Implemented UI: borderless native window with draggable integrated header; 224/56-point modular navigation; dark/light tokens; native pan/zoom surface; draggable fragments; temporary fragment editor; floating composer; conversation view; per-module guided prompts; custom modules; search; local manual notes; cached ASCII landscape. The study makes no model calls and does not write fragments into established lore. It is labeled accordingly.

Observed UI walkthrough: native launch with no OS title bar, typed answer → canvas fragment → next guide question, conversation view, custom Languages module, zoom to 90%, collapsed navigation. Final per-module guide and latest visual pass are being verified. Existing captures under `round1`/`round2` are rejected historical designs. `canvas-pass1` is the first current-direction inspection; it revealed a native Menu label issue and a card/composer overlap, both corrected in source.

## Checks and preserved functionality

- Optimized native build succeeded for the current UI.
- Core suite last passed 11 tests. A queued-cancellation regression was first observed failing, then passed after the fix.
- Independent read-only review identified queued cancellation, canonical context truncation and incomplete metadata restore; all three were corrected. Additional regression coverage is being finalized.
- Earlier application interactive verification remains documented in `docs/verification/WALKTHROUGH.md`, clearly distinguished from current UI scope.

No live provider call, browser test, public deployment, release, notarization or push is claimed. Immediate next work: finish visual/native interaction inspection, update evidence, and deliver the UI for owner review. Full-app integration waits for UI acceptance.
