# Expansion #4 — typography hierarchy

Entity pages use a 32pt semibold Inter identity heading. Overview keeps it editable; Sections and Mechanics retain that identity when switching tabs. Metadata and tool actions use 12–14pt roles; section/card headings remain subordinate. Long names wrap within content and truncate in workspace bars. Authored rich-text sizes are unchanged.

`./scripts/check.sh`: **175 tests / 42 suites**, strict lint and optimized build passed.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=editor,light-editor,editor-long,light-editor-long,sections,light-sections,mechanics,light-mechanics ./scripts/verify-ui.sh docs/verification/expansion-004`: **16 captures**, both sheets inspected. The long-name fixture uses an isolated saved record. At narrow width the full title wraps without overlapping metadata or controls. Background rendering only; no physical input or provider call. Source PNGs pruned after inspection.
