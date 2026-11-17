# Expansion #5 — category identity

Canvas overlay uses `displayPalette` and `categoryColor`, replacing a second hardcoded pastel map. Native Graph and Canvas show matching Phosphor category symbols; existing native record tiles and references use the same identity. Historical events/History records use calendar symbols and muted blue-gray. Visual aliases cover singular/plural character, faction/system, location/place, magic/power system and event/history without rewriting creator categories. Unknown categories retain the normal accent and document icon.

`./scripts/check.sh`: **175 tests / 42 suites**, strict lint, optimized build. Canvas typecheck and bundle build passed; `npm test`: **14 tests**, including category alias consistency and 4.5:1 text contrast against each appearance surface. The existing display/export inversion test remains green.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=canvas,light,graph,light-graph,library,light-library,timeline ./scripts/verify-ui.sh docs/verification/expansion-005`: **14 captures**, both sheets inspected. Dark/light Canvas, native Graph and record rows show the same muted identities; Timeline and its source records agree. PNGs pruned after inspection. Background render evidence only, no foreground interaction or model usage.
