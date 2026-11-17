# Expansion #9 — contextual toolbars

Audited native WorkspaceBars and the embedded Canvas overlay. Atlas exposes map/marker/region/layer actions; Graph exposes relationship creation and neighbourhood transfer; Canvas exposes spatial drawing, selection, grouping, references and viewport tools. Editor formatting, Library filtering/creation, chronology tools and Review decisions remain local to their workspaces.

Fixed defects found in that audit: Atlas marker and region tools are mutually exclusive and reset when changing maps; marker placement has guarded Undo; already-placed records no longer produce an empty picker; marker controls use shared interaction styling. Graph creation always clears reverse-label/direction fields, regardless of entry point. Canvas drawing styles apply only to editable drawings, never lore cards, stored connections, images or frames; mixed selections expose only applicable properties.

Checks: `./scripts/check.sh` passed strict lint, **181 tests / 45 suites**, optimized native build. New Atlas state coverage exercises tool changes, cancellation, normalized/invalid points and the vertex bound. Canvas `npm run typecheck`, **15 tests**, and `npm run build` passed; style regressions cover record-owned elements, mixed selections, text and empty tools.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=canvas,light,graph,graph-selected,sheet-relation,atlas,atlas-drawing,atlas-placing,light-atlas-drawing,empty-atlas,timeline,library SYNTHESIS_CANVAS_AUDIT=1 ./scripts/verify-ui.sh docs/verification/expansion-009`: **24 captures**, both contact sheets inspected. **28 native/WebKit engine checks** passed, including actual embedded toolbar commands, drag/undo/redo, canon-owned relationship locks, reload/viewport, Manual mode and PNG export. PNG captures pruned after inspection.

No live model, foreground desktop events, release or AGENTS change. The engine audit uses injected WebKit events in the isolated background instance; it does not establish physical trackpad feel. Graph semantic zoom remains separately open at #15.
