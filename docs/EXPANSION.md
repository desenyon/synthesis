# Expansion implementation ledger

Owner request, 2026-11-17: implement every requirement and account for each one individually. The previous composer slices did **not** complete this brief.

Source: [complete supplied brief](EXPANSION_SOURCE.md), SHA-256 `248e5cf11387658a131f6f31732c105f01372c0b76d7a7e1bff3667fcfa530d2`. Exactly **394 numbered requirements**, preserved below. Unnumbered composer interactions, modules and the final connected workflow remain part of acceptance.

## Completion rules

- **Open**: not yet audited or not fully implemented. Partial functionality never counts as complete.
- **In progress**: implementation or verification underway.
- **Verified**: source, meaningful checks and relevant inspected captures linked in Evidence.
- **Decision needed**: a specific conflict or external prerequisite; never counted as done.
- Work in numerical order, adding shared prerequisites where needed. Run repository checks, inspect native captures, log progress, commit and push. Test quietly against isolated data.
- Preserve canon approvals, portable data, native stack and subscription isolation. No unrequested release or private-world publication. The new graphite/OLED direction supersedes the old content-background choice.

## Numbered requirements

| # | Requirement and acceptance | Status | Evidence / remaining work |
| --- | --- | --- | --- |
| 1 | **Replace pure-black content backgrounds.** Use a dark graphite base, slightly lighter sidebars, and distinct raised surfaces. Preserve true black as an optional OLED theme. | Verified | [#001 evidence](verification/expansion-001/README.md): persisted graphite/OLED option, native/Canvas/export palette, 175 native + 13 Canvas tests, 14 captures. |
| 2 | **Introduce restrained frosted-glass surfaces.** Use translucent, lightly blurred treatments for floating toolbars, popovers, inspectors and the AI composer. Avoid putting glass behind every panel. | Verified | [#002 evidence](verification/expansion-002/README.md): native vibrancy shared by floating controls, inspectors, menus and composers; opaque fallback; 175 tests and 16 inspected captures. |
| 3 | **Create a proper design-token system.** Standardize surface colors, stroke opacity, spacing, typography, corner radii, shadows and interaction states. | Verified | [#003 evidence](verification/expansion-003/README.md): semantic type roles, shared geometry/spacing/elevation and existing surface/state tokens; 175 tests and 16 inspected captures. |
| 4 | **Improve typography hierarchy.** Entity titles should dominate their pages; metadata and controls should be visually subordinate. Currently several headings, tooltips and content labels compete at almost the same scale. | Verified | [#004 evidence](verification/expansion-004/README.md): shared 32pt entity title across all entity tabs, subordinate metadata/actions, long-title captures; 175 tests, 16 captures. |
| 5 | **Use category-specific visual identities.** Characters, factions, locations, magic systems and historical events can each have an understated color and icon, consistent across all views. | Verified | [#005 evidence](verification/expansion-005/README.md): one native/Canvas semantic palette, readable light accents, Phosphor glyphs and event identity; 175 native + 14 Canvas tests, 14 captures. |
| 6 | **Support adjustable information density.** Compact, comfortable and immersive modes should alter row height, card dimensions and spacing. | Verified | [#006 evidence](verification/expansion-006/README.md): three persisted density modes change rows, cards and spacing; 175 tests and 24 inspected captures. |
| 7 | **Introduce intentional empty states.** A mostly empty character profile could offer a portrait, biography prompts, relationship map and timeline, instead of displaying a large unoccupied editor. | Verified | [#007 evidence](verification/expansion-007/README.md): optional profile writing, persisted artwork with guarded Undo/export, real Graph/history entry points; 179 tests and 16 inspected captures. |
| 8 | **Improve microinteractions.** Use restrained transitions when selecting entities, opening panels, navigating relationships and accepting changes. | Verified | [#008 evidence](verification/expansion-008/README.md): shared motion and hover lifecycle, Reduce Motion, unobstructed confirmations; 180 tests, 20 inspected captures. |
| 9 | **Make all toolbars contextual.** Atlas should display geography tools, Graph should display relationship tools, and Canvas should display spatial authoring tools. | Verified | [#009 evidence](verification/expansion-009/README.md): workspace-specific tools, exclusive Atlas authoring, fresh relationship forms and drawing-only styles; 181 native / 15 Canvas tests, 28 engine checks, 24 inspected captures. |
| 10 | **Support collapsible contextual inspectors.** Each page should have an optional right-hand inspector that reveals object properties without opening a separate page. | Verified | [#010 evidence](verification/expansion-010/README.md): optional world-scoped object inspector across workspaces, linked references without navigation, Manual/compact support; 184 tests and 40 inspected captures. |
| 11 | **Add breadcrumbs and navigation history.** Moving from Mira Vale to Tidekeepers to the Glass Sea should create a reversible navigation trail. | Verified | [#011 evidence](verification/expansion-011/README.md): reversible record trail, shared map/board/chat/world history, save guards and fresh source resolution; 188 tests, 24 inspected captures. |
| 12 | **Provide saved workspace layouts.** Users should be able to save arrangements such as Research, Writing, Cartography or Simulation. | Verified | [#012 evidence](verification/expansion-012/README.md): per-world saved arrangements, rename/update/archive/Undo, fresh-source restore and Manual preservation; 192 tests, 16 inspected captures. |
| 13 | **Create an actual welcome dashboard.** Show recently edited entities, world activity, open proposals, unfinished writing and shortcuts to active projects. | Verified | [#013 evidence](verification/expansion-013/README.md): live world data, portable project outlines, direct source/review navigation and empty/Manual states; 196 tests, 20 final inspected captures. |
| 14 | **Improve light mode.** Use clearer separation between canvas, sidebar, floating controls and entity surfaces. The light Canvas screenshot currently appears washed out. | Verified | [#014 evidence](verification/expansion-014/README.md): shared spatial base, stronger text/boundaries and white entity/tool surfaces; 196 native / 15 Canvas tests, 28 engine checks, 18 inspected captures. |
| 15 | **Add semantic zoom.** When zooming out of a graph, show compact entity titles; when zooming in, progressively reveal descriptions, images and relationships. | Verified | [#015 evidence](verification/expansion-015/README.md): compact/summary/artwork detail, aligned ports, bounded thumbnails and readable relationship disclosure; 200 tests, 16 inspected states plus two corrected selection captures. |
| 16 | **Allow multiple open documents.** Tabs should support reopening recent entities, pinning important documents and switching without losing editor state. | Verified | [#016 evidence](verification/expansion-016/README.md): per-world persistent tabs/pins/recents, native caret/scroll/undo retention and failed-save guards; 204 tests, 16 inspected captures. |
| 17 | **Add independent scroll regions.** The inspector, document and navigation sidebar should scroll separately, without moving the entire workspace. | Verified | [#017 evidence](verification/expansion-017/README.md): existing independent regions confirmed with 36 rendered scroll assertions, 204 tests and 12 inspected captures. |
| 18 | **Introduce better progress and status feedback.** Saving, indexing, generating, reviewing and simulation operations need clear states, especially when an operation takes time. | Verified | [#018 evidence](verification/expansion-018/README.md): honest save/search states, counted review progress, failed/cancelled AI feedback and explicit hypothetical activity; 210 tests, 20 final inspected captures. |
| 19 | **Make panels resizable.** Sidebar width, inspector width and the chat dock should be user adjustable. | Verified | [#019 evidence](verification/expansion-019/README.md): native pointer/keyboard/accessibility splitters, persisted bounds and layouts, Settings controls and narrow-window adaptation; 215 tests, 24 final inspected captures and 14 rendered interaction/scroll assertions. |
| 20 | **Standardize hover and selection behavior.** A selected entity should look selected everywhere, with the same border, accent and interaction semantics. | Verified | [#020 evidence](verification/expansion-020/README.md): shared selection/hover surfaces across Graph, Canvas, Atlas, Library and Timeline; non-toggling selection, keyboard and focus cleanup; 216 native / 15 Canvas tests, 37 engine checks and 22 final inspected states. |
| 21 | **Universal command palette.** `⌘K` should find entities, commands, scenes, tools, settings, maps and recent changes. | Verified | [#021 evidence](verification/expansion-021/README.md): world-scoped lore/scenes/maps, real settings and tools, recent changes, guarded navigation and adaptive keyboard results; 219 tests and 30 final inspected captures. |
| 22 | **Global search with advanced syntax.** Support searches such as `type:character faction:Tidekeepers` or `status:canon updated:7d`. | Verified | [#022 evidence](verification/expansion-022/README.md): shared local filters for type/status/relationships/tags/dates, quoted names, archive/world isolation and safe invalid-query states; 227 tests and 20 final inspected states. |
| 23 | **Customizable sidebar.** Allow users to rearrange sections, hide unused categories and pin favorite collections. | Verified | [#023 evidence](verification/expansion-023/README.md): per-world section ordering, category visibility and pinned collections with safe preference recovery; 231 tests and 26 final inspected captures. |
| 24 | **Favorite entities and collections.** A pinned set of characters, locations or documents should stay immediately accessible. | Verified | [#024 evidence](verification/expansion-024/README.md): stable per-world record/collection favorites, shared controls, fresh-source opening, archive/restore and tab independence; 235 tests and 26 final inspected states. |
| 25 | **Recent activity history.** Show edits, approvals, newly discovered relationships and changes across the whole world. | Verified | [#025 evidence](verification/expansion-025/README.md): atomic world history, search/filter/pagination, preserved revisions and source navigation, portable v9 / JSON12; 244 tests and 22 final inspected states. |
| 26 | **Split workspace.** Open a character profile beside the atlas, timeline, graph or another entity. | Verified | [#026 evidence](verification/expansion-026/README.md): shared native second editor, dual-save guards, independent undo/focus, world-local addresses and adaptive layouts; 251 native / 17 Canvas tests, 37 engine checks and 37 final inspected states. |
| 27 | **Drag-to-open.** Drag an entity from search or the sidebar directly into another pane or onto a canvas. | Verified | [#027 evidence](verification/expansion-027/README.md): local record-address drag from Search/Favorites/Library to either editor or exact Canvas coordinates; guarded current-source resolution, undo/persistence and no duplicate lore; 256 native tests, 17 Canvas tests, 49 engine checks, 33 final inspected states. |
| 28 | **Context-preserving navigation.** Returning to Atlas should restore the previous zoom, active layer, selected region and viewport. | Verified | [#028 evidence](verification/expansion-028/README.md): world/map-scoped framing, layer and selection sessions, restart/history/layout restoration and guarded source preservation; 262 tests and 27 inspected native states. |
| 29 | **Global back/forward navigation.** Treat document, map and tool navigation consistently. | Open | Full requirement not yet verified. |
| 30 | **Keyboard-first creation.** Provide shortcuts for creating entities, linking records, opening inspectors, switching modes and navigating history. | Open | Full requirement not yet verified. |
| 31 | **Custom home views.** Users could choose Atlas, Conversation, Dashboard, Canvas or their last workspace as the startup screen. | Open | Full requirement not yet verified. |
| 32 | **Focusable workspaces.** Writing mode could temporarily hide the sidebar, inspectors and unrelated tools. | Open | Full requirement not yet verified. |
| 33 | **Session restoration.** Reopen all documents, tabs, views, selected entities and unsent drafts after an application restart. | Open | Full requirement not yet verified. |
| 34 | **Universal quick capture.** A single shortcut opens a small window to record an idea without disrupting the current workflow. | Open | Full requirement not yet verified. |
| 35 | **Cross-workspace drag and drop.** Any entity, event, source, image or proposal can become a reference within another tool. | Open | Full requirement not yet verified. |
| 36 | **Natural-language world operations.** Commands like "Create three competing coastal factions and connect them to the Tidekeepers" should create a reviewable batch of structured proposals. | Open | Full requirement not yet verified. |
| 37 | **Multi-step planning.** The assistant should plan complex changes, show the intended operations and let users approve the plan before execution. | Open | Full requirement not yet verified. |
| 38 | **Grounded answers with internal references.** Every factual claim about the world should be traceable to specific established lore. | Open | Full requirement not yet verified. |
| 39 | **Source inspection.** Clicking a cited passage should open the relevant section of the underlying entity or document. | Open | Full requirement not yet verified. |
| 40 | **Temporal awareness.** Asking "Who controlled the Glass Sea in Year 40?" should use the world state from Year 40. | Open | Full requirement not yet verified. |
| 41 | **Character knowledge awareness.** "What does Mira know about the Drowned City?" should consider only information available to Mira at that point. | Open | Full requirement not yet verified. |
| 42 | **Uncertainty-aware answers.** The assistant should distinguish established facts, unresolved questions, conflicting accounts and new suggestions. | Open | Full requirement not yet verified. |
| 43 | **Conversation branching.** Branch at any user or assistant message to explore an alternative creative direction without losing the original discussion. | Open | Full requirement not yet verified. |
| 44 | **Reusable prompt recipes.** Save instructions for character development, historical analysis, political simulation, plot critique or culture generation. | Open | Full requirement not yet verified. |
| 45 | **Structured AI output.** An answer could produce a timeline, map overlay, character comparison, graph, rule table or editable entity instead of only text. | Open | Full requirement not yet verified. |
| 46 | **Interactive proposal previews.** Show what would change in each tool before committing the proposed operations. | Open | Full requirement not yet verified. |
| 47 | **Context pinning.** Temporarily pin Mira Vale, the Tidekeepers and a relevant historical period as mandatory context. | Open | Full requirement not yet verified. |
| 48 | **Context exclusions.** Explicitly exclude particular drafts, branches, noncanon material or spoiler-heavy documents. | Open | Full requirement not yet verified. |
| 49 | **Multiple assistant working modes.** Offer Create, Research, Critique, Simulate, Organize and Explain. Each mode should have distinct behavior and tools. | Open | Full requirement not yet verified. |
| 50 | **Research-first questioning.** Let users select a mode where the assistant investigates inconsistencies and asks questions before proposing new lore. | Open | Full requirement not yet verified. |
| 51 | **Configurable originality.** Permit conservative continuations, moderate invention or highly exploratory suggestions. | Open | Full requirement not yet verified. |
| 52 | **Creative constraints.** Define requirements such as "no resurrection," "magic is hereditary," or "technology cannot exceed the early industrial era." | Open | Full requirement not yet verified. |
| 53 | **Long-running creative sessions.** Maintain goals, unanswered questions, working decisions and previous rejected ideas across conversations. | Open | Full requirement not yet verified. |
| 54 | **Conversation-to-world conversion.** Select a conversation passage and turn it into an entity, event, relationship, rule or collection of changes. | Open | Full requirement not yet verified. |
| 55 | **Inline entity editing.** Open an entity inspector directly from an AI response. | Open | Full requirement not yet verified. |
| 56 | **Regenerate only part of an answer.** Rewrite one faction, rule or character concept without regenerating the entire response. | Open | Full requirement not yet verified. |
| 57 | **Compare generations.** Place multiple AI responses side by side, with the ability to combine selected ideas. | Open | Full requirement not yet verified. |
| 58 | **Background world checks inside the application.** When enabled, the app can prepare consistency suggestions after edits, without modifying canon. | Open | Full requirement not yet verified. |
| 59 | **Explicit AI execution permissions.** Separate what the AI can read, generate, propose, simulate and save. | Open | Full requirement not yet verified. |
| 60 | **Per-operation cost visibility.** Show model usage, approximate token costs and configurable usage limits for external AI providers. | Open | Full requirement not yet verified. |
| 61 | **Custom entity types.** Let users define categories beyond the predefined Characters, Systems, Places and Power Systems. | Open | Full requirement not yet verified. |
| 62 | **Custom field schemas.** A character might have ancestry, affiliations, birthplace, abilities, languages, allegiances and death status. | Open | Full requirement not yet verified. |
| 63 | **Typed fields.** Support numbers, dates, ranges, durations, selections, formulas, linked entities, coordinates, media and computed values. | Open | Full requirement not yet verified. |
| 64 | **Conditional fields.** A deceased character can expose a death event and cause of death; a living character need not. | Open | Full requirement not yet verified. |
| 65 | **Reusable templates.** Create standardized profiles for kingdoms, characters, settlements, species, artifacts and organizations. | Open | Full requirement not yet verified. |
| 66 | **Entity inheritance.** A derived species or subclass could inherit attributes from a parent type while overriding selected fields. | Open | Full requirement not yet verified. |
| 67 | **Bidirectional relationships.** If Mira belongs to the Tidekeepers, the Tidekeepers should automatically list Mira. | Open | Full requirement not yet verified. |
| 68 | **Relationship attributes.** Record start and end dates, strength, secrecy, mutuality, status and the evidence supporting a connection. | Open | Full requirement not yet verified. |
| 69 | **Multiple relationship meanings.** Distinguish mentor, political superior, legal guardian, former ally, rival and unknown relationship types. | Open | Full requirement not yet verified. |
| 70 | **Names and aliases across time.** An organization might change its name after a revolution while retaining a single identity. | Open | Full requirement not yet verified. |
| 71 | **Entity lifecycle.** Support creation, transformation, dissolution, merger, succession and destruction. | Open | Full requirement not yet verified. |
| 72 | **Atomic facts beneath prose.** Store important assertions separately so the application can reason about them without trying to reinterpret entire documents every time. | Open | Full requirement not yet verified. |
| 73 | **Fact-level provenance.** Record who established a fact, when it was established, and which document or event supports it. | Open | Full requirement not yet verified. |
| 74 | **Canon states at fact level.** A character profile can contain canon, draft and disputed statements without labeling the entire character identically. | Open | Full requirement not yet verified. |
| 75 | **In-world perspectives.** A historical event may have an objective description and conflicting interpretations from different factions. | Open | Full requirement not yet verified. |
| 76 | **Time-dependent attributes.** A character's location, title, age and allegiance should change with the current historical date. | Open | Full requirement not yet verified. |
| 77 | **Computed properties.** Age, travel distance, faction population, genealogical relationship and inventory totals can be calculated. | Open | Full requirement not yet verified. |
| 78 | **Entity dependency tracking.** The app should know which rules, events and characters depend on another entity's attributes. | Open | Full requirement not yet verified. |
| 79 | **Entity duplication and variants.** Duplicate a character into a new branch while preserving its ancestry and original references. | Open | Full requirement not yet verified. |
| 80 | **Bulk editing.** Select dozens of records and modify tags, categories, affiliations, status or ownership together. | Open | Full requirement not yet verified. |
| 81 | **Automatic backlinks.** Find both explicit links and textual mentions, while keeping those two types distinct. | Open | Full requirement not yet verified. |
| 82 | **Entity merging.** Combine duplicate records with a field-by-field conflict resolution interface. | Open | Full requirement not yet verified. |
| 83 | **Record archival.** Hide unused records without breaking existing references. | Open | Full requirement not yet verified. |
| 84 | **Custom validation.** Set constraints such as unique royal titles during a given period, or birth dates before death dates. | Open | Full requirement not yet verified. |
| 85 | **Modular entity pages.** Profiles should consist of movable modules, not a single giant text field. | Open | Full requirement not yet verified. |
| 86 | **Cover artwork and portraits.** Include optional character portraits, location artwork or faction banners. | Open | Full requirement not yet verified. |
| 87 | **Rich-text blocks.** Support headings, collapsible sections, callouts, tables, code, equations, galleries and embedded media. | Open | Full requirement not yet verified. |
| 88 | **Inline linked entities.** Typing `@Tidekeepers` should create a live reference with hover previews. | Open | Full requirement not yet verified. |
| 89 | **Structured infoboxes.** Show the most useful attributes at a glance. | Open | Full requirement not yet verified. |
| 90 | **Tabbed entity views.** Overview, Details, Relationships, History, Media, Mechanics and Versions should expose distinct information. | Open | Full requirement not yet verified. |
| 91 | **Automatic relationship panels.** Show connected characters, factions, places and events without requiring manual duplication. | Open | Full requirement not yet verified. |
| 92 | **Inline timeline.** A character's profile should display their personal chronology. | Open | Full requirement not yet verified. |
| 93 | **Contextual maps.** Display birthplace, current location, journey history and territory in appropriate profiles. | Open | Full requirement not yet verified. |
| 94 | **Field-level edit history.** Compare who changed a specific attribute and restore earlier values. | Open | Full requirement not yet verified. |
| 95 | **Editor comments and annotations.** Keep unresolved questions attached to specific text. | Open | Full requirement not yet verified. |
| 96 | **Content completion suggestions.** Suggest missing biography fields or relevant relationships without forcing completion. | Open | Full requirement not yet verified. |
| 97 | **Editable section templates.** Different entity categories should have different layouts. | Open | Full requirement not yet verified. |
| 98 | **Distraction-free writing.** Provide a document-first mode that hides structured data until requested. | Open | Full requirement not yet verified. |
| 99 | **Automatic summaries.** Generate a short synopsis from a long entity profile, with citations back to the original text. | Open | Full requirement not yet verified. |
| 100 | **Sidebar inspector for selected text.** Highlight a character name to create or inspect a link, relationship, event or fact. | Open | Full requirement not yet verified. |
| 101 | **Interactive entity blocks.** Character, faction, map, event and rule nodes should have specialized designs and controls. | Open | Full requirement not yet verified. |
| 102 | **Live bidirectional synchronization.** Editing an entity inside Canvas should update its actual record; changing the entity elsewhere should refresh Canvas. | Open | Full requirement not yet verified. |
| 103 | **Nested frames and groups.** Create expandable boards within boards for individual plots, factions or regions. | Open | Full requirement not yet verified. |
| 104 | **Multiple canvas layers.** Separate geography, narrative, relationships, mechanics and research without creating unrelated documents. | Open | Full requirement not yet verified. |
| 105 | **Custom relationship connectors.** Support directed, undirected, conditional, reciprocal, historical and conflicting relationships. | Open | Full requirement not yet verified. |
| 106 | **Smart connection creation.** Dragging between two entities should offer valid relationships based on their types. | Open | Full requirement not yet verified. |
| 107 | **Conditional nodes.** Represent decisions, requirements, consequences and alternative outcomes directly on the board. | Open | Full requirement not yet verified. |
| 108 | **Embedded map viewports.** A live Atlas selection should be available as an interactive Canvas object. | Open | Full requirement not yet verified. |
| 109 | **Embedded timeline views.** Display a filtered historical period or a character's chronology inside a frame. | Open | Full requirement not yet verified. |
| 110 | **Interactive simulation nodes.** Attach a simulation to a set of entities and inspect its results without leaving Canvas. | Open | Full requirement not yet verified. |
| 111 | **Custom database tables.** Place editable entity collections directly on the canvas. | Open | Full requirement not yet verified. |
| 112 | **Live charts and diagrams.** Show population histories, magic progression curves, resource networks or faction influence. | Open | Full requirement not yet verified. |
| 113 | **AI-powered canvas operations.** Commands such as "Group these kingdoms by alliance" should manipulate the selected objects. | Open | Full requirement not yet verified. |
| 114 | **Automatic layouts.** Offer hierarchy, flowchart, timeline, circular, force-directed and grid arrangements. | Open | Full requirement not yet verified. |
| 115 | **Region-based selection.** Select objects inside a freeform lasso, rectangle or named frame. | Open | Full requirement not yet verified. |
| 116 | **Alignment and snapping.** Add guides, distribution commands, grids and smart spacing. | Open | Full requirement not yet verified. |
| 117 | **Minimap and viewport bookmarks.** Essential when a board becomes very large. | Open | Full requirement not yet verified. |
| 118 | **Canvas presentations.** Turn frames into a guided walkthrough with transitions and presenter notes. | Open | Full requirement not yet verified. |
| 119 | **Canvas history.** Replay changes, compare prior states and restore individual objects. | Open | Full requirement not yet verified. |
| 120 | **Reusable components.** Save entire node groups as templates for governments, settlements or character arcs. | Open | Full requirement not yet verified. |
| 121 | **Cross-canvas references.** An object on one board can link to another board without being copied. | Open | Full requirement not yet verified. |
| 122 | **Canvas-specific AI context.** Ask the assistant to explain only the selected nodes and connections. | Open | Full requirement not yet verified. |
| 123 | **Interactive sticky notes, sketches and annotations.** Permit freeform exploration without requiring everything to become structured lore. | Open | Full requirement not yet verified. |
| 124 | **Visual state indicators.** Make draft, canon, disputed and hypothetical records identifiable without opening each card. | Open | Full requirement not yet verified. |
| 125 | **Multiple graph layouts.** Hierarchical, force-directed, radial, geographic, chronological and community-clustered. | Open | Full requirement not yet verified. |
| 126 | **Relationship filtering.** Show only family, political, geographical, magical, historical or user-defined connections. | Open | Full requirement not yet verified. |
| 127 | **Entity-type filtering.** Isolate characters, settlements, artifacts or factions. | Open | Full requirement not yet verified. |
| 128 | **Temporal graph mode.** Display the relationships that existed during a specific year or era. | Open | Full requirement not yet verified. |
| 129 | **Neighborhood exploration.** Select an entity and expand one, two or more degrees of connection. | Open | Full requirement not yet verified. |
| 130 | **Pathfinding between entities.** Find the shortest or most relevant relationship chain connecting two records. | Open | Full requirement not yet verified. |
| 131 | **Influence analysis.** Rank entities by configurable network measures, without equating high connectivity with narrative importance. | Open | Full requirement not yet verified. |
| 132 | **Community detection.** Identify tightly connected groups that users may want to turn into collections or factions. | Open | Full requirement not yet verified. |
| 133 | **Relationship strength.** Let users assign qualitative or numerical weights to relevant connections. | Open | Full requirement not yet verified. |
| 134 | **Conflict detection.** Flag mutually incompatible relationship claims with supporting evidence. | Open | Full requirement not yet verified. |
| 135 | **Duplicate edge handling.** Collapse equivalent connections and clearly differentiate reciprocal relationships. | Open | Full requirement not yet verified. |
| 136 | **Relationship history.** Select an edge to see how the connection evolved. | Open | Full requirement not yet verified. |
| 137 | **Expandable node cards.** Hover or select to reveal portraits, descriptions, metadata and actions. | Open | Full requirement not yet verified. |
| 138 | **Progressive rendering.** Replace detailed cards with compact representations as graph density increases. | Open | Full requirement not yet verified. |
| 139 | **Graph search and focus.** Search for an entity and smoothly center its neighborhood. | Open | Full requirement not yet verified. |
| 140 | **Saved graph queries.** Store views such as "Political power during Year 40" or "Everyone connected to Mira." | Open | Full requirement not yet verified. |
| 141 | **Comparative graphs.** Compare two periods or alternative histories with added, removed and changed edges. | Open | Full requirement not yet verified. |
| 142 | **Graph-to-Canvas extraction.** Copy a selected subnetwork into a Canvas as live references. | Open | Full requirement not yet verified. |
| 143 | **Graph annotations.** Save observations separately from the underlying relationships. | Open | Full requirement not yet verified. |
| 144 | **Graph clustering and edge bundling.** Reduce long connection crossings and unreadable labels. | Open | Full requirement not yet verified. |
| 145 | **Graph analytics panel.** Show isolated records, relationship coverage, suspicious cycles and disconnected groups. | Open | Full requirement not yet verified. |
| 146 | **Multiple maps per world.** Planets, continents, countries, cities, buildings, dungeons, celestial regions and alternate dimensions. | Open | Full requirement not yet verified. |
| 147 | **Hierarchical maps.** Selecting a country opens its regional map; selecting a city opens a settlement map. | Open | Full requirement not yet verified. |
| 148 | **Map layers.** Terrain, elevation, borders, settlements, roads, climate, population, political influence, resources, trade routes and magic. | Open | Full requirement not yet verified. |
| 149 | **Custom layer creation.** Users should be able to define any visual layer, with custom geometry and metadata. | Open | Full requirement not yet verified. |
| 150 | **Time-dependent map states.** Move a year slider to show different borders, settlements and geographical conditions. | Open | Full requirement not yet verified. |
| 151 | **Advanced region editing.** Include polygon holes, vertex snapping, unions, intersections, splitting and merging. | Open | Full requirement not yet verified. |
| 152 | **Geographic object linking.** Connect map regions to real entities in the world database. | Open | Full requirement not yet verified. |
| 153 | **Road, river and route tools.** Support curved paths, branching networks, travel directions and connections. | Open | Full requirement not yet verified. |
| 154 | **Distance measurement.** Establish map scale and calculate distance between points or along paths. | Open | Full requirement not yet verified. |
| 155 | **Travel-time calculation.** Use terrain, transport mode, road networks, weather and configurable movement rules. | Open | Full requirement not yet verified. |
| 156 | **Custom coordinate systems.** Support fictional planetary dimensions, non-Earth calendars and unusual geographical models. | Open | Full requirement not yet verified. |
| 157 | **Terrain editing.** Let users paint mountains, coastlines, lakes, forests, deserts and elevation masks. | Open | Full requirement not yet verified. |
| 158 | **Procedural terrain generation.** Generate landscapes from adjustable seeds and constraints, with manual corrections. | Open | Full requirement not yet verified. |
| 159 | **Hydrology tools.** Create or estimate rivers, watersheds, lakes and drainage networks based on elevation. | Open | Full requirement not yet verified. |
| 160 | **Climate modeling.** Estimate broad climate zones from latitude, elevation, prevailing winds and other user-supplied assumptions. | Open | Full requirement not yet verified. |
| 161 | **Seasonal overlays.** Show snow coverage, rainfall, river flooding, desertification and agricultural cycles. | Open | Full requirement not yet verified. |
| 162 | **Population overlays.** Display settlement density, migration and regional demographics over time. | Open | Full requirement not yet verified. |
| 163 | **Political maps.** Show disputed borders, spheres of influence, occupied territories and historical claims. | Open | Full requirement not yet verified. |
| 164 | **Trade route visualization.** Map trade networks, transport bottlenecks, important ports and resource flows. | Open | Full requirement not yet verified. |
| 165 | **Military campaign tools.** Represent armies, supply lines, contested regions and changing control. | Open | Full requirement not yet verified. |
| 166 | **Map-based event placement.** A timeline event can refer to one or several specific locations. | Open | Full requirement not yet verified. |
| 167 | **Fog of war.** Hide locations and geographic details based on a character's or faction's knowledge. | Open | Full requirement not yet verified. |
| 168 | **Map styles.** Offer political, topographic, nautical, parchment, satellite-inspired, hand-drawn and schematic rendering. | Open | Full requirement not yet verified. |
| 169 | **Map import and tracing.** Import raster or vector artwork, calibrate scale and place structured geometry over it. | Open | Full requirement not yet verified. |
| 170 | **Map export.** Export print-quality images, layered files, transparent overlays and interactive read-only views. | Open | Full requirement not yet verified. |
| 171 | **Place-level inspectors.** Selecting a city should display its population, government, history, inhabitants and related events. | Open | Full requirement not yet verified. |
| 172 | **Map annotations.** Support labels, symbols, legends, scale bars and decorative elements that do not alter world data. | Open | Full requirement not yet verified. |
| 173 | **Geographic search.** Find places by name, region, ownership, population, terrain or historical state. | Open | Full requirement not yet verified. |
| 174 | **Atlas minimap and navigation bookmarks.** Jump between continents, important regions or saved camera positions. | Open | Full requirement not yet verified. |
| 175 | **Compare-map mode.** Overlay two historical or hypothetical states with a transparency slider. | Open | Full requirement not yet verified. |
| 176 | **Territorial expansion simulation.** Model changes in control from settlement, conquest, alliances or administrative decisions. | Open | Full requirement not yet verified. |
| 177 | **Settlement viability analysis.** Examine water availability, terrain, transport access and resources before proposing a new city. | Open | Full requirement not yet verified. |
| 178 | **Infrastructure planning.** Draw potential roads, ports and canals, then estimate their effects on travel and trade. | Open | Full requirement not yet verified. |
| 179 | **Environmental change simulation.** Explore floods, volcanic eruptions, changing sea levels and other events. | Open | Full requirement not yet verified. |
| 180 | **Character journey playback.** Animate a character's route along the atlas based on documented events. | Open | Full requirement not yet verified. |
| 181 | **World-scale consistency checks.** Flag impossible or unsupported journeys, geographic contradictions and mismatched map distances. | Open | Full requirement not yet verified. |
| 182 | **Interactive map storytelling.** Associate a story, historical event or narrated sequence with a specific location. | Open | Full requirement not yet verified. |
| 183 | **Map-linked AI generation.** Select a territory and request plausible settlements, cultures or conflicts based on its known attributes. | Open | Full requirement not yet verified. |
| 184 | **True horizontal timeline.** Display events on a scalable chronological axis. | Open | Full requirement not yet verified. |
| 185 | **Zoomable time scales.** Move from millennia to years, months, days or hours. | Open | Full requirement not yet verified. |
| 186 | **Custom calendars.** Define the length of years, months, weeks and days. | Open | Full requirement not yet verified. |
| 187 | **Multiple calendar systems.** Convert between imperial, religious, regional or astronomical dates. | Open | Full requirement not yet verified. |
| 188 | **Relative chronology.** Support events dated "three winters after the crossing" without inventing an absolute date. | Open | Full requirement not yet verified. |
| 189 | **Uncertain dates.** Store ranges, approximate dates, disputed dates and unknown dates explicitly. | Open | Full requirement not yet verified. |
| 190 | **Event dependencies.** Make it possible to declare that an event requires another event to have occurred first. | Open | Full requirement not yet verified. |
| 191 | **Causal event chains.** Link a famine to migration, political instability or other downstream consequences. | Open | Full requirement not yet verified. |
| 192 | **Parallel timeline tracks.** Compare different characters, nations, conflicts or storylines in synchronized lanes. | Open | Full requirement not yet verified. |
| 193 | **Personal timelines.** Automatically assemble a character's life history from linked events. | Open | Full requirement not yet verified. |
| 194 | **Territorial histories.** View events associated with a selected location or region. | Open | Full requirement not yet verified. |
| 195 | **Branching chronology.** Display alternative historical paths with visible divergence points. | Open | Full requirement not yet verified. |
| 196 | **Timeline playback.** Move through events while Atlas and Graph update to the corresponding period. | Open | Full requirement not yet verified. |
| 197 | **Interactive event expansion.** Open details, participants, causes, outcomes and related world changes. | Open | Full requirement not yet verified. |
| 198 | **Event drag and rescheduling.** Move an event to another time and preview affected dependencies. | Open | Full requirement not yet verified. |
| 199 | **Duration-based events.** Represent wars, migrations, reigns and environmental changes as spans instead of single points. | Open | Full requirement not yet verified. |
| 200 | **Era and period hierarchy.** Allow periods inside larger ages, with overlapping or competing chronologies where appropriate. | Open | Full requirement not yet verified. |
| 201 | **Historical comparison.** Compare the world before and after a major event. | Open | Full requirement not yet verified. |
| 202 | **Automatic event extraction.** Identify possible dates and historical events in written lore and propose structured timeline entries. | Open | Full requirement not yet verified. |
| 203 | **Chronology validation.** Detect age contradictions, impossible travel schedules and circular event dependencies. | Open | Full requirement not yet verified. |
| 204 | **Historical uncertainty visualization.** Use distinct markers for disputed or approximate dates. | Open | Full requirement not yet verified. |
| 205 | **Event intensity visualization.** Display concentrations of activity across eras, with configurable filters. | Open | Full requirement not yet verified. |
| 206 | **Story chronology versus world chronology.** Track both when events happened and when readers discover them. | Open | Full requirement not yet verified. |
| 207 | **Future planning.** Draft upcoming events as possibilities without establishing them as canonical history. | Open | Full requirement not yet verified. |
| 208 | **Alternate-history comparison.** Show what changed after a selected divergence point. | Open | Full requirement not yet verified. |
| 209 | **Formal power-system definitions.** Define energy sources, costs, restrictions, governing principles and exceptions. | Open | Full requirement not yet verified. |
| 210 | **Resource models.** Create mana, spiritual energy, stamina, divine authority, memories, lifespans or custom resource types. | Open | Full requirement not yet verified. |
| 211 | **Progression frameworks.** Support cultivation realms, ranks, classes, levels, stages, transformations and custom advancement models. | Open | Full requirement not yet verified. |
| 212 | **Multiple progression paths.** Let characters specialize in different branches and combine eligible techniques. | Open | Full requirement not yet verified. |
| 213 | **Technique prerequisites.** Support attribute requirements, completed training, resources, lineage, special locations and previous abilities. | Open | Full requirement not yet verified. |
| 214 | **Conditional unlocks.** A technique could require two specific skills, one rare artifact and a completed event. | Open | Full requirement not yet verified. |
| 215 | **Mutually exclusive paths.** Choosing one advancement can permanently prohibit another. | Open | Full requirement not yet verified. |
| 216 | **Technique combinations.** Define how abilities interact, reinforce or suppress one another. | Open | Full requirement not yet verified. |
| 217 | **Mathematical ability scaling.** Express damage, efficiency, duration, range or resource consumption through customizable formulas. | Open | Full requirement not yet verified. |
| 218 | **Attribute systems.** Define strength, perception, aptitude, concentration, affinity and other setting-specific attributes. | Open | Full requirement not yet verified. |
| 219 | **Training simulation.** Estimate progression under specified training schedules, talent assumptions and resource availability. | Open | Full requirement not yet verified. |
| 220 | **Individual skill profiles.** Track what each character has learned, mastered, forgotten or lost. | Open | Full requirement not yet verified. |
| 221 | **Power inheritance.** Support hereditary abilities, bloodlines, acquired traits and inherited restrictions. | Open | Full requirement not yet verified. |
| 222 | **Counter-technique systems.** Specify weaknesses and conditional counters instead of manually declaring every encounter outcome. | Open | Full requirement not yet verified. |
| 223 | **Equipment interactions.** Allow artifacts, weapons or environments to alter an ability's behavior. | Open | Full requirement not yet verified. |
| 224 | **Dynamic energy environments.** A location can amplify, suppress or prevent certain techniques. | Open | Full requirement not yet verified. |
| 225 | **Power-system exceptions.** Maintain explicit exceptions with explanations and affected rules. | Open | Full requirement not yet verified. |
| 226 | **Technique versioning.** Track abilities that evolve or are modified after major events. | Open | Full requirement not yet verified. |
| 227 | **Technique testing sandbox.** Create fictional encounters to examine whether abilities behave as intended. | Open | Full requirement not yet verified. |
| 228 | **Exploit detection.** Identify combinations that permit infinite energy, unrestricted replication or other unwanted outcomes under the authored rules. | Open | Full requirement not yet verified. |
| 229 | **Progression bottleneck analysis.** Reveal unreachable techniques, missing prerequisites and impossible progression paths. | Open | Full requirement not yet verified. |
| 230 | **Power comparison.** Compare characters using attributes, abilities and circumstances without blindly assigning an arbitrary winner. | Open | Full requirement not yet verified. |
| 231 | **Visual rule inspector.** Select any node and display prerequisites, effects, costs, restrictions and dependents. | Open | Full requirement not yet verified. |
| 232 | **Custom mechanics editors.** Support alternative systems such as alchemy, crafting, scientific technologies, biological adaptation or political authority. | Open | Full requirement not yet verified. |
| 233 | **Character agents.** Give characters persistent goals, resources, capabilities, relationships and beliefs. | Open | Full requirement not yet verified. |
| 234 | **Personality and decision models.** Define motivations, preferences, loyalties and how they respond to events. | Open | Full requirement not yet verified. |
| 235 | **Knowledge-limited decision-making.** Characters should act on what they believe, which may differ from the world's actual state. | Open | Full requirement not yet verified. |
| 236 | **Dynamic relationships.** Relationships evolve in response to events, betrayal, cooperation, proximity and conflicting goals. | Open | Full requirement not yet verified. |
| 237 | **Goal conflict simulation.** Explore what happens when multiple characters pursue incompatible objectives. | Open | Full requirement not yet verified. |
| 238 | **Character life simulation.** Model movement, occupation, training, major life events and affiliations at a configurable level of detail. | Open | Full requirement not yet verified. |
| 239 | **Reputation systems.** Track how different factions perceive an individual or organization. | Open | Full requirement not yet verified. |
| 240 | **Information and rumor propagation.** Model which populations learn about an event, when, and through which channels. | Open | Full requirement not yet verified. |
| 241 | **Social hierarchy modeling.** Represent class systems, titles, privileges, institutions and social restrictions. | Open | Full requirement not yet verified. |
| 242 | **Narrative consequence exploration.** Ask how a character's choice could affect other characters, factions and future events. | Open | Full requirement not yet verified. |
| 243 | **Faction agents.** Organizations can have goals, leadership, resources, territory and internal disagreements. | Open | Full requirement not yet verified. |
| 244 | **Diplomatic relationships.** Support treaties, alliances, hostility, trade agreements, vassalage and neutrality. | Open | Full requirement not yet verified. |
| 245 | **Government systems.** Model succession, elections, hereditary rule, councils, coups and institutional power. | Open | Full requirement not yet verified. |
| 246 | **Political instability modeling.** Explore how shortages, succession disputes and public dissatisfaction affect a government. | Open | Full requirement not yet verified. |
| 247 | **Trade and resource systems.** Track production, consumption, movement, shortages and dependencies. | Open | Full requirement not yet verified. |
| 248 | **Economic simulation.** Use configurable systems for currencies, wages, taxes, production and exchange. | Open | Full requirement not yet verified. |
| 249 | **Population modeling.** Track demographics, birth and death assumptions, migration and settlement growth. | Open | Full requirement not yet verified. |
| 250 | **Migration simulation.** Explore how climate, conflict, opportunity or persecution changes where populations live. | Open | Full requirement not yet verified. |
| 251 | **Military logistics.** Estimate supply consumption, travel and other constraints within fictional campaigns. | Open | Full requirement not yet verified. |
| 252 | **Civilization development.** Simulate gradual changes in infrastructure, institutions, technology and resource access. | Open | Full requirement not yet verified. |
| 253 | **Cultural diffusion.** Model the spread of languages, practices, inventions and beliefs along contact networks. | Open | Full requirement not yet verified. |
| 254 | **Ecological systems.** Represent food webs, habitats and interactions among species. | Open | Full requirement not yet verified. |
| 255 | **Climate-driven events.** Explore long-term consequences of changing rainfall, temperature or sea levels. | Open | Full requirement not yet verified. |
| 256 | **Disease and population disruption.** Model fictional outbreaks using explicitly configured transmission and recovery rules. | Open | Full requirement not yet verified. |
| 257 | **Resource depletion.** Track finite materials, replenishment and environmental pressures. | Open | Full requirement not yet verified. |
| 258 | **Magical environmental effects.** If magic changes geography, climate or biology, those effects should influence relevant simulations. | Open | Full requirement not yet verified. |
| 259 | **Technological diffusion.** Estimate how new inventions spread between connected populations. | Open | Full requirement not yet verified. |
| 260 | **Simulation time controls.** Run an hour, a year, a century or a custom time interval. | Open | Full requirement not yet verified. |
| 261 | **Simulation granularity.** Choose whether to simulate individuals, settlements, regions or entire civilizations. | Open | Full requirement not yet verified. |
| 262 | **Seeded simulation runs.** Reproduce the same run using stored starting conditions, parameters and random seeds. | Open | Full requirement not yet verified. |
| 263 | **Scenario comparison.** Compare outcomes with and without a specific change. | Open | Full requirement not yet verified. |
| 264 | **Sensitivity analysis.** Identify which assumptions influence the result most. | Open | Full requirement not yet verified. |
| 265 | **Simulation traces.** Inspect why a particular outcome occurred. | Open | Full requirement not yet verified. |
| 266 | **User interventions.** Change assumptions or introduce new events while a simulation is paused. | Open | Full requirement not yet verified. |
| 267 | **Simulation snapshots.** Save results as hypothetical states that can later become proposals. | Open | Full requirement not yet verified. |
| 268 | **Consequence visualizations.** Display changed territories, relationships, populations and events on the existing tools. | Open | Full requirement not yet verified. |
| 269 | **Atomic change sets.** Group all proposed edits from one action into a single reviewable operation. | Open | Full requirement not yet verified. |
| 270 | **Dependency-aware review.** Show which changes rely on other proposed changes. | Open | Full requirement not yet verified. |
| 271 | **Before-and-after previews.** Display exact modifications to entity fields, documents, maps and timelines. | Open | Full requirement not yet verified. |
| 272 | **Change impact analysis.** Identify every directly affected entity and the derived information that may need recalculation. | Open | Full requirement not yet verified. |
| 273 | **Three-way branch merging.** Compare an alternative branch with its original ancestor and the current canonical state. | Open | Full requirement not yet verified. |
| 274 | **Selective merging.** Accept only the parts of a hypothetical scenario that the user wants. | Open | Full requirement not yet verified. |
| 275 | **Conflict resolution UI.** Choose between competing values or create a new reconciled version. | Open | Full requirement not yet verified. |
| 276 | **Undoable operations.** Make approved changes reversible, with dependent operations handled safely. | Open | Full requirement not yet verified. |
| 277 | **Complete change provenance.** Record the user action, source context and generated proposal behind each alteration. | Open | Full requirement not yet verified. |
| 278 | **Canon locks.** Protect specific facts or entities from modification without explicit authorization. | Open | Full requirement not yet verified. |
| 279 | **Canonical invariants.** Define rules that every accepted change must satisfy. | Open | Full requirement not yet verified. |
| 280 | **Intentional inconsistencies.** Mark contradictions as deliberate mysteries, unreliable narratives or unresolved disputes. | Open | Full requirement not yet verified. |
| 281 | **Contradiction classifications.** Separate factual conflicts, temporal conflicts, missing references, duplicate records and semantic disagreements. | Open | Full requirement not yet verified. |
| 282 | **Explainable checks.** Show the exact conflicting facts and relevant sources, not merely a warning. | Open | Full requirement not yet verified. |
| 283 | **Suggested repair operations.** Offer minimal changes that would resolve a detected inconsistency. | Open | Full requirement not yet verified. |
| 284 | **Incremental validation.** Recheck affected records after edits instead of scanning the entire world unnecessarily. | Open | Full requirement not yet verified. |
| 285 | **Review queues by scope.** Filter proposals for a character, region, historical period, document or branch. | Open | Full requirement not yet verified. |
| 286 | **Saved review policies.** Allow different approval rules for experimental and canonical material. | Open | Full requirement not yet verified. |
| 287 | **Canon milestones.** Create named snapshots such as "Before the Long Tide" or "First published version." | Open | Full requirement not yet verified. |
| 288 | **Restore and replay.** View the world at a previous revision or restore a prior version. | Open | Full requirement not yet verified. |
| 289 | **Approval summaries.** Show the resulting changes to world state after a batch has been applied. | Open | Full requirement not yet verified. |
| 290 | **Custom consistency checks.** Let users define rules for their own settings. | Open | Full requirement not yet verified. |
| 291 | **Review comments.** Attach questions and explanations to individual proposed operations. | Open | Full requirement not yet verified. |
| 292 | **Distinguish references from implications.** A document mentioning another entity does not necessarily mean the records should have a formal relationship. | Open | Full requirement not yet verified. |
| 293 | **Module marketplace or gallery.** Allow users to enable predefined modules. | Open | Full requirement not yet verified. |
| 294 | **Custom module builder.** Create a new category and choose its fields, behaviors, views and relationships. | Open | Full requirement not yet verified. |
| 295 | **Module dependencies.** A dynasty module can use data from characters, governments and timelines. | Open | Full requirement not yet verified. |
| 296 | **Module-specific dashboards.** Provide views designed for the module's purpose. | Open | Full requirement not yet verified. |
| 297 | **Module-level AI tools.** An economic module could expose trade-analysis operations; a language module could expose translation and language-generation operations. | Open | Full requirement not yet verified. |
| 298 | **Module export and sharing.** Let users publish templates or modules for other creators. | Open | Full requirement not yet verified. |
| 299 | **Custom visualizations.** Allow module authors to define graph, table, tree and map representations. | Open | Full requirement not yet verified. |
| 300 | **Entity schema migration.** Preserve existing data when a module's schema changes. | Open | Full requirement not yet verified. |
| 301 | **Constructed-language generator.** Generate language structures using configurable phonotactics and grammatical constraints. | Open | Full requirement not yet verified. |
| 302 | **Phoneme and script editors.** Define sounds, orthography, characters and writing systems. | Open | Full requirement not yet verified. |
| 303 | **Vocabulary database.** Store words, meanings, forms, examples and their historical changes. | Open | Full requirement not yet verified. |
| 304 | **Etymology trees.** Track how words originate, diverge and change across languages. | Open | Full requirement not yet verified. |
| 305 | **Language-family graphs.** Model common ancestors and linguistic relationships. | Open | Full requirement not yet verified. |
| 306 | **Sound-change rules.** Apply defined phonological changes over fictional centuries. | Open | Full requirement not yet verified. |
| 307 | **Translation assistance.** Translate within established language rules while flagging missing vocabulary. | Open | Full requirement not yet verified. |
| 308 | **Naming generators.** Generate names for characters, regions, cities and artifacts based on local linguistic patterns. | Open | Full requirement not yet verified. |
| 309 | **Cultural practice systems.** Define rites, taboos, customs, ceremonies and their distribution among populations. | Open | Full requirement not yet verified. |
| 310 | **Cultural evolution.** Explore how migration, trade, conquest and religion alter practices over time. | Open | Full requirement not yet verified. |
| 311 | **Regional naming consistency.** Detect place names that contradict an established naming convention, while allowing exceptions. | Open | Full requirement not yet verified. |
| 312 | **Cultural perspective.** Track how different societies interpret the same event or myth. | Open | Full requirement not yet verified. |
| 313 | **Story projects.** A single universe can contain multiple books, campaigns, scripts or independent storylines. | Open | Full requirement not yet verified. |
| 314 | **Chapter and scene editor.** Provide long-form writing tools with a hierarchical outline. | Open | Full requirement not yet verified. |
| 315 | **Plot boards.** Organize scenes by act, chapter, point of view, timeline and location. | Open | Full requirement not yet verified. |
| 316 | **Character arc tracking.** Define goals, turning points, development and unresolved conflicts. | Open | Full requirement not yet verified. |
| 317 | **Scene-level lore validation.** Check whether referenced locations, technologies, relationships and abilities are available at that point. | Open | Full requirement not yet verified. |
| 318 | **Point-of-view consistency.** Warn when a narrator knows information unavailable to them. | Open | Full requirement not yet verified. |
| 319 | **Story timeline versus canonical timeline.** Track flashbacks, parallel scenes and nonchronological disclosure. | Open | Full requirement not yet verified. |
| 320 | **Foreshadowing tracking.** Link early clues to intended later developments. | Open | Full requirement not yet verified. |
| 321 | **Unresolved thread management.** Track mysteries, character promises, objectives and planted information. | Open | Full requirement not yet verified. |
| 322 | **Scene dependency graphs.** Identify the scenes that establish information needed by later scenes. | Open | Full requirement not yet verified. |
| 323 | **Draft comparison.** Compare alternative scene or chapter versions. | Open | Full requirement not yet verified. |
| 324 | **AI-assisted continuity editing.** Review specific scenes against established world facts. | Open | Full requirement not yet verified. |
| 325 | **In-character conversations.** Simulate dialogue using a character's established knowledge, goals and personality. | Open | Full requirement not yet verified. |
| 326 | **Character voice profiles.** Track vocabulary, speech patterns, preferences and register. | Open | Full requirement not yet verified. |
| 327 | **Spoiler controls.** Restrict the AI's context to information revealed by a chosen chapter. | Open | Full requirement not yet verified. |
| 328 | **Story-to-world extraction.** Propose new world facts discovered in a written scene. | Open | Full requirement not yet verified. |
| 329 | **Interactive fiction support.** Create branching reader decisions and track possible narrative states. | Open | Full requirement not yet verified. |
| 330 | **Campaign session support.** Record tabletop sessions and propose resulting world changes for review. | Open | Full requirement not yet verified. |
| 331 | **Narrative visualization.** Show story locations, cast overlap and point-of-view sequences. | Open | Full requirement not yet verified. |
| 332 | **Reader-facing exports.** Produce manuscripts, world guides or filtered companion encyclopedias. | Open | Full requirement not yet verified. |
| 333 | **Hybrid retrieval.** Combine semantic search, exact entity matching, relationship traversal and temporal filtering. | Open | Full requirement not yet verified. |
| 334 | **World-specific memory.** Maintain separate context for each universe, including long-running creative objectives. | Open | Full requirement not yet verified. |
| 335 | **Structured tool calling.** AI operations should use validated application commands, not direct uncontrolled database modifications. | Open | Full requirement not yet verified. |
| 336 | **Automatic relationship suggestions.** Detect potential connections from descriptions and propose them for review. | Open | Full requirement not yet verified. |
| 337 | **Implicit fact extraction.** Identify factual statements embedded in documents and present them as proposed structured facts. | Open | Full requirement not yet verified. |
| 338 | **Missing-information detection.** Discover unresolved properties that prevent a requested operation. | Open | Full requirement not yet verified. |
| 339 | **Dependency-based context selection.** Retrieve only the relevant connected information for a given question. | Open | Full requirement not yet verified. |
| 340 | **World-consistency reasoning.** Compare proposed changes with rules, history, geography and known character states. | Open | Full requirement not yet verified. |
| 341 | **Causal consequence generation.** Generate possible second-order effects and explicitly identify the assumptions behind them. | Open | Full requirement not yet verified. |
| 342 | **Alternative interpretation generation.** Offer multiple explanations for unresolved in-world mysteries. | Open | Full requirement not yet verified. |
| 343 | **Adaptive creative guidance.** Learn from explicitly accepted and rejected proposals within a particular world. | Open | Full requirement not yet verified. |
| 344 | **AI-generated test cases.** Create hypothetical situations to test whether world rules produce the intended behavior. | Open | Full requirement not yet verified. |
| 345 | **Model routing.** Use different AI models for writing, structured extraction, classification, planning and intensive reasoning. | Open | Full requirement not yet verified. |
| 346 | **Provider-agnostic AI.** Allow compatible local and hosted models when feasible. | Open | Full requirement not yet verified. |
| 347 | **Transparent context inspection.** Show what lore the assistant read before generating an answer. | Open | Full requirement not yet verified. |
| 348 | **Generation reproducibility.** Record the model, prompt configuration, relevant context and output for important operations. | Open | Full requirement not yet verified. |
| 349 | **Automated world summaries.** Generate summaries of entities, civilizations, historical periods and changes using traceable references. | Open | Full requirement not yet verified. |
| 350 | **Specialized collaborative agents.** Optional agents for cartography, chronology, economy, narrative and consistency, each with restricted responsibilities. | Open | Full requirement not yet verified. |
| 351 | **Creative goal tracking.** Maintain explicit project goals such as "complete the history of the Eastern Crossing." | Open | Full requirement not yet verified. |
| 352 | **Incremental world indexing.** Update search and context representations only for modified information. | Open | Full requirement not yet verified. |
| 353 | **Real-time multiplayer editing.** Allow several creators to edit the same universe. | Open | Full requirement not yet verified. |
| 354 | **Presence indicators.** Show which documents, maps or canvas frames collaborators are viewing. | Open | Full requirement not yet verified. |
| 355 | **Role-based permissions.** Owner, editor, contributor, commenter and viewer roles. | Open | Full requirement not yet verified. |
| 356 | **Canon approval permissions.** Only authorized collaborators can approve specific classes of changes. | Open | Full requirement not yet verified. |
| 357 | **Proposed edits from collaborators.** Contributors can submit changes for review. | Open | Full requirement not yet verified. |
| 358 | **Comments and discussion threads.** Discuss particular facts, regions, events or design decisions. | Open | Full requirement not yet verified. |
| 359 | **Collaborative Canvas.** Multiple cursors, selections and simultaneous spatial editing. | Open | Full requirement not yet verified. |
| 360 | **Shared creative sessions.** Work with other users in a common AI-assisted discussion. | Open | Full requirement not yet verified. |
| 361 | **Private documents and spoilers.** Restrict access to hidden lore, plot information and selected branches. | Open | Full requirement not yet verified. |
| 362 | **Public world encyclopedia.** Publish a browsable, read-only version of selected canonical lore. | Open | Full requirement not yet verified. |
| 363 | **Interactive world websites.** Publish Atlas, Timeline and entity profiles together. | Open | Full requirement not yet verified. |
| 364 | **Shareable individual views.** Create links to a specific character, map region or historical state. | Open | Full requirement not yet verified. |
| 365 | **Community templates.** Share world structures, entity schemas, Canvas templates and custom modules. | Open | Full requirement not yet verified. |
| 366 | **World cloning and remixing.** Duplicate an authorized public template into a new independent universe. | Open | Full requirement not yet verified. |
| 367 | **Import tools.** Support Markdown, JSON, CSV, existing writing documents and selected third-party worldbuilding formats. | Open | Full requirement not yet verified. |
| 368 | **Open export formats.** Export structured data, references, assets and chronology without proprietary lock-in. | Open | Full requirement not yet verified. |
| 369 | **Developer API.** Permit external tools to read and manipulate worlds subject to user-defined permissions. | Open | Full requirement not yet verified. |
| 370 | **Plugin SDK.** Allow community-built modules, simulations and visualizations. | Open | Full requirement not yet verified. |
| 371 | **External writing-tool integrations.** Synchronize selected documents with supported editors where APIs permit. | Open | Full requirement not yet verified. |
| 372 | **Optional local collaboration server.** Let users choose whether collaborative world data is hosted by Synthesis or self-managed. | Open | Full requirement not yet verified. |
| 373 | **Per-world configuration.** Set calendars, units, default entity types, conventions, canon rules and AI permissions separately for each world. | Open | Full requirement not yet verified. |
| 374 | **Global versus local preferences.** Clearly distinguish application-wide settings from world-specific ones. | Open | Full requirement not yet verified. |
| 375 | **Detailed AI configuration.** Providers, models, API credentials, context limits, data-sharing policies and cost controls. | Open | Full requirement not yet verified. |
| 376 | **Configurable automation permissions.** Specify which operations require confirmation and which can run without editing canon. | Open | Full requirement not yet verified. |
| 377 | **Custom keyboard shortcuts.** Allow users to rebind actions and export shortcut profiles. | Open | Full requirement not yet verified. |
| 378 | **Editor preferences.** Control autosave, spell-checking, typography, formatting and default views. | Open | Full requirement not yet verified. |
| 379 | **Graph performance settings.** Configure layout, rendering density, node clustering and label behavior. | Open | Full requirement not yet verified. |
| 380 | **Map performance settings.** Control texture quality, resolution, caching and layer rendering. | Open | Full requirement not yet verified. |
| 381 | **Offline-first operation.** Let users browse and edit local world data without internet access. | Open | Full requirement not yet verified. |
| 382 | **Reliable synchronization.** Use explicit conflict handling for offline edits and multiple devices. | Open | Full requirement not yet verified. |
| 383 | **Local backups and snapshots.** Provide scheduled backups, manual backups and recovery. | Open | Full requirement not yet verified. |
| 384 | **Restore preview.** Inspect a backup before replacing or merging world data. | Open | Full requirement not yet verified. |
| 385 | **Storage management.** Display database, image, attachment and generated-asset usage. | Open | Full requirement not yet verified. |
| 386 | **Index management.** Explain when search indexes are stale and allow safe rebuilding. | Open | Full requirement not yet verified. |
| 387 | **Background operation history.** Track completed, failed and canceled generation or indexing jobs. | Open | Full requirement not yet verified. |
| 388 | **Accessible interactions.** Keyboard navigation, screen-reader labels, focus outlines and color-independent status markers. | Open | Full requirement not yet verified. |
| 389 | **Reduced-motion support.** Respect accessibility preferences across transitions and map animations. | Open | Full requirement not yet verified. |
| 390 | **Responsive application layouts.** Handle smaller desktop windows without overlapping toolbars or clipped controls. | Open | Full requirement not yet verified. |
| 391 | **Application diagnostics.** Provide readable error details and recovery options for failed operations. | Open | Full requirement not yet verified. |
| 392 | **Data ownership controls.** Make local and remote storage choices explicit. | Open | Full requirement not yet verified. |
| 393 | **Sensitive-world permissions.** Prevent selected worlds or documents from being sent to external AI providers. | Open | Full requirement not yet verified. |
| 394 | **Versioned settings and schemas.** Ensure application updates do not silently damage existing worlds. | Open | Full requirement not yet verified. |

## Additional acceptance

- [ ] Seven unnumbered composer interactions in section 4, including budgets, spatial selections, drag-out and independent windows.
- [ ] All 31 module families in section 13 have meaningful schemas, editors, visualizations, validation and permitted AI operations where useful. Generic categories alone do not satisfy this.
- [ ] Shared-state architecture in section 20: temporal truth, beliefs, provenance, reversible commands, incremental views and reproducible simulation state.
- [ ] End-to-end Mira/remembrance workflow in section 24 across proposals, rules, hypothetical branches, Graph, Timeline, Atlas and Review.
- [ ] Experimental concepts in section 19 assessed individually; no generated fiction presented as calculations.
