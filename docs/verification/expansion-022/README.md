# Expansion #22 — advanced local search

The actual ⌘K palette and Library now share parameterized filters for record type/category, current status, tags, aliases, linked factions/entities and real creation/edit dates. Both requested examples work: `type:character faction:Tidekeepers` and `status:canon updated:7d`. Double quotes support multiword names. Filters intersect, and Library scopes apply before LIMIT. Invalid recognized filters cannot fall back to unrelated names or Capture actions. See [syntax and exact semantics](../../SEARCH.md).

Verification:

- `./scripts/check.sh`: strict Swift format lint, **227 tests / 57 suites**, optimized ad-hoc native build.
- Eight new tests cover real links in both directions, accented aliases, exact tags, quoted phrases, boundary dates, canon/draft distinctions, stale/archive/world isolation, injection-like values, invalid syntax, scope-before-limit, Manual navigation and query reset after world switching.
- The 2,000-record benchmark measured **66 ms for 20 ordinary searches** and **76 ms for 20 structured searches** in the final run. An earlier full check failed at 26 seconds: SQLite repeated the FTS scan for every record. EXPLAIN confirmed the plan, and materializing the FTS candidates fixed it. The existing scale assertion remains unchanged.
- **20 final native states visually inspected**: six palette states at each desktop size in `main/` (faction, canon/date, quoted relation, no results, light and Manual), invalid palette at both sizes in `refined/`, Library/results/errors at both sizes in `library/`, and two 520×620 states in `narrow/`. All contact sheets, including ten superseded intermediate frames, were inspected.
- Visual iteration removed unused height in the invalid-query palette. Capture fixtures reset the Library query so one capture cannot contaminate the next. README's palette image is the actual faction-filter result.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=search-faction,search-canon,search-quoted,search-invalid,search-no-results,light-search-faction,manual-search-faction,search-library,search-library-error ./scripts/verify-ui.sh docs/verification/expansion-022/main
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=search-invalid,search-library,search-library-error ./scripts/verify-ui.sh docs/verification/expansion-022/refined
SYNTHESIS_CAPTURE_SIZES=520x620 SYNTHESIS_CAPTURE_STATES=search-faction,search-invalid ./scripts/verify-ui.sh docs/verification/expansion-022/narrow
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=search-library,search-library-error ./scripts/verify-ui.sh docs/verification/expansion-022/library
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-022/library --prune
```

No dependencies, migration, live model request, foreground activation/events, owner-data changes, app restart or release. Captures establish rendering; native popover interaction, physical keyboard feel and VoiceOver were not retested. AGENTS.md unchanged. #23 follows; the complete expansion remains unfinished.
