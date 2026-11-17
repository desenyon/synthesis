# Expansion #3 — design tokens

Typography.swift supplies semantic title, section, card, body, control, label and caption roles. Theme.swift owns colors, state/stroke opacity, geometry, four-point spacing and elevation roles. Shared components consume them; repeated font and radius literals in native workspaces were replaced with the corresponding role. Creator-authored rich text retains its formatting. Native surfaces and the offline engine remain separate renderers; the Canvas palette is its explicit theme adapter.

`./scripts/check.sh`: **175 tests / 42 suites**, strict lint and optimized build passed. No new behavior tests for a mechanical presentation refactor.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=editor,light-editor,library,light-library,settings,worlds,graph-selected,canvas ./scripts/verify-ui.sh docs/verification/expansion-003`: **16 captures**, both contact sheets inspected. Content, controls, titles and metadata remain aligned at both sizes; sidebar geometry unchanged. Background render evidence only; no foreground input or provider usage. PNGs pruned after inspection.
