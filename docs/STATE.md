# Current state — 2026-11-15

Canonical checkout: `/Users/desenyon/Developer/synthesis`, `main`. Native SwiftUI/AppKit + SQLite; Canvas alone uses the bundled offline Excalidraw engine. Development only, no release. The owner’s untracked `docs/DESIGN_AGENT_BRIEF.md` is preserved and is not part of the agent commit.

## This implementation

- Direct API transport, Keychain configuration and API settings removed. Claude Code / Codex subscriptions only. Authentication is checked before generation; API-only login is rejected. Manual cancels and blocks model work in the native core. Harness exits are awaited asynchronously, with bounded timeouts and termination escalation.
- Fixed stale proposal revisions overwriting newer writing. Ambiguous titles require stable IDs; archived source records cannot be changed through a pending proposal.
- Added bounded structured agent context for actual relationship tuples, events, board membership and positions, alongside source-backed lore retrieval. Reviewed operations now cover canvas creation, card placement/movement, existing-map markers, record links and draft rules. Existing canon approval remains separate.
- Live Canvas flushes before reviewed writes and reloads afterwards. A background integration check proves a reviewed placement appears in the actual Excalidraw scene. Existing images, unrelated shapes, outer groups and hidden relationships survive.
- Canvas has explicit Library capture, save-board-text-as-idea, a shared relationship inspector, and a Synthesis-owned drawing-style panel. Rule drafts can be read, added and edited in entity details. Graph and Atlas refresh on domain changes; large Graph layouts no longer run on the UI thread.
- New grouped sidebar, world lenses and conversation history; shared neutral charcoal/light tokens; upstream Lucide throughout authored native/web controls. Removed SF Symbol rendering and hand-drawn UI icon components. Compact editor details no longer silently disappear.
- Retired unused `legacy/web`, standalone `docs/design` previews, old API/placeholder and pixel-art components. Git preserves source history; ignored legacy files are archived outside the repository. No user lore or database was removed.

## Verification

- `./scripts/check.sh`: strict Swift formatting, **61 native tests / 7 suites**, optimized native development build passed. One intermediate overlapping build was invalidated by a source edit; the subsequent isolated full run passed.
- `cd CanvasWeb && npm run typecheck && npm test && npm run build`: TypeScript, **7 Node tests**, bundled production assets passed. Initial invocation from the repository root failed because the package is in CanvasWeb; the correct invocation passed.
- `python3 scripts/check-capture-isolation.py dist/Synthesis.app/Contents/MacOS/Synthesis`: passed absent/existing database refusal.
- Background `verify-ui.sh`: **18 engine/native integration checks** passed, including reviewed placement -> live engine, drag/undo/redo, relationship updates, image persistence, Manual controls and save-failure shutdown protection.
- 24 captures at 1440×900 and 1024×768 in `test-results/overhaul-final` cover Conversation home/thread, Canvas/companion/Manual/collapsed/light, Graph, Editor/light, settings and rule-sheet state. These are authored fixtures, not model output. Sheets render inline; native modal interaction is not verified. An initial rule-sheet capture at compact width exposed the missing inspector and led to a correction.
- Ten corrected-state captures and two final arrow captures were then inspected; compact details/rule-sheet layout and direction markers are corrected. The canonical app was reopened with existing data and live Canvas records were verified through accessibility. The general desktop screenshot omits remote WebKit pixels; use the engine-composited background evidence for rendering.
- See [INTEGRATION_OVERHAUL](INTEGRATION_OVERHAUL.md) for final visual follow-up and remaining acceptance limits. Automated testing stays in the background; no foreground pointer self-test or live model request was run.

## Not complete

This is a substantial integration repair and UI foundation pass, not an audit of every feature or exact parity with a missing latest attachment. Full autonomous tool loops, retained world-index snapshots, dense-board obstacle routing, export/live card parity, large-world benchmarks, physical trackpad/VoiceOver, crash recovery and deeper Timeline/Atlas interactions remain open. Rules Lab/scenario UI and rule canon review are not complete. Runtime image generation is absent; existing bundled illustrations remain optional.

Next: verify live subscription behavior with the new CLI flags in an explicitly authorized session; retain structured context traces; audit connection creation/style/capture actions through actual pointer input; then dense-board routing and large-world performance. Keep the existing native/engine boundary and user data.
