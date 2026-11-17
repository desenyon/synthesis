# Expansion #31 — custom home views

Verified 2026-11-17 in the actual native app with isolated data.

Settings offers Last workspace, Conversation, Atlas, Dashboard, Canvas, Library and Your worlds. Core validation and the menu share one catalog; existing preference strings remain compatible. The selected home applies next launch without navigating the current session. Direct chat routes now update Last workspace through the same boundary as sidebar/board/search/history navigation. Failed saves and companion chat preserve the underlying destination.

- `./scripts/check.sh`: strict lint, **275 tests / 67 suites**, optimized ad-hoc build passed. Four new tests cover every home in both modes through a separate on-disk database connection, direct navigation/save failures, world isolation, archive exclusion, defaults/corrupt-value fallback and zero model requests through an injected recording transport.
- **33 native frames inspected**, all cells in the three contact sheets at 1440×900, 1024×768 and 720×800. Includes the saved setting in dark/light, Atlas in dark/light/Manual, Conversation, Manual fallback to Library, Canvas, Dashboard, remembered Graph and an empty world's Atlas.
- Each frame mounts a **new Studio/ConnectedRoot reconstructed from persisted preferences**. **33 startup assertions** check expected workspace, selected world, saved choice, unchanged original records and idle state. No fixture directly assigns the startup destination. This is process-local root reconstruction, paired with disk-reopen tests; it is not a foreground app-quit/launch walkthrough.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=startup-settings,light-startup-settings,startup-atlas,light-startup-atlas,manual-startup-atlas,startup-conversation,manual-startup-conversation,startup-canvas,startup-dashboard,startup-last,startup-empty-atlas ./scripts/verify-ui.sh docs/verification/expansion-031/final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-031/final --prune
```

Manual never enables itself or makes a request; Conversation falls back to Library while Manual is saved. Startup stays device-local, outside portable lore. No migration, dependency, live provider request, foreground input, owner-app restart or release. Native popover interaction and VoiceOver remain unverified. AGENTS.md unchanged. Continue #32; full session restoration is #33.
