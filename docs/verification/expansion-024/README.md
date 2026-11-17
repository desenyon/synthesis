# Expansion #24 — favorite entities and collections

Verified 2026-11-17 in the native application. Record favorites extend the existing per-world navigation preference; no lore schema or approval changes.

- Shared pin controls in the editor/record inspector and menu actions in Library/document tabs. Favorites remain visible in expanded and collapsed navigation, independently of open tabs.
- Stable IDs resolve current names and revisions. Archive hides a favorite but preserves its address for restore. Foreign-world records cannot enter the visible favorites. Reordering skips unavailable records; removal changes only the navigation preference.
- The shared customization sheet has Arrangement, Categories and Favorites pages. Collections and records can be reordered/removed; long names truncate with full tooltips. Empty Favorites has a compact explanatory layout. A pinned collection has one active navigation highlight.
- `./scripts/check.sh` passed strict lint, **235 tests / 59 suites** and optimized ad-hoc native build. The four new Favorites tests also passed independently with `./scripts/test.sh --filter FavoritesTests`.
- Tests cover real disk reopening, tab independence, renames, no lore mutation, world isolation, archive/restore, current-version navigation, failed saves, Manual mode, bounded ordering around archived entries, stale-view writes and corrupt preference preservation.
- **26 final native states inspected:** 14 main states (Library, editor, inspector, rail, collection, light Library and Manual editor at both sizes), plus 12 refined Favorites/empty/long-title states at three sizes. Eight superseded main frames were also inspected. The refined empty dialog removes unused height; document metadata distinguishes a document filed in Places from a place entity. The long-title fixture is idempotent across sizes.
- README's `favorites.png` is the final actual 1440×900 Favorites manager scaled for the repository.

```sh
./scripts/test.sh --filter FavoritesTests
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=favorites-library,light-favorites-library,favorites-editor,manual-favorites-editor,favorites-inspector,favorites-rail,favorites-options,light-favorites-options,favorites-empty,favorites-long,favorites-collection ./scripts/verify-ui.sh docs/verification/expansion-024/main
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,1024x620 SYNTHESIS_CAPTURE_STATES=favorites-options,light-favorites-options,favorites-empty,favorites-long ./scripts/verify-ui.sh docs/verification/expansion-024/refined
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-024/refined --prune
```

No new dependency, migration, provider request, foreground activation/input, owner-data change, app restart or release. Rendering and state tests do not establish physical interaction, animation pacing or VoiceOver. AGENTS.md unchanged. #25 activity history follows; the complete expansion remains unfinished.
