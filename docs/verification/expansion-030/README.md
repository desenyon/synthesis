# Expansion #30 — keyboard-first creation

Verified 2026-11-17 in the actual native app using isolated data.

- Native File commands and the command palette expose New Entity (⌥⌘N) and Link Records (⇧⌘K). Existing Inspector (⌥⌘I), AI/Manual (⇧⌘M), Back (⌘[) and Forward (⌘]) remain available. Creation respects pending editor saves and cannot replace an open form.
- Graph and the global shortcut share a single linking form: source references for any two records, or typed draft relationships between entities with an optional independently named reverse. Searchable record pickers support Up/Down and Return. Source/target records are revalidated against the active world at save; archived/foreign sources and invalid labels are rejected. Canon and model requests are unchanged.
- `./scripts/check.sh` passed strict lint, **271 tests / 66 suites** and the optimized ad-hoc build. Four new tests cover command routes, failed saves, restart persistence, idempotent backlinks, atomic two-way relationships, archived/foreign records and context selection.
- **36 final frames inspected** in all three contact sheets at 1440×900, 1024×768 and 720×800: entity creation/result, link/reference forms, inspector, mode switching, empty world, dark/light/Manual variants and the shared form opened from Graph. Fields and actions remain visible at compact width.
- **99 native-menu assertions passed**. The capture runner sends key-equivalent events directly to the real NSMenu, verifies the resulting command/form state, Back/Forward traversal and unchanged original lore/mode. It asserts the test app remains inactive and its window nonkey. It posts no global input.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768,720x800 SYNTHESIS_CAPTURE_STATES=keyboard-entity,light-keyboard-entity,manual-keyboard-entity,keyboard-created,keyboard-link,light-keyboard-link,manual-keyboard-link,keyboard-reference,keyboard-inspector,keyboard-mode,keyboard-empty,sheet-relation ./scripts/verify-ui.sh docs/verification/expansion-030/final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-030/final --prune
```

README includes the actual linking form. No foreground input, live provider request, owner-app restart, migration, dependency or release. Background key-equivalent dispatch and captures do not establish physical typing, popover interaction, animation pacing or VoiceOver. AGENTS.md unchanged. Continue #31 next.
