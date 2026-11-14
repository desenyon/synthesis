# Background verification and graph engine — 2026-11-13

The handoff was reviewed at d02798b; no newer commits or uncommitted changes were present at session start.

## Implemented

- Knowledge Graph now uses MIT SwiftFlow for native graph rendering, curved labeled edges, handles, pan/zoom, fit and selection. `GraphEngine` preserves record IDs and filters by selected-world entity membership. Connections open an explicit labeled draft form; engine deletion cannot remove lore. Graph neighborhoods transfer to independent saved canvas boards. Canvas auto-arrange reuses the engine layout only on explicit action, with undo and persistence.
- SwiftFlow is pinned at 3515701fad73d3c6f8722bd65c22ef0813dc11a0 under Vendor/SwiftFlow. One documented resource lookup patch supports signed command-line app bundles. Upstream algorithms/interaction behavior are unchanged; MIT notices are included.
- `scripts/verify-background.sh` runs checks at reduced priority with two build workers by default. Captures use a separate temporary bundle, fresh DB, separate preferences, no Keychain lookup, a rejecting model transport and prohibited activation. Windows are never ordered. No menus, alerts, input automation, app restart or persistent watcher. Existing developer bundle remains untouched.

## Verification

23 Synthesis tests in 4 suites and 291 upstream SwiftFlow tests in 27 suites passed. Strict format lint and optimized native capture build passed. All 27 native captures completed at 1440×900, 1920×1080 and 1024×768, at 2× backing scale. All inspected in contact sheets, plus the full-size graph. The capture log reports `BACKGROUND VERIFIED: no visible window or activation`; every capture checked visibility, key status, current activation and recorded activation notifications.

Evidence and exact commands: docs/verification/BACKGROUND_GRAPH_REVIEW.md. The two negative startup-isolation checks passed; the separate optimized `dist/Synthesis-next.app` build and strict ad-hoc signature verification passed. The new app remains unopened. Build warnings are the known deprecated SwiftPM native build-system flag.

## Limits / next

No foreground interaction testing was performed, by owner request. Physical handle dragging, canvas gestures and companion resizing remain live-verification gaps; hidden captures and model/upstream tests are not a substitute. Canvas retains its existing custom gesture surface; only its explicit auto-layout uses SwiftFlow in this stage. Large graphs and long-running sessions need profiling. Live provider streaming and structured multi-record proposals remain untested/incomplete as previously documented.

AGENTS now records background-only unattended verification. No protected canon/privacy rule changed. No release, push, paid API call or current-app relaunch.
