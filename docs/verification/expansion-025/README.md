# Expansion #25 — recent activity history

Verified 2026-11-17 in the real native application, against isolated databases.

- Migration 0015 records committed edits, approvals, connections and changes across the selected world. Failed transactions roll back their activity. Archive retains history; source opening resolves current data. No canon approval is inferred from opening a history row.
- Search, source/action filters, bounded keyset pagination, empty/error states and current-source navigation are available from Dashboard, ⌘K and the native View menu. Manual uses the same local history.
- Existing record revisions (including the original revisions table), relationship history and rule snapshots reconstruct once. Other old objects have explicitly labeled saved-state baselines. Missing historical edits are not invented.
- Portable v9 / JSON12 include history. Imports remap and validate source addresses, suppress synthetic creation entries and add one import entry. Older files reconstruct available history. Malformed imports roll back completely.
- `./scripts/check.sh` passed strict lint, **244 tests / 61 suites** and optimized ad-hoc build. Nine added tests cover actual mutations, failures, stale edits, world isolation, pagination while new edits arrive, literal searches, disk migration, archive round trips, invalid imports, failed-save navigation and Manual mode.
- **22 final captures inspected:** 20 in `refined` (history, light, Manual, approvals, relationships, search, no matches, archives, Dashboard and reconstruction at 1440×900 and 1024×620), plus two dark/light 720×800 states in `narrow`. All contact-sheet cells were inspected. Twenty initial frames in `main` were also inspected.
- Initial captures exposed board saves crowding history. `BoardActivity` now compares JSON semantically and omits viewport/engine bookkeeping, while preserving all saved board content and actual arrangement changes. The focused regression and final captures confirm the correction.
- README `activity.png` comes from final `changes-search` at 1440×900.

```sh
./scripts/test.sh --filter WorldChangeHistoryTests
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x620 SYNTHESIS_CAPTURE_STATES=changes-history,light-changes-history,manual-changes-history,changes-approvals,changes-relations,changes-search,changes-empty,changes-archived,changes-dashboard,changes-reconstructed ./scripts/verify-ui.sh docs/verification/expansion-025/refined
SYNTHESIS_CAPTURE_SIZES=720x800 SYNTHESIS_CAPTURE_STATES=changes-history,light-changes-history ./scripts/verify-ui.sh docs/verification/expansion-025/narrow
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-025/refined --prune
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-025/narrow --prune
```

The focused core suite initially passed six tests; the final full check includes its seventh board-noise test and two UI navigation tests. No live provider request, foreground input, owner-data access, owner-app restart or release. Captures establish rendering, not physical input, animation pacing or VoiceOver. The history sheet fits the compact capture; the underlying Library toolbar still exceeds the 720pt capture width. AGENTS.md unchanged. Continue #26; the full expansion is not complete.
