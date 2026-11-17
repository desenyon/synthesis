# Expansion #19 — resizable native panels

Navigation, both inspectors and docked/floating conversations now share a native splitter. Drag the edge to resize; double-click resets the default. Focused dividers support arrow-key adjustment and native accessibility increment/decrement. Settings → General also exposes numeric controls. Defaults remain 284 / 300 / 400 points; bounds are 240–360 / 260–480 / 320–600. Collapsing navigation preserves its expanded width.

Widths persist on this Mac and travel with saved workspace layouts. Transient drags avoid database writes until completion. Old layouts decode without new width fields. Invalid preferences recover safely. A small window constrains the display without overwriting the preferred size. Inspectors float when docking would leave too little workspace; the editor reserves 480 points for writing and its formatting controls. Canvas retains its narrow-window conversation takeover.

`./scripts/check.sh`: strict lint, **215 tests / 54 suites**, optimized ad-hoc native build. Five panel tests cover disk restart, corrupt/out-of-range preferences, transient versus committed changes, legacy layouts, native mouse event handlers, arrow keys, accessibility and bounds. These invoke handlers directly on unattached views; they do not claim physical pointer routing.

The isolated native capture runner also exercises the actual rendered dividers' accessibility actions: **8 checks** cover nine-point hit areas, decrement/increment, persistence and no activation at 1440×900 and 1024×768. A separate scroll regression checks all three independent regions at both sizes. No foreground events, live provider call or owner-app restart.

Final visual evidence is in `refined/` (20 states), `narrow/` (2 states at 720×800), and `scroll/` (2 regression states). Contact sheets were inspected. The earlier `probe/` and `final/` sheets preserve iteration evidence: a narrow writing-column issue led to the floating-inspector correction. Native accessibility alone did not expose the first SwiftUI-only divider, so it was replaced with an AppKit splitter. Animation feel and a VoiceOver session are not established by background captures.

Commands:

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=panels-default,panels-narrow,panels-wide,light-panels-wide,manual-panels-wide,panels-collapsed,panels-inspector-wide,panels-companion-wide,panels-canvas-companion,panels-settings ./scripts/verify-ui.sh docs/verification/expansion-019/refined
SYNTHESIS_CAPTURE_SIZES=720x800 SYNTHESIS_CAPTURE_STATES=panels-wide,panels-canvas-companion ./scripts/verify-ui.sh docs/verification/expansion-019/narrow
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=scroll-regions-document ./scripts/verify-ui.sh docs/verification/expansion-019/scroll
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-019/refined --prune
```

The rest of the expansion brief remains unfinished; #20 follows.
