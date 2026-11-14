# Background verification and SwiftFlow review — 2026-11-13

## What changed

Unattended verification no longer activates the application. `scripts/verify-background.sh` runs strict lint, app tests, an optimized build, fail-closed capture startup checks and native screenshot captures. Default build concurrency is two workers at reduced priority. The capture process has prohibited activation, a never-ordered window, isolated temporary bundle/database/preferences and a rejecting model transport. It does not open browser tabs, send desktop input, restart the user's app or read provider credentials. Each capture checks visible/key/active state; an observer detects transient activation. Failure paths exit instead of opening modal alerts.

Knowledge Graph now runs on the MIT SwiftFlow engine: native nodes, curved labeled edges, arrowheads, handles, selection, pan/zoom and fit. Engine connections enter Synthesis's labeled draft form. Record deletion is disabled at the engine boundary; semantic editing/archive remains validated in WorkspaceStore, with canonical relations protected. The pure GraphEngine adapter filters selected-world entity membership, projects stable IDs and provides deterministic layout/neighborhood transfer. Explicit canvas auto-arrange uses the same layout utilities and retains undo/persistence. Existing manually curated card gestures remain Synthesis code.

SwiftFlow source/tests are pinned at `3515701fad73d3c6f8722bd65c22ef0813dc11a0`. The sole local dependency patch resolves localized resources from the signed app's Contents/Resources before SwiftPM's fallback. Upstream source provenance and MIT license are retained in Vendor/SwiftFlow; notices ship inside the app.

## Executed checks

- `./scripts/verify-background.sh test-results/background-final`: strict format lint; 23 Synthesis tests in 4 suites; optimized build; two negative startup-isolation checks; 27 native captures.
- `./scripts/test.sh --package-path Vendor/SwiftFlow`: 291 tests in 27 suites passed, including connection, layout, viewport, geometry and keyboard-monitor behavior. These are upstream tests, not a claim of physical gesture acceptance in Synthesis.
- `python3 scripts/check-capture-isolation.py dist/Synthesis-next.app/Contents/MacOS/Synthesis`: capture rejects a missing isolated DB path; rejects and preserves an existing file. No normal database is opened.
- `codesign --verify --deep --strict dist/Synthesis-next.app`: passed for the separate ad-hoc development bundle.
- `zsh -n scripts/build.sh scripts/verify-ui.sh scripts/verify-background.sh` and `git diff --check`: passed.

Captured nine actual app states at 1440×900, 1920×1080 and 1024×768 (2× backing scale): conversation home, persisted authored-example thread, canvas, companion, Manual, collapsed navigation, light theme, graph and library. Contact sheets were inspected, plus the full graph. The capture log records `BACKGROUND VERIFIED: no visible window or activation`.

- [1440 contact sheet](background-graph/contact-1440x900.jpg)
- [1920 contact sheet](background-graph/contact-1920x1080.jpg)
- [1024 contact sheet](background-graph/contact-1024x768.jpg)
- [Native graph](background-graph/graph-1440x900.png)
- [Capture log](background-graph/capture.log)
- [Verification log](background-graph/verification.log)
- [Upstream test log](background-graph/upstream-tests.log)

## Limits

No foreground click/drag test, current-app relaunch, paid provider call, release or push. Hidden rendering does not prove physical handle dragging, native canvas gestures, companion resizing or large-world performance. Existing canon/persistence tests remain passing. The earlier connected-workspace review documents previously observed interactive flows; they were not repeated on the owner's desktop this session. Narrow graph fit can reduce text scale; zoom is available and large-world density still needs profiling.

The replacement build is `dist/Synthesis-next.app`, left unopened. The current `dist/Synthesis.app` bundle and running app were not replaced by verification. AGENTS now makes background verification the unattended default; no canon/privacy rule was relaxed.
