# Search and commands

Press **⌘K** anywhere in the studio. Type a name or command, use ↑/↓ to select a result and Return to open it. Escape or clicking the backdrop closes the palette. Searching and navigation never send a model request; the same palette works in Manual mode.

The palette searches the selected universe's lore titles, text, categories, tags and aliases, named Canvas boards, Atlas maps, conversations and recent saved changes. Existing Scene/Scenes records are shown under Scenes. Tool destinations and category collections share the same search. Settings entries come from the actual Settings catalog and open the matching control. Other universes appear as explicit switch-world results; their content is not searched.

Examples:

- `Mira` — matching lore and recent changes involving Mira.
- `maps` or a map name — open an actual saved Atlas map.
- `scenes` — browse the scene collection and saved scenes.
- `power systems` — open the collection or a matching record.
- `spelling` or `settings spelling` — open the spelling control in Settings.
- `recent changes` — inspect recent saved entities, events, relationships, maps, boards or proposals.
- `knowledge graph`, `workspace layouts`, `light appearance` — open a tool or run a command.

Matches precede the optional Capture/Start a conversation actions. Starting a conversation only prepares a draft; it does not submit it. Opening a result validates its current source and respects unsaved-writing guards. Archived or other-world objects cannot be reopened through stale results.

Recent changes shows the latest saved state of up to 100 world objects, with at most 50 matching rows. For the retained edit log, use the **World activity history** command: searchable edits, approvals, connections and archived-source history. See [World activity](ACTIVITY.md). Existing scenes remain portable lore records; narrative-studio expansion requirements are separate.

## Structured lore search

Use the same syntax in ⌘K or the Library search field. The question-mark control offers examples that only fill the query. Combine words and filters; every condition must match. Structured queries return lore records, not commands or Capture actions. Clear the filters to search maps, settings and other palette destinations.

| Filter | Meaning |
| --- | --- |
| `type:character` | Category, with singular/plural aliases for characters, systems/factions, places/locations, power/magic systems, events and scenes. Custom category names also work. |
| `type:document`, `type:entity`, `type:idea` | Record kind. `category:` explicitly filters a category instead. |
| `status:canon` | Current state: `idea`, `draft`, `canon` or `hypothetical`. An edited draft with an older canon snapshot is a draft. |
| `faction:Tidekeepers` | Real, non-archived relationships in either direction to the named system/faction. This does not infer membership from prose; any stored relationship to that faction matches. |
| `related:"Mira Vale"` | Relationships in either direction to an entity of any category. Both relationship filters accept an exact title, alias or record ID. |
| `tag:"story arc"`, `alias:"La Gardienne"` | Exact tags and alternate names, case/diacritic-insensitive. Repeating a filter intersects the matches. |
| `updated:7d`, `created:2w` | Saved edits or creation in the preceding duration: positive `h`, `d` or `w`, through now. These are real elapsed UTC intervals, not fictional dates. |
| `updated:2026-11-01` | On or after midnight UTC on that calendar date, through now. |

Examples: `type:character faction:Tidekeepers`, `status:canon updated:7d`, `cartographer type:character`, `type:"Power systems" tag:limits`.

Double quotes preserve names with spaces and full-text phrases. Escape embedded double quotes with a backslash. Unknown prefixes are treated as ordinary text. A recognized filter with a missing/invalid value reports the problem and produces no fallback results. A literal phrase beginning with a filter name can be quoted in full, such as `"type:character"`.

Queries are limited to 2,048 characters and 64 terms/filters; result lists show up to 50 records. Search remains selected-world-only and excludes archives unless the Library's Archived view is explicitly selected. Library category/type tabs further narrow the result before the 50-record limit. The Canon tab includes drafts with a previous canon snapshot; explicit `status:canon` only matches records whose current state is canon. Archived relationships and linked targets never supply faction matches. Search is local, makes no model calls and does not change canon.
