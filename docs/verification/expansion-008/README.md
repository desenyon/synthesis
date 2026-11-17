# Expansion #8 — restrained microinteractions

Shared feedback and panel transition tokens cover entity selection, relationship navigation, inspectors, companions and proposal review. Segmented controls fade rather than sliding a highlight. All changed transitions respect Reduce Motion. A shared hover lifecycle clears transient state when navigation, selection, availability or window/app focus changes; controls retain their dimensions.

`./scripts/check.sh`: strict Swift lint, **180 tests / 44 suites**, optimized native build passed. The new unwindowed `NSHostingView` regression checks navigation, disabled and focus-loss paths without activating a window. Existing persistence and approval tests remain passing.

`SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=graph,graph-selected,editor,sections,graph-companion,review,review-canon,toast,light-graph,light-editor ./scripts/verify-ui.sh docs/verification/expansion-008`: **20 captures**. Inspection exposed a runner that cleared its named toast state, then a toast covering the compact composer; both were corrected and recaptured. Final contact sheets inspected at both sizes. PNGs pruned after inspection.

Captures show settled states; physical pointer feel, frame pacing and VoiceOver remain unverified. No live provider request, foreground interaction, personal-lore access, release or AGENTS change.
