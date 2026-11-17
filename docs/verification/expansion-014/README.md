# Expansion #14 — light-mode separation

Native Graph and offline Canvas share a cool `#E7ECF2` spatial base. White entity and floating tool surfaces remain distinct from the sidebar and document background. Stronger shared light text/boundary tokens, small shadows and quiet grid points improve separation without changing navigation or geometry. Canvas overlay colors come from `palette.ts`, matching export. Dark/OLED values are unchanged.

Checks observed: Canvas typecheck, **15 tests**, bundle build; `./scripts/check.sh`: strict lint, **196 tests / 50 suites**, optimized ad-hoc build. Capture run with `SYNTHESIS_CANVAS_AUDIT=1` passed **28 embedded-engine checks**, including real PNG export and repeated viewport/save cycles. PNG export was checked by the engine, not visually inspected in this pass.

Before captures: `light,light-editor,light-graph` at 1440×900. Final captures: `light,light-graph,light-editor,light-inspector-library,light-composer-attached,light-library,light-dashboard,canvas,graph-selected` at 1440×900 and 1024×768. All **18 final states** inspected in six contact-sheet rows; same-size before/after comparison inspected for the three original states. Dark 1440px Canvas reflects the audit's deliberately displaced saved viewport; the 1024px dark regression uses normal fitting. README preserves the final light Canvas. Individual PNGs pruned after sheets.

No foreground pointer/keyboard test, animation-pacing claim, model request or release. No change to data, canon, sidebar composition or the owner's running app.
