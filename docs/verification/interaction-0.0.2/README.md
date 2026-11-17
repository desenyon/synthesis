# 0.0.2 interaction verification — 2026-11-16

All tests/captures used isolated data. No owner database was edited and no foreground window automation or app restart occurred. The two contact sheets show 48 settled states of the actual native app at 1440×900 and 1024×768. Both were inspected; Conversation, loading/interrupted responses, Graph and selection, Canvas with/without companion, Manual, Timeline/tree/edit sheet, Atlas, Review diffs, editor, Library companion, Settings, Mechanics, collapsed navigation and light variants are included.

- `./scripts/check.sh`: strict Swift formatting lint; **140 tests / 30 suites passed**; optimized native build. Logs contain SDK build-system deprecation warnings, no failing checks.
- `npm --prefix CanvasWeb run typecheck`, `test`, `build`: TypeScript passed; **11 tests passed**; production bundle rebuilt and committed.
- `SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_STATES=... SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 ./scripts/verify-ui.sh /tmp/synthesis-interaction-final`: **27 actual WebKit/native integration checks passed**. Includes custom drag, zoom, undo/redo, locked relationship inspection/rename/archive, image reload, export PNG, Manual action removal, save acknowledgement failure/recovery, reviewed placement and viewport stability.
- `SYNTHESIS_LIVE_HARNESS=codex ./scripts/test.sh --filter LiveHarnessTests`: **one owner-approved real request passed** in 9.312 seconds. In-memory fixture universe; source-linked prose and create_record/relate proposal; no changes applied. Codex emitted one completed update, not token-by-token streaming. No second live request was made.

The first visual pass caught a viewport reset even though card-coordinate tests passed. `before-canvas-reload.png` shows the issue. `after-canvas-reload.png` shows the committed-viewport fix and intervening-card relationship detour. Readiness now follows React state commit. Three regression assertions cover saved viewport restoration, reviewed placement viewport and repeated reload. Compact companion capture also stopped compositing a hidden Canvas behind the conversation.

Commands to rebuild sheets: `uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-interaction-final`. README screenshots were copied only after inspection. The capture runner's macOS sandbox-extension diagnostic did not prevent WebKit capture or engine tests.

Limits: no physical trackpad/VoiceOver test or measured animation frame pacing; no large dense-board stress result. Native clip-view scroll behavior and core cancellation are tested without foreground input. The live Codex request verifies the transport and staging path, not cancellation of a live CLI or the native chat UI. No arbitrary executable UI, on-demand subscription image generation, coherent editable map geography, canon branch merging or complete spatial techniques simulator is claimed. The distribution remains ad-hoc signed and not notarized.


## Extracted distribution verification

The final `Synthesis-0.0.2-macos-arm64.zip` was extracted into a fresh temporary folder. `codesign --verify --deep --strict` passed; its executable matched the checked local bundle byte for byte. The extracted executable ran against a fresh fixture database with `SYNTHESIS_CANVAS_AUDIT=1`, eight capture states and both viewport sizes. **28 engine/native checks passed; all 16 package captures were inspected in `package-contact-1440x900.jpg` and `package-contact-1024x768.jpg`.** `package-capture.log` records this final run.

The additional check covers first-fit acknowledgement before native persistence; `first-fit-red.log` records its failure before repair. The source capture log remains the historical 27-check/48-state pass and has not been relabelled. Final native checks also include independent provider caches and untouched host defaults. No extra live model request or foreground interaction occurred.

ZIP SHA-256: `c86f0c3eba8046612d1f3441b22d2aa065b6bddc1bb74bb4e35a440c172e4a89`.

Published [v0.0.2](https://github.com/desenyon/synthesis/releases/tag/v0.0.2) from `2b792637553ed6d940b0f9d5d4540a6b2b7694a8`. GitHub confirms `prerelease: true`, `draft: false`, three assets and the same ZIP SHA-256 above. Remote v0.0.1 still points to its original commit.
