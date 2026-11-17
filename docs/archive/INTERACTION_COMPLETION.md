# Owner interaction request — completion audit

This ledger tracks the full latest request, not just the Atlas follow-up. Prior implementation is evidence to inspect, not automatic acceptance. Keep the accepted appearance, user lore and explicit canon approval. Test with isolated data without taking desktop focus.

## Pass 1 — implementation and behavior

- [x] Sidebar: retain the accepted composition; verify only its horizontal compaction.
- [x] Navigation: deliberate workspace/editor/companion transitions; no stuck hover or surprise navigation changes.
- [x] Connections: stored relationships own their Canvas arrows; drawing/converting a new connection matches existing links and retains inspect/edit/remove controls.
- [x] Graph: coherent fit, button zoom, pointer zoom, close-node connections and selection without viewport jumps.
- [x] Privacy: subscription authentication only; no account memories, host instructions, tools or unrelated world data in model context.
- [x] Context: current workspace, selected records, active map/board and chronology branch reach the next request; changing pages makes no request.
- [x] Timeline: accepting parent/branch/period/event changes refreshes All history and the visible tree, preserving source links and canon.
- [x] Atlas/Canvas: accepted create/edit/placement changes appear immediately in the correct workspace and survive reload.
- [x] Review: per-change and batch acceptance, dependency failures, partial failures, rejection and stale data remain consistent and understandable.
- [x] Conversation: reliable send, streaming, citations, scrolling, Stop, retry/error handling, multiline entry and shared composer behavior across workspaces.
- [x] Agent controls: validate meaningful edits to existing world structures, not only creation; refresh all affected views through the shared model.

## Pass 2 — regression and actual rendering

- [x] Full native checks plus Canvas typecheck, tests and bundle build.
- [x] Background engine checks for actual Canvas create/connect/inspect/edit, persistence and approval refresh.
- [x] Inspect actual dark/light, expanded/collapsed, compact, Conversation, Canvas, Graph, Timeline, Atlas, Review and editor captures.
- [x] Revisit every item above after fixes and record remaining limitations explicitly.

## Pass 3 — delivery

- [x] Update README screenshots and factual implementation docs.
- [x] Review the complete diff for data integrity, untrusted inputs, privacy, stale code and regressions.
- [x] Commit/push only checked source. Verify the built artifact separately from source checks; do not mislabel the existing 0.0.1 archive as containing later commits.

Live subscription and physical foreground gesture checks are distinct from stand-in provider tests, native captures and synthetic engine events. Do not mark them as exercised unless actually run. Existing 0.0.1 is a development prerelease, not the future 1.0 public product launch.

## Evidence and limits of the ticks

Ticks above describe implemented behavior with the recorded code, test and settled-rendering coverage; they do not mean physical interaction or the complete product roadmap is accepted. The accepted sidebar remains 284pt. Native transitions respect Reduce Motion; no animation frame-pacing measurement or foreground hover/trackpad walkthrough was run. Graph/Canvas input geometry and the actual embedded Canvas engine were exercised; physical draw-to-convert and dense-board behavior remain open.

- Recovery/context: AgentRecoveryTests and ConversationFlowTests cover incomplete output, malformed proposals, unsent/retry drafts, continuation, current selection/editor/lane snapshots, no calls on navigation, native clip-view reading position and compact Canvas visibility.
- Workspace/review: WorkspaceEditTests and existing approval suites cover before-state rejection, cycles/foreign parents, imported pending proposal IDs, invalid-change disclosure, per-change/batch approval, rejection and canon protection. WorkspaceTests exercises affected Atlas refresh and All history reset through actual Studio acceptance.
- Geometry/rendering: GraphGeometryTests, 11 Node tests, 28 native/WebKit checks and 48 source captures plus 16 final packaged-app captures. Inspection found and repaired the Canvas reset-viewport bug and compact companion compositing. All four source/package contact sheets and README images were inspected.
- Privacy/live: per-instance provider/model caches cannot alter another app or shared defaults; unchanged least-privilege harness flags plus isolation tests; one approved real Codex fixture request passed in 9.312s, with cited prose and two staged changes. Nothing applied. No further live calls.
- Scope still incomplete: subscription image generation, full editable/coherent map geometry, spatial techniques/cosmology simulation and canon branch merging. Native foreground input/VoiceOver, live-CLI Stop and large-board performance are not certified.

Detailed logs, before/after and contact sheets: [interaction-0.0.2](../verification/interaction-0.0.2/README.md). Prior audit A2's physical requirement and unapproved C2/C3 are not ticked by this work.

Published [v0.0.2](https://github.com/desenyon/synthesis/releases/tag/v0.0.2) from `2b792637553ed6d940b0f9d5d4540a6b2b7694a8` after extracted-artifact verification. GitHub asset digest matches the tested ZIP; v0.0.1 remains unchanged.
