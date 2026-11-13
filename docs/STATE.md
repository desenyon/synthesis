# Current state — UI first

## Latest owner direction

Pause application feature expansion. The previous light serif redesign was rejected. Match the latest three references with an infinite canvas, compact modular sidebar, a Zeron-style floating chat composer, guided world creation, fluid interaction and no separate native title bar.

## Current executable

`dist/Synthesis.app` now opens **CanvasDesignRoot**, an optimized SwiftUI/AppKit UI study. The prior application is preserved in source and commit `f35e968`; its lore/database/schema remain intact. This is not GPUI and contains no WebView or HTML preview.

Implemented UI: borderless native window with draggable integrated header; 224/56-point modular navigation; dark/light tokens; native pan/zoom surface; draggable fragments; temporary fragment editor; floating composer; conversation view; per-module guided prompts; custom modules; search; local manual notes; cached ASCII landscape. The study makes no model calls and does not write fragments into established lore. It is labeled accordingly.

Observed native UI walkthrough: no OS title bar; Power Systems → typed answer → “The source” fragment → next relevant question; fragment renamed to “Memory roots”; ⌘K filtered and reopened it; Universal History showed its own prompt/chips; Manual removed guide suggestions; ⌘N opened a new fragment; appearance and hide-chat controls changed their states. Earlier in this UI pass, conversation view, custom Languages module, zoom buttons and collapsed navigation were also exercised. The app was restarted and left open on the clean canvas for review.

Visual evidence: 24 actual native captures in `docs/verification/canvas-final` (six states × four viewports). Every final contact sheet was inspected, plus the main desktop capture at larger size. Logical sizes and 2× bitmap dimensions were asserted. Starter framing, world-menu label, light shadow, and composer overlap were corrected. At 390 points, the overview is intentionally zoomed out; select a module or zoom to read cards. This is a macOS compact-layout check, not a mobile app.

Verification limit: the native automation tool returned `noWindowsAvailable` for drag gestures against the borderless window after two attempts. Card dragging, background panning and window dragging are implemented but were not interaction-verified. No frame-rate or input-latency measurement is claimed. See [UI review evidence](verification/UI_REVIEW.md).

## Checks and preserved functionality

- `./scripts/build.sh release`: passed for the current UI.
- `swift format lint --strict --recursive Sources Tests Package.swift`: passed.
- `git diff --check`: passed.
- Core suite passed 13 tests in two suites. A queued-cancellation regression was first observed failing, then passed after the fix.
- Independent read-only review identified queued cancellation, canonical context truncation and incomplete metadata restore; all three were corrected. Regression coverage now includes canonical context projection and atomic metadata restore.
- Earlier application interactive verification remains documented in `docs/verification/WALKTHROUGH.md`, clearly distinguished from current UI scope.

No live provider call, browser test, public deployment, release, notarization or push is claimed. Immediate next milestone: owner visual review and direct trackpad/mouse gesture review. Full-app integration waits for UI acceptance.
