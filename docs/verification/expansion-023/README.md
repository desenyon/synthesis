# Expansion #23 — customizable sidebar

Verified on 2026-11-17 in the canonical native app. No changes to lore, canon or the navigation destinations.

- Per-world, device-local section ordering, category visibility and pinned collections; Settings and sidebar context menus open the shared native manager.
- Arrangement moves sections and collections with labeled, bounded controls. Categories offers local search, pin/unpin and World visibility. Standard/custom entity categories and legacy aliases share consistent rows. Restore defaults is explicit.
- Preferences survive disk restart and world changes, merge latest independent edits and preserve unreadable/future-version data. Hidden categories remain in Library/search. Collection opening honors failed-save guards before clearing a previous Library query.
- `./scripts/check.sh` passed strict lint, **231 tests / 58 suites**, optimized ad-hoc native build. Four new tests cover disk/world isolation, no lore/mode mutation, corruption/partial values, stale view writes, aliases, long custom categories, search and navigation guards.
- **26 final actual-app captures inspected:** 14 main states (customized, default, empty, rail, long, light and Manual at both sizes), eight refined Arrangement/error/Settings states, and four final Categories states. All contact sheets were inspected, including ten superseded frames. Main's long custom-category fixture persists into its second window size; it is actual isolated test data.
- Initial screenshots hid category controls below the fold. The manager now separates Arrangement from Categories. The first refined category fixture reused an existing sheet and showed Arrangement; it was corrected to track capture changes, recaptured and inspected in `categories/`.
- README's navigation image is the final dark Categories state, scaled from the actual native window.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=navigation-customized,light-navigation-customized,manual-navigation-customized,navigation-options,light-navigation-options,navigation-empty,navigation-rail,navigation-default,navigation-error,navigation-long ./scripts/verify-ui.sh docs/verification/expansion-023/main
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x620 SYNTHESIS_CAPTURE_STATES=navigation-options,light-navigation-options,navigation-categories,light-navigation-categories,navigation-settings,navigation-error ./scripts/verify-ui.sh docs/verification/expansion-023/refined
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x620 SYNTHESIS_CAPTURE_STATES=navigation-categories,light-navigation-categories ./scripts/verify-ui.sh docs/verification/expansion-023/categories
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-023/categories --prune
```

No new dependency, migration, live subscription request, foreground activation/input, owner-data change, app restart or release. Background captures verify rendering, not physical interaction, animation pacing or VoiceOver. AGENTS.md unchanged. #24 individual favorites follows; the full expansion remains unfinished.
