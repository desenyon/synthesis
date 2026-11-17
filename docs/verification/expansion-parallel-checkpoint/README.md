# Parallel expansion checkpoint — 2026-11-17

The owner requested a saved, committed and pushed checkpoint so a new runtime can use the configured 50-agent limit. This is **not a release or acceptance of unfinished requirements**. The ledger remains **32 Verified, 11 In progress, 351 Open** out of 394.

## Work saved

| Requirements | Source state | Remaining acceptance |
| --- | --- | --- |
| #33 | Per-world sessions, editor positions, view context, newest unsent draft, guarded close/quit and separate-process audit | Final optimized three-size captures; physical interaction remains separate |
| #34 | Native nonactivating quick capture, launch-local shortcut, per-world scratch drafts, atomic retry-safe saving | Recapture corrected header/error sizing; physical global shortcut and focus restoration unverified |
| #35 | Typed addresses, guarded resolution/opening, composer insertion, initial drag sources and assistant context | Canvas/editor destinations, image/board source UI, link rendering, combined context budget and complete drop verification |
| #43–44 | Conversation prefix branching and lineage; world-owned prompt recipes with optimistic edits and Undo | Final optimized captures, including compact companion and modal states |
| #61–66 | Custom types, inheritance, typed/conditional fields, templates, property canon/history, search/context and portability | Native visual inspection of 26 states at three sizes; model-authored typed-field operations are not implemented |

## Executed checks

- `integration-check-1.log` through `integration-check-9.log` retain the earlier intermediate failures and repair attempts. They are diagnostic history, not final acceptance evidence.
- `check-10-passed.log`: strict Swift format lint, **326 native tests / 79 suites**, optimized build passed before the final import/export/reference fixes.
- `check-11-failed.log`: **329 tests / 79 suites, three failures**. Two assertions exposed PNG export loss; one exposed a changed source-reason label. These failures are retained, not hidden.
- `check-12-final.log`: strict Swift format lint, **334 native tests / 81 suites**, and the optimized ad-hoc native build all passed.
- `npm test && npm run typecheck` in `CanvasWeb/`: **18 tests passed** and TypeScript exited successfully at this checkpoint. `canvas-build.log` preserves the earlier successful bundle build; JavaScript source has not changed since it.
- `session-process.log`: rerun after check12; two separate executions of the final built native app wrote and restored the session exactly, with unchanged lore and Manual mode.
- Initial native appearance evidence: [25 main frames and six panel frames](../expansion-parallel-initial/README.md), from the debug executable at 1440×900. Both contact sheets were inspected. These are deliberately labeled preliminary and predate the corrected panel layout and schema views.

No final three-size capture run occurred before the owner's freeze. No live model request, foreground pointer/key test, owner-app restart, image generation, release or tag was performed.

## Failures found and disposition

| Finding | Disposition at checkpoint |
| --- | --- |
| Inspector choices could be lost before a debounced session save | Navigation/inspector checkpoints added; regressions pass |
| Fixed-delay session test could race the concurrent main-actor test suite | Test waits for observable persisted draft with a bounded deadline |
| Interrupted Graph layout could publish a completed signature without complete positions; a late layout could affect another universe | Publish signature with completed positions, guard world identity, clear incomplete signatures and cancel superseded tasks; regressions pass |
| Recipe/type/template/entity modal could retarget an unsaved form after changing universe | Frozen world scope and retained draft/error; regressions pass |
| Long working properties could hide accepted canon from context | Independent accepted/draft budgets with explicit truncation; regression passes |
| Tiny numeric values displayed as zero | Significant-digit/scientific display preserves finite values; numeric comparison regression passes |
| Imported retired schema/template/profile payloads lacked current size limits | Historical bounds and eight malformed archive cases added; rollback regressions pass |
| Schema images missing from world-image export | Connected to existing export with scoped, deduplicated collection |
| Valid grayscale/alpha PNG silently disappeared during AppKit re-encoding (check11) | Preserve validated PNG bytes; ImageIO converts other raster input and reports failure; PNG/JPEG/export regressions pass in check12 |
| Typed record references changed retrieval reason from “You referenced it” to “Attached by you” (check11) | Distinction restored; original regression passes in check12 |
| Proposal references could bypass exclusions through accepted record IDs, old endpoints or automatically created event sources | Include record-valued results, before-state dependencies and event-source ownership; three focused regressions pass in check12 |
| Quick-capture double header, growing error panel and weak shortcut contrast | Source corrected; final native captures still pending |
| Branch summary displayed Markdown syntax; short source thread could show unnecessary Latest action | Source corrected; final native captures still pending |
| Earlier integration compile/test failures: throwing test macros, mutable archive-table access, export-version expectation and missing reference fixture record | Repaired before check10; final shared checks cover the integrated source |

## Open defects and next actions

1. **#35 budget accounting:** explicit record attachments and non-record reference sources are currently bounded separately. Count the combined unique direct sources against the advertised context budget, without counting the same record twice.
2. **#35 editor:** add native text reference insertion and serialization/rendering for `synthesis://reference/...`. `MentionCodec` still handles the older record-link format. Preserve caret, Undo, failed-save guards and #33 position restoration.
3. **#35 Canvas:** implement reference cards/links using the existing offline bridge, with saved positions, fresh scoped source resolution, real Undo and flush/load verification. Do not invent entities or canon for an event/image/proposal reference.
4. **#35 sources:** expose board, Atlas image and Canvas image drags; focus the actual image element when opening its reference. Register the new UTI in the app bundle. Current source UI covers records, timeline events, entity artwork and proposals.
5. **#35 tests:** expand attachment-only/current-source/budget/foreign reference cases and verify actual native text/composer/Canvas drop precedence. Current privacy tests cover accepted record results, implicit event sources and reassigned event/map sources.
6. Run the prepared final captures; inspect all contact sheets and fix layout defects before marking #33/#34/#43/#44/#61–66 Verified. Do not treat the initial sheets as current-source proof.
7. Continue the other 351 Open requirements with explicit file ownership and independent checking. Do not infer that existing partial implementations satisfy them.
8. Toolchain warning retained in the build logs: SwiftPM's `--build-system native` option is deprecated. It did not fail the check; migrate the wrapper only with verification of the Swift Testing macro workaround. The earlier Canvas build also retains its bundler warnings in `canvas-build.log`.

## Prepared capture run

`capture-states.txt` preserves the exact 56-state selection: 11 session states, Canvas, six quick-capture states, 12 conversation/recipe states and 26 schema states. At three sizes it produces 168 main frames plus 18 quick-capture panels. Use a fresh output directory and inspect the resulting images before adding acceptance evidence.

```sh
SYNTHESIS_CAPTURE_SIZES='1440x900,1024x768,720x800' \
SYNTHESIS_CAPTURE_STATES="$(cat docs/verification/expansion-parallel-checkpoint/capture-states.txt)" \
SYNTHESIS_CANVAS_AUDIT=1 \
./scripts/verify-ui.sh docs/verification/expansion-parallel-final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-parallel-final
```

The native runner stays in the background with isolated data and blocked model transport. Physical global hotkeys, pointer/drop gestures, VoiceOver and subjective animation feel are not established by these captures. Do not activate the owner's working app to fill those gaps.
