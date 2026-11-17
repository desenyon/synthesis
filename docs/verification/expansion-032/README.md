# Expansion #32 — focusable workspaces

Verified 2026-11-17 in the native app with isolated data.

⌥⌘F, the native View menu, command palette and shared workspace control enter temporary Focus. Navigation, inspectors, companion chat and unrelated document controls hide. Reading width, formatting, save/recovery errors, native chrome, AI/Manual and active-response Stop remain. Exit restores prior panel choices. Related split documents stay available. Explicit inspection reveals its controls again; Settings/Worlds exit Focus. No saved Focus preference or model request is introduced.

- `./scripts/check.sh`: strict lint, **279 tests / 68 suites**, optimized ad-hoc build passed. Four Focus tests cover saved layout/address/mode preservation, failed-save/modal guards, compact Canvas takeover and actual native-editor identity, caret, save and Undo across toggles.
- **33 final native frames inspected** in all three contact sheets: 1440×900, 1024×768, 720×800. Writing, light/Manual writing, restored/rail layouts, split/blank writing, Atlas, Graph, Canvas and Conversation. The initial 33 states were also inspected.
- **66 native-menu assertions** in the final capture log: local key-equivalent dispatch enters/exits Focus, checks native-editor identity, addresses, original records, panel choices and assistance mode. No global events or focus stealing.
- Refinements: a text Focus control avoids confusing it with Canvas Fit; viewport resizing no longer automatically rearranges Graph orientation. Full-resolution inspection confirmed the Graph was centered; an apparent offset in a contact sheet was not a reproduced framing defect.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=focus-writing,light-focus-writing,manual-focus-writing,focus-restored,focus-collapsed,focus-split,focus-blank,focus-atlas,focus-graph,focus-canvas,focus-conversation ./scripts/verify-ui.sh docs/verification/expansion-032/final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-032/final --prune
```

No foreground interaction, owner-app restart, live provider request or release. Native physical keyboard/trackpad feel, animation pacing and VoiceOver are not established by these background checks. No migration, dependency or AGENTS.md change. Continue #33, full session restoration.
