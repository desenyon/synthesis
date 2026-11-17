# Expansion #28 — context-preserving Atlas navigation

Verified 2026-11-17 in the native application using isolated databases.

- Each map/universe retains image-relative framing, marker/region visibility and selected region/source. The view survives leaving for a document, tools or another map; normal restart and saved workspace layouts also restore it. Fit resets geometry only; resizing preserves the geographic center.
- Versioned local preferences never rewrite map lore or canon. Removed sources clear selection; archived maps are not revived. Invalid/foreign preferences preserve their original text and use a safe default. Modified replacements retain a recovery copy.
- `./scripts/check.sh`: strict Swift lint, **262 tests / 64 suites**, optimized ad-hoc build. Six new tests cover disk restart, world/map isolation, history/layout restoration and failed saves, archive/removal, corrupt/foreign preferences, anchor/resize geometry and mounting the actual Atlas view.
- Initial capture verification found that switching maps cleared the save callback without remounting Atlas. Callback registration now occurs during map loading; the mounted-view test includes consecutive map switches. `initial-capture-failure.log` records the finding.
- **27 final native states inspected**, all cells in `final/contact-*.jpg`: before/return, map switching, tool traversal, hidden regions/visible markers, split editor, Fit, light and Manual. Each was captured at 1440×900, 1024×768 and 720×800. **54 mounted-view assertions** verify restored state, current save callback, no active generation and unchanged source map/record. Before/return pairs show the same geographic framing and region, with no control overlaps at the inspected sizes.
- `docs/screenshots/atlas-context.png` is the 1440×900 returned view, copied before raw capture pruning.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=atlas-context-before,atlas-context-return,light-atlas-context-return,manual-atlas-context-return,atlas-context-map-switch,atlas-context-tools,atlas-context-layers,atlas-context-split,atlas-context-fit ./scripts/verify-ui.sh docs/verification/expansion-028/final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-028/final --prune
```

No foreground input, live model request, owner-data change, owner-app restart, migration, new dependency or release. Background geometry/state checks do not establish physical trackpad feel, animation pacing or VoiceOver behavior. AGENTS.md unchanged. Full session restoration is #33; continue #29 next.
