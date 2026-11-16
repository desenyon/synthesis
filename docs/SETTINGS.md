# Settings refinement — 2026-11-15

Owner direction: simplify Settings, add useful controls, audit behavior, remove stale code, commit and push. Keep the existing native app and background verification. C2/C3's unrelated theme/composer redesign remains excluded.

## Direction

- Product: a personal worldbuilding studio whose tools adapt to the creator.
- Character: quiet, legible, deliberate.
- World: a writing desk and its organized reference shelves; retain black surfaces, Inter and Phosphor.
- Moments: the current world's saved cover and an actual writing preview.
- Signature: every control clearly belongs to this Mac or the selected world.

Use a searchable Settings workspace with General, Writing, Assistant, This world and Data sections. Desktop uses a narrow section list and an open settings column; compact layouts use a section menu. Aligned rows replace nested panels. Keep detailed provider isolation/install text behind a disclosure. The existing long form and its unused local state are removed after replacement. No generated decoration or standalone preview.

## Functional slice

Persist typed, validated writing/workspace preferences: body size for unformatted documents, reading width, spellcheck, smart quotes/dashes, automatic links, word count, Library summaries, sidebar counts, recent-conversation limit, launch workspace and message send shortcut. Preserve existing rich formatting. Add per-world new-entity category and new-conversation mode; include these world defaults in portable snapshots. Theme, assistance mode, provider/model, world name/description/cover and import/export remain functional. Search must find settings across sections. Choosing a provider must not start generation or silently check sign-in.

Verify defaults and invalid stored values, restart persistence, world isolation, portable defaults, send-key behavior and actual native editor configuration. Capture every section, search/results/empty, light and compact variants with isolated background data; inspect contact sheets and fix observed defects. Native file dialogs and live provider calls remain outside background verification.

Design audit method: adapted from **unslop** by [Damir Sokolovsky](https://heydamir.design/unslop), CC BY 4.0. The implementation uses Synthesis's native design system.
