# Expansion #6 — adjustable information density

Settings → General → Information density selects Compact, Comfortable or Immersive. A shared density environment changes navigation/history row heights, Library row/thumbnail sizes, content insets, Worlds/Mechanics grid widths and card padding, and entity-section spacing. Comfortable is the default. Manual and assisted workspaces share the setting. Presentation preferences never resize creator-arranged Canvas elements or rewrite rich text.

`./scripts/check.sh`: **175 tests / 42 suites**, strict lint, optimized build. The disk-reopen preference regression now includes density; malformed/future values use Comfortable. No model calls are involved.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=library,compact-library,immersive-library,light-compact-library,light-immersive-library,compact-worlds,immersive-worlds,compact-mechanics,immersive-mechanics,compact-sections,immersive-sections,settings ./scripts/verify-ui.sh docs/verification/expansion-006`: **24 captures**, both sheets inspected. At narrow width immersive grids become one column; navigation and content scroll independently. Typography remains readable without scaling down. PNGs pruned after inspection. Background rendering and persistence tests do not establish foreground interaction feel.
