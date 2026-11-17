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

## Controls and scope

Open Settings from navigation or ⌘,. Search works across all sections; terms such as font, export and model find their corresponding controls. Searching for model or privacy opens connection details. Narrow windows use a section menu.

| Section | Controls | Scope |
| --- | --- | --- |
| General | Light/dark; expanded navigation; category counts; 0/5/12/20 recent chats; launch workspace; Library text previews | This Mac |
| Writing | 14/16/18/20 pt body text; 640/780/960 pt reading width; spellcheck; smart quotes; smart dashes; web-link detection; word count | This Mac |
| Assistant | Assisted/Manual; Codex/Claude Code; explicit sign-in check; optional model; Return or Command–Return to send | This Mac |
| This world | Name and description; cover; custom new-entity type; new-chat mode | Selected world; included in portable archive |
| Data | Import Markdown/text; open world file; export `.synthesis`, Markdown, JSON or images; open sample world | Selected world, or a fresh world on import |

Writing size affects unformatted documents and the Body formatting action, not saved rich-text font sizes. Spellcheck never enables automatic correction. Shift–Return adds a line in either send mode; entity mention selection and IME composition keep priority. A Manual launch preference cannot land on a disabled conversation: it opens Library instead.

Name/description save together; model and custom type have explicit Save controls. Other preferences save as changed. Changing worlds resets world fields to that world's data. A provider selection does not run a check; Check sign-in only requests subscription status. AI generation remains blocked in Manual by the core.

The obsolete Settings sheet, duplicated provider cards, unused saved-state flag and unused secure-field branch were removed. Onboarding shares the connection control without advanced model/privacy sections. No foreground UI automation or paid generation is part of this iteration.

## Verification

Final `./scripts/check.sh`: strict Swift lint, 94 tests in 21 suites, optimized ad-hoc development app. Tests cover restart persistence, invalid values, world isolation, archive privacy/rollback, identity transactions, launch defaults, native send keys and text configuration/RTF preservation, search and Manual/provider selection. Final 40 background captures were inspected across 1440×900, 1024×768 and 720×800; evidence in `verification/settings-refinement`. Native menus/file dialogs, foreground gestures/focus traversal and live provider calls remain unverified in this pass.

## Information density

General → Information density saves Compact, Comfortable or Immersive on this Mac. Navigation/history and Library rows change height; record thumbnails, Worlds/Mechanics cards, section padding and reading-edge spacing adapt immediately. Comfortable preserves the standard scale. Fonts stay readable at every density. Authored Canvas positions/sizes and document rich text are not rewritten. Missing or unknown older preference values safely use Comfortable.

## Per-universe navigation content

General → Navigation content opens customization for the current universe on this Mac. Reorder sections, hide unused World categories and pin/reorder collections in Favorites; search remains complete. Arrangement, Categories and Favorites use separate tabs in the shared sheet. Favorites orders/removes individual records and collections; closing a document tab does not remove its favorite. These preferences are not world exports or shared lore. [Sidebar usage and verification](SIDEBAR.md#customizable-navigation--expansion-23).
