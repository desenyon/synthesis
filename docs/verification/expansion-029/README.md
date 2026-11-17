# Expansion #29 — one Back/Forward history

Verified 2026-11-17 in the actual native application with isolated data.

- History now restores entity subpages in either editor, Settings sections/search, Library category/query/filter/sort, Timeline branches, Review tabs/focused proposals and inspected objects, alongside existing map/board/chat/world addresses. Nested actions form one visit; repeated visits add nothing.
- Both editors must save first. Returning between tabs in a still-mounted editor retains its save callback. Optional removed/foreign inspected sources clear; source records resolve fresh and no canon or AI mode is restored from history.
- `./scripts/check.sh`: strict Swift lint, **267 tests / 65 suites**, optimized ad-hoc build. Four new navigation tests cover full traversal, save failures, same-mounted native editor callbacks, optional source validation and activity targets. One new core search regression covers all four Places aliases and title/body matches.
- Initial captures exposed a broken case/diacritic collation and compact Library overflow. Equality and sorting disagreed for `Places`/`places`, causing multi-alias IN filters to lose results. Folding before ordering fixes it. Search/filter controls now fit compact bars and filters scroll. A final icon pass replaced two unsupported names with bundled Phosphor glyphs.
- **33 final frames inspected**: all 30 cells in `final/contact-*.jpg`, then all three Library states in `library-refined/contact-*.jpg`, at 1440×900, 1024×768 and 720×800. **66 native-menu assertions** dispatch the real Back/Forward/Back actions, validate shortcut bindings/background isolation, compare restored addresses and preserve source data/mode. The returned Library shows all three matching Places records without overflow. Entity Sections, Review Checks, Settings Writing and the selected Timeline branch return correctly.
- `initial` retains the first contact sheets. `search-before-fix.log` and `library-before-fix.log` retain reproductions. README's `library-history.png` is the refined 1440×900 result.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=global-history-settings,light-global-history-settings,global-history-timeline,global-history-record,manual-global-history-record,global-history-review,global-history-map,global-history-canvas,global-history-graph,global-history-library ./scripts/verify-ui.sh docs/verification/expansion-029/final
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=global-history-library ./scripts/verify-ui.sh docs/verification/expansion-029/library-refined
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-029/final --prune
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-029/library-refined --prune
```

No foreground keyboard/pointer input, model request, owner-data changes, app restart, migration, dependency or release. Native menu dispatch and captures do not establish physical keyboard interaction, popover feel, animation pacing or VoiceOver. AGENTS.md unchanged. Continue #30 next; complete restart restoration remains #33.
