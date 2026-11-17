# Expansion #21 — universal command palette

⌘K finds selected-world lore (including body text, tags and aliases), saved scenes, maps, boards, conversations, category tools, commands, individual Settings controls and recent saved changes. Results open actual source records through Studio's save and ownership guards. Search remains local in Manual mode. Scene records use existing lore categories. Recent changes shows the latest saved state per object, not a complete edit log (#25).

Verification:

- `./scripts/check.sh`: strict Swift format lint, **219 tests / 55 suites**, optimized ad-hoc native build.
- Four focused palette tests passed. Coverage includes actual map/scene/settings/tool destinations, blocked navigation on save failure, current-source resolution, archive/world isolation, Manual behavior, unique result IDs and bounded keyboard indices.
- **30 final native states visually inspected**: `final/` contains 11 states at each of 1440×900 and 1024×768; `refined-narrow/` contains four at 520×620; `body/` contains body-only and ordinary text matches at both desktop sizes. All contact-sheet rows were inspected.
- Shared palette and fresh-source tests also retain command-before-capture ranking. No send occurs when preparing a new conversation.

The first captures exposed squeezed right-side metadata, oversized short lists and title-bar overlap in narrow windows. Final sizing uses actual rendered content height and stays below native controls. Result-ID changes reset scroll to the first actual match, including FTS-only results. Earlier `main/`, `narrow/`, `metadata-pass/` and `height-probe/` preserve iteration evidence; only the final sets above establish completion.

```sh
./scripts/check.sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=palette,palette-search,palette-maps,palette-scenes,palette-settings,palette-tools,palette-recent,light-palette-search,manual-palette-search,palette-long,palette-unmatched ./scripts/verify-ui.sh docs/verification/expansion-021/final
SYNTHESIS_CAPTURE_SIZES=520x620 SYNTHESIS_CAPTURE_STATES=palette-search,palette-settings,palette-long,palette-unmatched ./scripts/verify-ui.sh docs/verification/expansion-021/refined-narrow
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=palette-body,palette-search ./scripts/verify-ui.sh docs/verification/expansion-021/body
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-021/body --prune
```

No foreground activation/events, live model request, owner-data changes, owner-app restart or release. These checks do not establish physical keyboard feel, motion pacing or VoiceOver. #22 follows in numerical order; the full brief remains unfinished. AGENTS.md unchanged.
