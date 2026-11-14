# Reference fidelity and feature audit — 2026-11-13

Active checkout: `swift-falcon`, starting at `9b31fd5`; Claude’s implementation is retained. Owner reference: `ebe87125-Image_1.png` (graphite inset cards, colored ports, curved wires, image previews, compact composer and edge-docked tools). The unfinished core rules-lab work remains separate.

## Execution and acceptance

The first slice repairs the actual offline engine/native boundary and gives Canvas a custom Synthesis presentation. This is not an HTML preview, a new app, or a claim of exact pixel parity. Broad source/visual review covers all seven workspaces; deep interaction coverage remains incremental.

| Area | Finding | Implemented / observed | Remaining acceptance |
| --- | --- | --- | --- |
| Canvas presentation | Stock editor chrome and generic grouped text dominated | Live DOM cards with semantic ports, artwork, selection, tools and reference styling; engine pan, drag, undo/redo pass | Physical input, all tools/context menus, exact reference parity |
| Compact layout | Engine mobile toolbar reappeared beside companion | Both mobile/desktop chrome paths hidden; compact captures inspected | Full text at overview zoom is small; refine framing and focus navigation |
| Canvas saves | Delayed messages/loads could target a newer board | Session IDs on both boundaries, load epochs, flush before switch, visible timeout; stale-message tests and native scene save pass | Rapid switching/failure injection needs wider end-to-end coverage |
| Shutdown | Quit waited for flush but exited even after timeout | Window close and Quit honor the native save result; withheld-acknowledgement and recovery checks pass | Physical Close/Quit UI walkthrough |
| Save timeout | A timer from an earlier flush could fail a later one | One cancellable timer per flush; engine/native save check passes | Inject delayed/failed WebKit responses |
| Images | Reset could discard files; TIFF/HEIC were labeled PNG without conversion | Reset precedes file restore; valid conversion/bounds tests; image reload and native file persistence pass | Huge images, malformed metadata and interrupted imports |
| Relationships | Renames/archives left stale arrows | Synchronization refreshes labels and removes archived/retargeted edges; tests pass | Curve routing can bend awkwardly after binding adjustments; interactive port/edit/hide flows |
| Groups | Outermost group lookup could mix record content | Innermost card ownership; Node and actual engine grouping checks pass | Nested resize/rotation across revisions |
| Hit testing | Rotated cards used unrotated double-click bounds | Inverse-rotation hit test; regression passes | Physical double-click and keyboard access |
| Rendering | Overlay under engine; faded cards leaked duplicate text | Correct stacking and transparent underlying card parts; inspected screenshots | Export uses engine styling, not identical live DOM material |
| Artwork | No usable generated imagery | Two actual GPT assets, optional picker, explicit provenance; decoded in tests and shown on saved cards/maps | Runtime image generation absent; picker selection still needs physical interaction check |
| Atlas | Replacing map had no Undo; marker picker capped at 80 | Replacement Undo and uncapped searchable records; rendered map/markers inspected | Marker drag, multiple maps, repeated Undo interaction |
| Library/editor | Link picker capped at 60 | Shared search by title/category/alias; >90-record regression; editor/history/canon sheets inspected | Crash recovery; long document behavior and keyboard traversal |
| Timeline | Source menu capped at 80; actions hidden until hover | Searchable source picker and discoverable controls; timeline/empty state inspected | Era navigation, reorder, event canon state and scale |
| Conversation | Streaming and Stop not freshly observed | Existing cancellation/world-context/proposal tests pass; home/transcript/companion visual review | Controlled streamed UI and live Stop; long-rich-response stress |
| Manual mode | AI must remain independently gated | Existing transport-boundary tests pass; canvas contextual AI action disappears and returns appropriately | Physical switching during streamed UI; no new live provider requests were made |
| Graph | Native relationship-derived view, separate from Canvas | Graph/selected/empty/light renders inspected; existing layout tests pass | O(n²) layout scale, VoiceOver, large neighborhoods |
| Review/canon | Explicit decisions must remain deliberate | Existing approval tests pass; proposal/canon/check/diff sheets inspected | Fresh physical acceptance/rejection/undo walkthrough |
| Navigation/theme | Shared tokens, expanded/collapsed navigation | Desktop/compact and light/dark states inspected; no permanent assistant overlay | Full keyboard/VoiceOver and animation measurements |
| Capture isolation | Tests rebuilt running bundle; first-screen sheet could become key | Temporary bundle/database, no-model transport, non-key/main window and inline sheet-content snapshots; startup sentinel check | Never use the foreground self-test while the owner works |

## Evidence and exact checks

- `./scripts/test.sh`: **51 tests in 6 suites passed**. Includes preserved unfinished rules tests. Five new `CanvasBoundaryTests` cover sessions, TIFF conversion, bad/large inputs, bundled images and uncapped alias search.
- `swift format lint --strict --recursive Sources/SynthesisUI Sources/SynthesisApp Tests/SynthesisUITests`: passed.
- `cd CanvasWeb && npm run typecheck && npm test && npm run build`: passed, **6 Node tests**.
- `./scripts/build.sh release dist/Synthesis-review.app`: optimized development bundle, ad-hoc signed. Not a release and not opened over the owner’s work.
- `python3 scripts/check-capture-isolation.py dist/Synthesis-review.app/Contents/MacOS/Synthesis`: rejects absent or occupied database paths; sentinel bytes unchanged.
- `SYNTHESIS_CANVAS_AUDIT=1 ./scripts/verify-ui.sh …`: **17 engine/native checks**: custom chrome/layers, pan, zoom, drag by (40,25), undo, redo, relationship rename/archive, group isolation, image reload, Manual/Assisted action visibility, persisted scene/files, withheld save acknowledgement blocking shutdown and successful retry.
- Broad sweep: **78 actual native/WebKit captures** at 1440×900 and 1024×768 (`test-results/refinement-final`). All 20 four-image contact pages inspected. The final focused sweep has **20 captures**, covering canvas/companion/manual/light and six sheet-content states at both sizes; all five contact pages were inspected. Background sheet-content snapshots are inline renderings of the actual views; they do not certify modal interaction. Selected images and logs: [refinement evidence](refinement/).
- Full `./scripts/check.sh` **did not pass**: eight pre-existing strict-format errors in `Rules.swift`, `AgentEngine.swift`, `Portability.swift`. These owner edits were left intact. Independent tests/build passed; do not equate scoped lint with a full-project pass.

One artwork-only run caught `Background verification unexpectedly took focus` before writing a screenshot. Non-key/non-main windows alone did not prevent native modal activation; prohibited activation also prevented correct sheet rendering. The final runner uses accessory/non-key windows and renders the same sheet bodies inline during background snapshots, preserving normal modal behavior in production. The final runner also blocks framework activation requests, ignores mouse events and keeps capture windows below normal windows. Final evidence is in `test-results/refinement-final-safe`. Native modal behavior is not verified by these inline snapshots. This is recorded as a real defect, not hidden by rerunning.

Screenshots use authored, isolated fixture lore and conversations; no generated response is faked in production. Internal engine pointer events are not physical native UI tests. No foreground self-test, paid provider call, motion/FPS measurement or VoiceOver walkthrough was performed. Exact visual parity, full-product correctness and all-case performance remain open acceptance items.
