# Expansion #27 — drag real records into workspaces

Verified 2026-11-17 in the native application and offline Canvas engine, against isolated data.

- Search lore results, sidebar Favorites and unarchived Library rows use one native record drag. Targets open a record in the main/secondary editor, create a secondary pane, or place its linked card on the current Canvas. The palette remains mounted but steps aside during a drag; cancellation restores it. Compact composers hide without changing pane geometry.
- An own-process item provider contains only version/world/record IDs. Current-source lookup and delivery guards reject malformed, foreign, archived, cancelled or stale addresses. Both editor save guards remain in force. Manual mode needs no provider. Source lore and canon stay unchanged.
- Canvas converts the drop point with its live pan and zoom. An existing record card moves with its grouped content/artwork rather than duplicating; stored relationships remain authoritative. Engine Undo reverses the placement/move. Native confirmation waits for the current board generation's save acknowledgment.
- `./scripts/check.sh`: strict Swift lint, **256 tests / 63 suites**, optimized ad-hoc build. Five new native tests cover the item-provider payload, latest-source resolution, both panes, save failures, cancellation, late/foreign/archived delivery, unavailable Canvas and no lore mutation. App Info.plist passes `plutil -lint` with the record-reference type declaration.
- Canvas `npm test`: **17 tests**; typecheck and bundle build passed. **49 embedded-engine checks** passed in `final/capture.log`, including pan/zoom coordinates, group selection, duplicate prevention, Undo, native bridge persistence and unchanged source lore after reload.
- **33 final native frames inspected**: every cell in the three `final/contact-*.jpg` sheets (11 states at 1440×900, 1024×768 and 720×800). The initial 22 frames in `main` were also inspected. That pass exposed the new-pane target covering the compact composer; final captures show the corrected transient state. The engine audit now restores its prior board before appearance captures.
- README image copied from `final/drag-targets-1440x900.png` before pruning raw PNGs.

```sh
./scripts/check.sh
npm --prefix CanvasWeb test
npm --prefix CanvasWeb run typecheck
npm --prefix CanvasWeb run build
SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=canvas,drag-search,light-drag-search,drag-favorites,drag-targets,light-drag-targets,manual-drag-targets,drag-second-pane,drag-opened,light-drag-opened,drag-canvas ./scripts/verify-ui.sh docs/verification/expansion-027/final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-027/final --prune
plutil -lint dist/Synthesis.app/Contents/Info.plist
```

No live provider call, foreground pointer/keyboard events, owner-data change, owner-app restart or release. Background state/engine checks and captures do not establish physical OS drag feel, animation pacing or VoiceOver. Broader image/event/proposal transfer is #35. AGENTS.md unchanged. Continue #28; the full expansion remains unfinished.
