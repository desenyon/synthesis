# Connected studio overhaul — 2026-11-15

Owner request: subscription-only Claude/Codex, deeper integration of Excalidraw with world records and agent actions, a new sidebar/design system with authored open-source icons, and removal of obsolete code.

## Execution order and acceptance

1. Subscription boundary: remove direct API adapter/settings; reject API-key harness authentication; retain cancellation and Manual enforcement. Test with fake executables, never private-world live calls.
2. Connected actions: stale proposals cannot overwrite writing; assistant receives typed relationships, events and board context. Reviewed proposals can operate on boards and links using stable world-scoped IDs. Flush the live scene before external board writes and reload it afterward. Canon remains separately approved.
3. UI: use the existing node reference and owner design brief as the available evidence. Rebuild the navigation into grouped workspaces, world lenses and conversation history, with coherent light/dark tokens and bundled Lucide icons throughout authored native/web UI. No newly attached reference arrived with this request; exact parity with that missing reference cannot be certified.
4. Canvas: retain the OSS scene engine/history, improve relationship geometry and expose source-aware actions. Distinguish board-only drawings from real records. Graph remains derived from the same relationships.
5. Verify: focused regression tests, complete native checks, canvas checks/build, isolated background captures and visual inspection. Update the feature acceptance ledger with remaining gaps; do not claim every feature audited.

## Confirmed findings, repaired in this pass

- API provider remains in router/settings and can be selected by stored preference.
- Harness status accepts generic/API-key sign-in, despite subscription intent.
- Status scratch-directory fallback can schedule removal of the shared temporary directory if creation fails.
- Proposal acceptance ignores `baseVersion`, allowing a stale AI edit to overwrite newer writing.
- Assistant context includes records/rules but no actual relationship tuples, chronology or board membership.
- Agent protocol supports only four actions; no canvas/atlas operations.
- Canvas DOM icons are hand-authored; native controls use SF Symbols, conflicting with the new icon direction.
- Live connection creation exists, but text/drawing tools are board-local and do not become lore. This distinction needs explicit UI and a save-to-lore action.

## Design implementation choices

Keep the native SwiftUI/AppKit app and offline Excalidraw engine. Replace authored icons with upstream Lucide artwork (licensed, version pinned). Adopt a flatter charcoal navigation surface, clearer groups, prominent New chat, compact rows and quiet active states. Shared tokens/components carry the changes across every workspace. Preserve native window controls and keyboard/accessibility labels.

## Observed verification

- Final `./scripts/check.sh`: strict lint, 61 native tests in 7 suites, optimized development app build passed. Canvas TypeScript, seven Node tests and bundle build passed. No direct API implementation/settings remain in native source.
- Background engine/native audit: 18 checks passed, including actual reviewed placement reaching the live engine after a flush. [Audit log](../verification/connected-studio/canvas-audit.log).
- 24 initial targeted screenshots at 1440×900 / 1024×768, then 10 correction captures and two final arrow captures. All contact sheets were inspected. Corrections addressed wrapping New chat, missing compact inspector, an off-centre/clipped rule sheet, looping tight curves and tiny direction markers. Final [Canvas light/dark](../verification/connected-studio/canvas-light-dark.jpg) and [compact workspaces](../verification/connected-studio/compact-workspaces.jpg) evidence is retained. Compact-sheet evidence predates only the final arrowhead sizing and new-rule source-link correction.
- Capture startup isolation checks passed. Testing used isolated databases and authored chat fixtures. No model calls or foreground pointer self-test. Modal sheet content was captured inline, not through native presentation.
- The canonical app was gracefully quit and reopened with existing data. Live accessibility inspection confirms the new navigation, existing Library records and linked Canvas cards; Fit changed the engine viewport. The general desktop screenshot omitted the remote WebKit layer, so foreground Canvas pixels are not certified by that screenshot. Background verification composites the engine's own real snapshot with the native window.

## Acceptance ledger

| Area | Verified scope | Remaining work |
| --- | --- | --- |
| Subscription-only | fake-executable auth rejection, isolation, exit/failure/cancellation/deadline tests | new CLI flags in a live subscription request |
| Canon and proposals | stale edits rejected, approval required, world isolation | atomic full change-set approval and wider invalid-dependency cases |
| Canvas integration | linked cards, shared relationships, image retention, scene save protection, reviewed placement reload | physical pointer capture/style/relationship inspection flows; dense obstacle routing; rotated endpoint routing |
| Agent context | records plus bounded relationship/event/board index; foreign world excluded | persist index snapshots; autonomous tool/retrieval loops |
| Navigation/icons | all authored native SF rendering replaced; 94 semantic Lucide aliases; real groups/history | full accessibility walkthrough; upstream/system-owned controls retain their own icons |
| Editor/rules | compact inspector and rule sheet render; native rules persistence tests | deeper manual rule editing journey, dedicated lab/scenarios/canon review |
| Graph | shared domain refresh; background layout above 80 nodes | quadratic-layout performance benchmark and dense labels |
| Atlas/Timeline | marker proposal persistence; source records preserved | multi-map navigation depth, marker dragging, eras and ordering |

This is not complete product acceptance or a claim to match the latest missing attachment exactly. Free drawing remains board-only until explicitly saved as a record. The assistant operates through the listed reviewed domain actions; it cannot control every arbitrary engine gesture or silently establish canon.

## Correction and follow-up — 2026-11-15

The earlier “remote WebKit pixels omitted” explanation did **not** establish that the native Canvas was visible. A later source audit found an opaque workspace background covering the WKWebView. Removing it restored actual native-window Canvas rendering, confirmed through a live screen capture and native Fit action. Engine-composited capture remains useful but cannot validate native occlusion. See STATE.md for the new Phosphor/Inter, black/glass, shared chat, portability and chronology checkpoint and its separate verification limits.
