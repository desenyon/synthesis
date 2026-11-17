# **Synthesis: Complete Product Overhaul & Expansion Plan**

After reviewing all 11 screenshots, I think Synthesis has a solid foundation, but its current capabilities are closer to a connected worldbuilding notebook than a complete worldbuilding environment.

You already have several important components: a conversational assistant, structured entities, a relationship graph, an atlas, a canvas, a timeline, a power-system editor, a canon review process, and hypothetical world branches.

The largest opportunity is **making these systems actually understand, affect, and operate on one another.**

For example, imagine telling Synthesis:

> The Glass Sea begins freezing permanently in Year 60. The Tidekeepers lose their monopoly over crossings. New settlements appear on the ice, and Mira Vale discovers that the art of remembrance no longer works there.

An advanced version of Synthesis should be capable of proposing a geographic transformation, calculating implications for travel and settlement, modeling the Tidekeepers' economic and political decline, identifying affected characters, creating a plausible sequence of events, updating relationships, and displaying the resulting changes on the atlas.

Every proposed change should remain inspectable and reversible. The user should decide which developments become canon.

That's the kind of depth I'd aim for.

## **1. The biggest problems in the current screenshots**

These are my immediate observations, based on the visible UI.

| Area           | Current issue                                                      | Recommended direction                                                                      |
| -------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| Overall design | Large black empty areas, flat surfaces, minimal visual hierarchy   | More deliberate spatial composition, layered surfaces, stronger typography                 |
| Sidebar        | Entire navigation stays visible, even when working inside one tool | Context-aware navigation, customizable collections, collapsible sections                   |
| Conversation   | AI suggestions appear as long, fairly basic change cards           | A full creative workspace with previews, comparisons, simulation and structured operations |
| Canvas         | Basic cards, connectors and floating toolbars                      | A powerful spatial editor with embedded interactive components                             |
| Graph          | Small nodes, overlapping relationships, substantial unused space   | Semantic knowledge graph with filters, traversal, clustering and advanced layouts          |
| Atlas          | Attractive illustrated map, but relatively simple marking tools    | A geographic information system specifically for fictional worlds                          |
| Timeline       | Primarily an event list grouped by period                          | Visual chronology, branching histories, causality and time-dependent world states          |
| Entity editor  | Nine words of content occupy an enormous blank editor              | Adaptive structured profiles, rich documents, interactive entity-specific interfaces       |
| Power systems  | Technique tree appears limited to prerequisites and unlocks        | A complete rules, progression, cost, restriction and balancing engine                      |
| Review         | Basic contradiction checks and accept/dismiss actions              | Dependency analysis, change previews, consistency checks and version control               |
| Settings       | A sparse preferences page with basic toggles                       | A proper configuration center for AI, data, world rules, tools and integrations            |
| AI/Manual mode | A global switch with little visible explanation                    | Granular control over what the AI may read, propose, simulate or modify                    |

There are also several cross-application issues:

- **Canvas and Graph overlap conceptually.** Canvas should be a manually arranged thinking space; Graph should be an automatically maintained view of the world's actual relationships.
- **Your composer appears on nearly every screen**, sometimes obscuring valuable workspace. It needs responsive docking, compact mode and deliberate interaction states.
- **Dark mode relies too heavily on pure black.** A very dark graphite workspace with subtle surface separation would provide better depth without adding unnecessary color.
- **The app is visually consistent but the tools do not look equally capable.** Atlas looks impressive, while Timeline, Review and the entity editor look closer to early prototypes.
- **The app currently exposes records more prominently than operations.** Users can see what exists, but the interface does not sufficiently communicate everything they can do with their worlds.

## **2. The systems I'd build the entire application around**

**World intelligence engine**

Understands entities, relationships, rules, history, geography, consequences, conflicting accounts and the reasons behind every established fact.

**Simulation engine**

Lets users explore how civilizations, characters, ecosystems, economies, technologies and power systems behave under particular conditions.

**Creative version-control engine**

Supports alternative histories, experiments, proposals, canon approvals, merges, consequences, rollback and a complete record of how a world evolved.

**Unified creation environment**

Connects chat, maps, diagrams, documents, graphs, timelines, structured data and simulations into one workspace with multiple ways of examining the same world.

These four systems would provide the foundation for the following feature expansions.

## **3. Global UI and workspace redesign**

The design should feel like a professional creative application, with the density and control of a developer tool and the flexibility of a visual editor.

### **Visual design upgrades**

1. **Replace pure-black content backgrounds.** Use a dark graphite base, slightly lighter sidebars, and distinct raised surfaces. Preserve true black as an optional OLED theme.
2. **Introduce restrained frosted-glass surfaces.** Use translucent, lightly blurred treatments for floating toolbars, popovers, inspectors and the AI composer. Avoid putting glass behind every panel.
3. **Create a proper design-token system.** Standardize surface colors, stroke opacity, spacing, typography, corner radii, shadows and interaction states.
4. **Improve typography hierarchy.** Entity titles should dominate their pages; metadata and controls should be visually subordinate. Currently several headings, tooltips and content labels compete at almost the same scale.
5. **Use category-specific visual identities.** Characters, factions, locations, magic systems and historical events can each have an understated color and icon, consistent across all views.
6. **Support adjustable information density.** Compact, comfortable and immersive modes should alter row height, card dimensions and spacing.
7. **Introduce intentional empty states.** A mostly empty character profile could offer a portrait, biography prompts, relationship map and timeline, instead of displaying a large unoccupied editor.
8. **Improve microinteractions.** Use restrained transitions when selecting entities, opening panels, navigating relationships and accepting changes.
9. **Make all toolbars contextual.** Atlas should display geography tools, Graph should display relationship tools, and Canvas should display spatial authoring tools.
10. **Support collapsible contextual inspectors.** Each page should have an optional right-hand inspector that reveals object properties without opening a separate page.
11. **Add breadcrumbs and navigation history.** Moving from Mira Vale to Tidekeepers to the Glass Sea should create a reversible navigation trail.
12. **Provide saved workspace layouts.** Users should be able to save arrangements such as Research, Writing, Cartography or Simulation.
13. **Create an actual welcome dashboard.** Show recently edited entities, world activity, open proposals, unfinished writing and shortcuts to active projects.
14. **Improve light mode.** Use clearer separation between canvas, sidebar, floating controls and entity surfaces. The light Canvas screenshot currently appears washed out.
15. **Add semantic zoom.** When zooming out of a graph, show compact entity titles; when zooming in, progressively reveal descriptions, images and relationships.
16. **Allow multiple open documents.** Tabs should support reopening recent entities, pinning important documents and switching without losing editor state.
17. **Add independent scroll regions.** The inspector, document and navigation sidebar should scroll separately, without moving the entire workspace.
18. **Introduce better progress and status feedback.** Saving, indexing, generating, reviewing and simulation operations need clear states, especially when an operation takes time.
19. **Make panels resizable.** Sidebar width, inspector width and the chat dock should be user adjustable.
20. **Standardize hover and selection behavior.** A selected entity should look selected everywhere, with the same border, accent and interaction semantics.

### **Workspace and navigation**

21. **Universal command palette.** `⌘K` should find entities, commands, scenes, tools, settings, maps and recent changes.
22. **Global search with advanced syntax.** Support searches such as `type:character faction:Tidekeepers` or `status:canon updated:7d`.
23. **Customizable sidebar.** Allow users to rearrange sections, hide unused categories and pin favorite collections.
24. **Favorite entities and collections.** A pinned set of characters, locations or documents should stay immediately accessible.
25. **Recent activity history.** Show edits, approvals, newly discovered relationships and changes across the whole world.
26. **Split workspace.** Open a character profile beside the atlas, timeline, graph or another entity.
27. **Drag-to-open.** Drag an entity from search or the sidebar directly into another pane or onto a canvas.
28. **Context-preserving navigation.** Returning to Atlas should restore the previous zoom, active layer, selected region and viewport.
29. **Global back/forward navigation.** Treat document, map and tool navigation consistently.
30. **Keyboard-first creation.** Provide shortcuts for creating entities, linking records, opening inspectors, switching modes and navigating history.
31. **Custom home views.** Users could choose Atlas, Conversation, Dashboard, Canvas or their last workspace as the startup screen.
32. **Focusable workspaces.** Writing mode could temporarily hide the sidebar, inspectors and unrelated tools.
33. **Session restoration.** Reopen all documents, tabs, views, selected entities and unsent drafts after an application restart.
34. **Universal quick capture.** A single shortcut opens a small window to record an idea without disrupting the current workflow.
35. **Cross-workspace drag and drop.** Any entity, event, source, image or proposal can become a reference within another tool.

## **4. Transform Conversation into an actual creative command center**

The conversation view currently resembles a standard AI chat with additional proposal cards.

I'd make it the main interface through which users can operate the whole world.

### **Advanced conversational capabilities**

36. **Natural-language world operations.** Commands like "Create three competing coastal factions and connect them to the Tidekeepers" should create a reviewable batch of structured proposals.
37. **Multi-step planning.** The assistant should plan complex changes, show the intended operations and let users approve the plan before execution.
38. **Grounded answers with internal references.** Every factual claim about the world should be traceable to specific established lore.
39. **Source inspection.** Clicking a cited passage should open the relevant section of the underlying entity or document.
40. **Temporal awareness.** Asking "Who controlled the Glass Sea in Year 40?" should use the world state from Year 40.
41. **Character knowledge awareness.** "What does Mira know about the Drowned City?" should consider only information available to Mira at that point.
42. **Uncertainty-aware answers.** The assistant should distinguish established facts, unresolved questions, conflicting accounts and new suggestions.
43. **Conversation branching.** Branch at any user or assistant message to explore an alternative creative direction without losing the original discussion.
44. **Reusable prompt recipes.** Save instructions for character development, historical analysis, political simulation, plot critique or culture generation.
45. **Structured AI output.** An answer could produce a timeline, map overlay, character comparison, graph, rule table or editable entity instead of only text.
46. **Interactive proposal previews.** Show what would change in each tool before committing the proposed operations.
47. **Context pinning.** Temporarily pin Mira Vale, the Tidekeepers and a relevant historical period as mandatory context.
48. **Context exclusions.** Explicitly exclude particular drafts, branches, noncanon material or spoiler-heavy documents.
49. **Multiple assistant working modes.** Offer Create, Research, Critique, Simulate, Organize and Explain. Each mode should have distinct behavior and tools.
50. **Research-first questioning.** Let users select a mode where the assistant investigates inconsistencies and asks questions before proposing new lore.
51. **Configurable originality.** Permit conservative continuations, moderate invention or highly exploratory suggestions.
52. **Creative constraints.** Define requirements such as "no resurrection," "magic is hereditary," or "technology cannot exceed the early industrial era."
53. **Long-running creative sessions.** Maintain goals, unanswered questions, working decisions and previous rejected ideas across conversations.
54. **Conversation-to-world conversion.** Select a conversation passage and turn it into an entity, event, relationship, rule or collection of changes.
55. **Inline entity editing.** Open an entity inspector directly from an AI response.
56. **Regenerate only part of an answer.** Rewrite one faction, rule or character concept without regenerating the entire response.
57. **Compare generations.** Place multiple AI responses side by side, with the ability to combine selected ideas.
58. **Background world checks inside the application.** When enabled, the app can prepare consistency suggestions after edits, without modifying canon.
59. **Explicit AI execution permissions.** Separate what the AI can read, generate, propose, simulate and save.
60. **Per-operation cost visibility.** Show model usage, approximate token costs and configurable usage limits for external AI providers.

### **A proper conversation composer**

I'd replace the current basic message box with a compact but expandable composer.

**World assistant**

Illustrative design

What should happen in Aster?

&#x20;The Glass Sea

&#x20;Tidekeepers

&#x20;Year 60

Explore

Canon protected

World context

New composer interactions:

- Attach entities, maps, timeline ranges, image references or entire canvas frames.
- Choose whether the response should create proposals or remain exploratory.
- Adjust a reasoning or generation budget.
- Preview which world records will be included in the AI context.
- Insert a selected graph subnetwork or geographic region into the conversation.
- Drag AI-generated objects straight into Canvas or Atlas.
- Pop the composer into a side panel or independent floating window.

## **5. A much deeper world database and entity editor**

This may be the most important technical upgrade.

Your current entity editor appears mostly document-driven. Long-form writing is useful, but sophisticated worldbuilding requires structured data underneath the prose.

### **Entity architecture**

61. **Custom entity types.** Let users define categories beyond the predefined Characters, Systems, Places and Power Systems.
62. **Custom field schemas.** A character might have ancestry, affiliations, birthplace, abilities, languages, allegiances and death status.
63. **Typed fields.** Support numbers, dates, ranges, durations, selections, formulas, linked entities, coordinates, media and computed values.
64. **Conditional fields.** A deceased character can expose a death event and cause of death; a living character need not.
65. **Reusable templates.** Create standardized profiles for kingdoms, characters, settlements, species, artifacts and organizations.
66. **Entity inheritance.** A derived species or subclass could inherit attributes from a parent type while overriding selected fields.
67. **Bidirectional relationships.** If Mira belongs to the Tidekeepers, the Tidekeepers should automatically list Mira.
68. **Relationship attributes.** Record start and end dates, strength, secrecy, mutuality, status and the evidence supporting a connection.
69. **Multiple relationship meanings.** Distinguish mentor, political superior, legal guardian, former ally, rival and unknown relationship types.
70. **Names and aliases across time.** An organization might change its name after a revolution while retaining a single identity.
71. **Entity lifecycle.** Support creation, transformation, dissolution, merger, succession and destruction.
72. **Atomic facts beneath prose.** Store important assertions separately so the application can reason about them without trying to reinterpret entire documents every time.
73. **Fact-level provenance.** Record who established a fact, when it was established, and which document or event supports it.
74. **Canon states at fact level.** A character profile can contain canon, draft and disputed statements without labeling the entire character identically.
75. **In-world perspectives.** A historical event may have an objective description and conflicting interpretations from different factions.
76. **Time-dependent attributes.** A character's location, title, age and allegiance should change with the current historical date.
77. **Computed properties.** Age, travel distance, faction population, genealogical relationship and inventory totals can be calculated.
78. **Entity dependency tracking.** The app should know which rules, events and characters depend on another entity's attributes.
79. **Entity duplication and variants.** Duplicate a character into a new branch while preserving its ancestry and original references.
80. **Bulk editing.** Select dozens of records and modify tags, categories, affiliations, status or ownership together.
81. **Automatic backlinks.** Find both explicit links and textual mentions, while keeping those two types distinct.
82. **Entity merging.** Combine duplicate records with a field-by-field conflict resolution interface.
83. **Record archival.** Hide unused records without breaking existing references.
84. **Custom validation.** Set constraints such as unique royal titles during a given period, or birth dates before death dates.

### **Redesign the editor itself**

85. **Modular entity pages.** Profiles should consist of movable modules, not a single giant text field.
86. **Cover artwork and portraits.** Include optional character portraits, location artwork or faction banners.
87. **Rich-text blocks.** Support headings, collapsible sections, callouts, tables, code, equations, galleries and embedded media.
88. **Inline linked entities.** Typing `@Tidekeepers` should create a live reference with hover previews.
89. **Structured infoboxes.** Show the most useful attributes at a glance.
90. **Tabbed entity views.** Overview, Details, Relationships, History, Media, Mechanics and Versions should expose distinct information.
91. **Automatic relationship panels.** Show connected characters, factions, places and events without requiring manual duplication.
92. **Inline timeline.** A character's profile should display their personal chronology.
93. **Contextual maps.** Display birthplace, current location, journey history and territory in appropriate profiles.
94. **Field-level edit history.** Compare who changed a specific attribute and restore earlier values.
95. **Editor comments and annotations.** Keep unresolved questions attached to specific text.
96. **Content completion suggestions.** Suggest missing biography fields or relevant relationships without forcing completion.
97. **Editable section templates.** Different entity categories should have different layouts.
98. **Distraction-free writing.** Provide a document-first mode that hides structured data until requested.
99. **Automatic summaries.** Generate a short synopsis from a long entity profile, with citations back to the original text.
100. **Sidebar inspector for selected text.** Highlight a character name to create or inspect a link, relationship, event or fact.

The key is to keep writing comfortable while making the underlying information usable by every other part of Synthesis.

## **6. Canvas: turn it into a real spatial development environment**

Your Canvas resembles a node-based board with image and text cards. It's visually understandable, but most of its apparent interactions are common to general-purpose whiteboarding tools.

The ideal Canvas should allow users to construct complex world systems visually.

101. **Interactive entity blocks.** Character, faction, map, event and rule nodes should have specialized designs and controls.
102. **Live bidirectional synchronization.** Editing an entity inside Canvas should update its actual record; changing the entity elsewhere should refresh Canvas.
103. **Nested frames and groups.** Create expandable boards within boards for individual plots, factions or regions.
104. **Multiple canvas layers.** Separate geography, narrative, relationships, mechanics and research without creating unrelated documents.
105. **Custom relationship connectors.** Support directed, undirected, conditional, reciprocal, historical and conflicting relationships.
106. **Smart connection creation.** Dragging between two entities should offer valid relationships based on their types.
107. **Conditional nodes.** Represent decisions, requirements, consequences and alternative outcomes directly on the board.
108. **Embedded map viewports.** A live Atlas selection should be available as an interactive Canvas object.
109. **Embedded timeline views.** Display a filtered historical period or a character's chronology inside a frame.
110. **Interactive simulation nodes.** Attach a simulation to a set of entities and inspect its results without leaving Canvas.
111. **Custom database tables.** Place editable entity collections directly on the canvas.
112. **Live charts and diagrams.** Show population histories, magic progression curves, resource networks or faction influence.
113. **AI-powered canvas operations.** Commands such as "Group these kingdoms by alliance" should manipulate the selected objects.
114. **Automatic layouts.** Offer hierarchy, flowchart, timeline, circular, force-directed and grid arrangements.
115. **Region-based selection.** Select objects inside a freeform lasso, rectangle or named frame.
116. **Alignment and snapping.** Add guides, distribution commands, grids and smart spacing.
117. **Minimap and viewport bookmarks.** Essential when a board becomes very large.
118. **Canvas presentations.** Turn frames into a guided walkthrough with transitions and presenter notes.
119. **Canvas history.** Replay changes, compare prior states and restore individual objects.
120. **Reusable components.** Save entire node groups as templates for governments, settlements or character arcs.
121. **Cross-canvas references.** An object on one board can link to another board without being copied.
122. **Canvas-specific AI context.** Ask the assistant to explain only the selected nodes and connections.
123. **Interactive sticky notes, sketches and annotations.** Permit freeform exploration without requiring everything to become structured lore.
124. **Visual state indicators.** Make draft, canon, disputed and hypothetical records identifiable without opening each card.

**Biggest UI fix:** the lower composer, right-hand toolbar and card content should stop competing for the same viewport. The canvas needs genuine fullscreen mode, auto-hiding tools and an optional docked AI panel.

## **7. Graph: build an actual knowledge exploration engine**

Your Graph screenshot shows seven entities and eight relationships, but the nodes are relatively small and multiple connection labels overlap.

A sophisticated Graph should be useful for exploration and analysis, rather than functioning solely as a visualization of connections.

125. **Multiple graph layouts.** Hierarchical, force-directed, radial, geographic, chronological and community-clustered.
126. **Relationship filtering.** Show only family, political, geographical, magical, historical or user-defined connections.
127. **Entity-type filtering.** Isolate characters, settlements, artifacts or factions.
128. **Temporal graph mode.** Display the relationships that existed during a specific year or era.
129. **Neighborhood exploration.** Select an entity and expand one, two or more degrees of connection.
130. **Pathfinding between entities.** Find the shortest or most relevant relationship chain connecting two records.
131. **Influence analysis.** Rank entities by configurable network measures, without equating high connectivity with narrative importance.
132. **Community detection.** Identify tightly connected groups that users may want to turn into collections or factions.
133. **Relationship strength.** Let users assign qualitative or numerical weights to relevant connections.
134. **Conflict detection.** Flag mutually incompatible relationship claims with supporting evidence.
135. **Duplicate edge handling.** Collapse equivalent connections and clearly differentiate reciprocal relationships.
136. **Relationship history.** Select an edge to see how the connection evolved.
137. **Expandable node cards.** Hover or select to reveal portraits, descriptions, metadata and actions.
138. **Progressive rendering.** Replace detailed cards with compact representations as graph density increases.
139. **Graph search and focus.** Search for an entity and smoothly center its neighborhood.
140. **Saved graph queries.** Store views such as "Political power during Year 40" or "Everyone connected to Mira."
141. **Comparative graphs.** Compare two periods or alternative histories with added, removed and changed edges.
142. **Graph-to-Canvas extraction.** Copy a selected subnetwork into a Canvas as live references.
143. **Graph annotations.** Save observations separately from the underlying relationships.
144. **Graph clustering and edge bundling.** Reduce long connection crossings and unreadable labels.
145. **Graph analytics panel.** Show isolated records, relationship coverage, suspicious cycles and disconnected groups.

An especially useful interaction would be right-clicking a relationship and choosing **Explain**, **Show history**, **Find consequences** or **Explore alternative**.

## **8. Atlas: make this one of the application's standout tools**

Your Atlas has the strongest immediate visual appeal. The map already establishes a sense of place. The existing marker and region tools could become the entrance to an entire geographic simulation and cartography environment.

### **Mapping and cartography**

146. **Multiple maps per world.** Planets, continents, countries, cities, buildings, dungeons, celestial regions and alternate dimensions.
147. **Hierarchical maps.** Selecting a country opens its regional map; selecting a city opens a settlement map.
148. **Map layers.** Terrain, elevation, borders, settlements, roads, climate, population, political influence, resources, trade routes and magic.
149. **Custom layer creation.** Users should be able to define any visual layer, with custom geometry and metadata.
150. **Time-dependent map states.** Move a year slider to show different borders, settlements and geographical conditions.
151. **Advanced region editing.** Include polygon holes, vertex snapping, unions, intersections, splitting and merging.
152. **Geographic object linking.** Connect map regions to real entities in the world database.
153. **Road, river and route tools.** Support curved paths, branching networks, travel directions and connections.
154. **Distance measurement.** Establish map scale and calculate distance between points or along paths.
155. **Travel-time calculation.** Use terrain, transport mode, road networks, weather and configurable movement rules.
156. **Custom coordinate systems.** Support fictional planetary dimensions, non-Earth calendars and unusual geographical models.
157. **Terrain editing.** Let users paint mountains, coastlines, lakes, forests, deserts and elevation masks.
158. **Procedural terrain generation.** Generate landscapes from adjustable seeds and constraints, with manual corrections.
159. **Hydrology tools.** Create or estimate rivers, watersheds, lakes and drainage networks based on elevation.
160. **Climate modeling.** Estimate broad climate zones from latitude, elevation, prevailing winds and other user-supplied assumptions.
161. **Seasonal overlays.** Show snow coverage, rainfall, river flooding, desertification and agricultural cycles.
162. **Population overlays.** Display settlement density, migration and regional demographics over time.
163. **Political maps.** Show disputed borders, spheres of influence, occupied territories and historical claims.
164. **Trade route visualization.** Map trade networks, transport bottlenecks, important ports and resource flows.
165. **Military campaign tools.** Represent armies, supply lines, contested regions and changing control.
166. **Map-based event placement.** A timeline event can refer to one or several specific locations.
167. **Fog of war.** Hide locations and geographic details based on a character's or faction's knowledge.
168. **Map styles.** Offer political, topographic, nautical, parchment, satellite-inspired, hand-drawn and schematic rendering.
169. **Map import and tracing.** Import raster or vector artwork, calibrate scale and place structured geometry over it.
170. **Map export.** Export print-quality images, layered files, transparent overlays and interactive read-only views.
171. **Place-level inspectors.** Selecting a city should display its population, government, history, inhabitants and related events.
172. **Map annotations.** Support labels, symbols, legends, scale bars and decorative elements that do not alter world data.
173. **Geographic search.** Find places by name, region, ownership, population, terrain or historical state.
174. **Atlas minimap and navigation bookmarks.** Jump between continents, important regions or saved camera positions.
175. **Compare-map mode.** Overlay two historical or hypothetical states with a transparency slider.

### **Geographic mechanics beyond drawing**

176. **Territorial expansion simulation.** Model changes in control from settlement, conquest, alliances or administrative decisions.
177. **Settlement viability analysis.** Examine water availability, terrain, transport access and resources before proposing a new city.
178. **Infrastructure planning.** Draw potential roads, ports and canals, then estimate their effects on travel and trade.
179. **Environmental change simulation.** Explore floods, volcanic eruptions, changing sea levels and other events.
180. **Character journey playback.** Animate a character's route along the atlas based on documented events.
181. **World-scale consistency checks.** Flag impossible or unsupported journeys, geographic contradictions and mismatched map distances.
182. **Interactive map storytelling.** Associate a story, historical event or narrated sequence with a specific location.
183. **Map-linked AI generation.** Select a territory and request plausible settlements, cultures or conflicts based on its known attributes.

One especially powerful feature would be a historical Atlas with a timeline slider. Watching the Tidekeepers' control of the Glass Sea expand, fragment and disappear should require no manual reconstruction of the map for each period.

## **9. Timeline: replace the event list with a historical modeling tool**

The current Timeline supports periods, branches and events. That's a good starting data structure, but it needs multiple visualizations and more sophisticated temporal logic.

184. **True horizontal timeline.** Display events on a scalable chronological axis.
185. **Zoomable time scales.** Move from millennia to years, months, days or hours.
186. **Custom calendars.** Define the length of years, months, weeks and days.
187. **Multiple calendar systems.** Convert between imperial, religious, regional or astronomical dates.
188. **Relative chronology.** Support events dated "three winters after the crossing" without inventing an absolute date.
189. **Uncertain dates.** Store ranges, approximate dates, disputed dates and unknown dates explicitly.
190. **Event dependencies.** Make it possible to declare that an event requires another event to have occurred first.
191. **Causal event chains.** Link a famine to migration, political instability or other downstream consequences.
192. **Parallel timeline tracks.** Compare different characters, nations, conflicts or storylines in synchronized lanes.
193. **Personal timelines.** Automatically assemble a character's life history from linked events.
194. **Territorial histories.** View events associated with a selected location or region.
195. **Branching chronology.** Display alternative historical paths with visible divergence points.
196. **Timeline playback.** Move through events while Atlas and Graph update to the corresponding period.
197. **Interactive event expansion.** Open details, participants, causes, outcomes and related world changes.
198. **Event drag and rescheduling.** Move an event to another time and preview affected dependencies.
199. **Duration-based events.** Represent wars, migrations, reigns and environmental changes as spans instead of single points.
200. **Era and period hierarchy.** Allow periods inside larger ages, with overlapping or competing chronologies where appropriate.
201. **Historical comparison.** Compare the world before and after a major event.
202. **Automatic event extraction.** Identify possible dates and historical events in written lore and propose structured timeline entries.
203. **Chronology validation.** Detect age contradictions, impossible travel schedules and circular event dependencies.
204. **Historical uncertainty visualization.** Use distinct markers for disputed or approximate dates.
205. **Event intensity visualization.** Display concentrations of activity across eras, with configurable filters.
206. **Story chronology versus world chronology.** Track both when events happened and when readers discover them.
207. **Future planning.** Draft upcoming events as possibilities without establishing them as canonical history.
208. **Alternate-history comparison.** Show what changed after a selected divergence point.

**The defining interaction:** selecting Year 52 should change the information shown in Atlas, Graph, entity profiles, faction relationships and the assistant's answers.

That would make time a property of the entire application, instead of a separate page.

## **10. Power systems: turn technique trees into functional rule engines**

Your technique tree has prerequisites and progression, but this is an area where Synthesis could become particularly interesting.

It should let someone design a sophisticated cultivation system, magic system, technology tree or supernatural framework, then test whether its internal rules hold together.

### **Mechanics and progression**

209. **Formal power-system definitions.** Define energy sources, costs, restrictions, governing principles and exceptions.
210. **Resource models.** Create mana, spiritual energy, stamina, divine authority, memories, lifespans or custom resource types.
211. **Progression frameworks.** Support cultivation realms, ranks, classes, levels, stages, transformations and custom advancement models.
212. **Multiple progression paths.** Let characters specialize in different branches and combine eligible techniques.
213. **Technique prerequisites.** Support attribute requirements, completed training, resources, lineage, special locations and previous abilities.
214. **Conditional unlocks.** A technique could require two specific skills, one rare artifact and a completed event.
215. **Mutually exclusive paths.** Choosing one advancement can permanently prohibit another.
216. **Technique combinations.** Define how abilities interact, reinforce or suppress one another.
217. **Mathematical ability scaling.** Express damage, efficiency, duration, range or resource consumption through customizable formulas.
218. **Attribute systems.** Define strength, perception, aptitude, concentration, affinity and other setting-specific attributes.
219. **Training simulation.** Estimate progression under specified training schedules, talent assumptions and resource availability.
220. **Individual skill profiles.** Track what each character has learned, mastered, forgotten or lost.
221. **Power inheritance.** Support hereditary abilities, bloodlines, acquired traits and inherited restrictions.
222. **Counter-technique systems.** Specify weaknesses and conditional counters instead of manually declaring every encounter outcome.
223. **Equipment interactions.** Allow artifacts, weapons or environments to alter an ability's behavior.
224. **Dynamic energy environments.** A location can amplify, suppress or prevent certain techniques.
225. **Power-system exceptions.** Maintain explicit exceptions with explanations and affected rules.
226. **Technique versioning.** Track abilities that evolve or are modified after major events.
227. **Technique testing sandbox.** Create fictional encounters to examine whether abilities behave as intended.
228. **Exploit detection.** Identify combinations that permit infinite energy, unrestricted replication or other unwanted outcomes under the authored rules.
229. **Progression bottleneck analysis.** Reveal unreachable techniques, missing prerequisites and impossible progression paths.
230. **Power comparison.** Compare characters using attributes, abilities and circumstances without blindly assigning an arbitrary winner.
231. **Visual rule inspector.** Select any node and display prerequisites, effects, costs, restrictions and dependents.
232. **Custom mechanics editors.** Support alternative systems such as alchemy, crafting, scientific technologies, biological adaptation or political authority.

For example, in Aster, borrowing a memory could increase a character's power but permanently remove access to particular knowledge. Synthesis should track the associated memory loss, change what that character knows, and detect when a later scene depends on something they have forgotten.

That is far more interesting than a skill tree that only records unlocks.

## **11. Build a world simulation engine**

This is where I'd invest heavily after establishing the underlying data model.

An actual simulation engine should use explicit rules, state variables and defined assumptions. AI can generate scenarios and explain outcomes, but should not invent numerical precision or silently replace the simulator's results.

### **Character and social simulation**

233. **Character agents.** Give characters persistent goals, resources, capabilities, relationships and beliefs.
234. **Personality and decision models.** Define motivations, preferences, loyalties and how they respond to events.
235. **Knowledge-limited decision-making.** Characters should act on what they believe, which may differ from the world's actual state.
236. **Dynamic relationships.** Relationships evolve in response to events, betrayal, cooperation, proximity and conflicting goals.
237. **Goal conflict simulation.** Explore what happens when multiple characters pursue incompatible objectives.
238. **Character life simulation.** Model movement, occupation, training, major life events and affiliations at a configurable level of detail.
239. **Reputation systems.** Track how different factions perceive an individual or organization.
240. **Information and rumor propagation.** Model which populations learn about an event, when, and through which channels.
241. **Social hierarchy modeling.** Represent class systems, titles, privileges, institutions and social restrictions.
242. **Narrative consequence exploration.** Ask how a character's choice could affect other characters, factions and future events.

### **Civilization and political simulation**

243. **Faction agents.** Organizations can have goals, leadership, resources, territory and internal disagreements.
244. **Diplomatic relationships.** Support treaties, alliances, hostility, trade agreements, vassalage and neutrality.
245. **Government systems.** Model succession, elections, hereditary rule, councils, coups and institutional power.
246. **Political instability modeling.** Explore how shortages, succession disputes and public dissatisfaction affect a government.
247. **Trade and resource systems.** Track production, consumption, movement, shortages and dependencies.
248. **Economic simulation.** Use configurable systems for currencies, wages, taxes, production and exchange.
249. **Population modeling.** Track demographics, birth and death assumptions, migration and settlement growth.
250. **Migration simulation.** Explore how climate, conflict, opportunity or persecution changes where populations live.
251. **Military logistics.** Estimate supply consumption, travel and other constraints within fictional campaigns.
252. **Civilization development.** Simulate gradual changes in infrastructure, institutions, technology and resource access.
253. **Cultural diffusion.** Model the spread of languages, practices, inventions and beliefs along contact networks.

### **Environmental and systemic simulation**

254. **Ecological systems.** Represent food webs, habitats and interactions among species.
255. **Climate-driven events.** Explore long-term consequences of changing rainfall, temperature or sea levels.
256. **Disease and population disruption.** Model fictional outbreaks using explicitly configured transmission and recovery rules.
257. **Resource depletion.** Track finite materials, replenishment and environmental pressures.
258. **Magical environmental effects.** If magic changes geography, climate or biology, those effects should influence relevant simulations.
259. **Technological diffusion.** Estimate how new inventions spread between connected populations.
260. **Simulation time controls.** Run an hour, a year, a century or a custom time interval.
261. **Simulation granularity.** Choose whether to simulate individuals, settlements, regions or entire civilizations.
262. **Seeded simulation runs.** Reproduce the same run using stored starting conditions, parameters and random seeds.
263. **Scenario comparison.** Compare outcomes with and without a specific change.
264. **Sensitivity analysis.** Identify which assumptions influence the result most.
265. **Simulation traces.** Inspect why a particular outcome occurred.
266. **User interventions.** Change assumptions or introduce new events while a simulation is paused.
267. **Simulation snapshots.** Save results as hypothetical states that can later become proposals.
268. **Consequence visualizations.** Display changed territories, relationships, populations and events on the existing tools.

### **A dedicated Simulation workspace**

**Simulation Studio**

Concept

What if the Glass Sea freezes?

Starting period

**Year 60**

Simulation horizon

**50 years**

Systems enabled

**Trade, migration, politics**

Starting state

**Canonical world**

Illustrative outcomes for a hypothetical run, not calculated predictions.

**Tidekeepers lose control of sea crossings**

Candidate consequence from reduced maritime dependence

**Overland settlements appear on the frozen sea**

Depends on ice stability and available resources

**New political relationships emerge**

Explore with faction decision models

I would allow users to inspect the proposed effects and then promote selected outcomes to a hypothetical branch. Nothing generated by a simulation should automatically become canon.

## **12. Review, canon and alternative histories**

Your existing Review system is one of the better architectural decisions visible in the screenshots. Keep the separation between accepting a draft and establishing canon.

Now extend it into a real system for managing a fictional universe's continuity.

269. **Atomic change sets.** Group all proposed edits from one action into a single reviewable operation.
270. **Dependency-aware review.** Show which changes rely on other proposed changes.
271. **Before-and-after previews.** Display exact modifications to entity fields, documents, maps and timelines.
272. **Change impact analysis.** Identify every directly affected entity and the derived information that may need recalculation.
273. **Three-way branch merging.** Compare an alternative branch with its original ancestor and the current canonical state.
274. **Selective merging.** Accept only the parts of a hypothetical scenario that the user wants.
275. **Conflict resolution UI.** Choose between competing values or create a new reconciled version.
276. **Undoable operations.** Make approved changes reversible, with dependent operations handled safely.
277. **Complete change provenance.** Record the user action, source context and generated proposal behind each alteration.
278. **Canon locks.** Protect specific facts or entities from modification without explicit authorization.
279. **Canonical invariants.** Define rules that every accepted change must satisfy.
280. **Intentional inconsistencies.** Mark contradictions as deliberate mysteries, unreliable narratives or unresolved disputes.
281. **Contradiction classifications.** Separate factual conflicts, temporal conflicts, missing references, duplicate records and semantic disagreements.
282. **Explainable checks.** Show the exact conflicting facts and relevant sources, not merely a warning.
283. **Suggested repair operations.** Offer minimal changes that would resolve a detected inconsistency.
284. **Incremental validation.** Recheck affected records after edits instead of scanning the entire world unnecessarily.
285. **Review queues by scope.** Filter proposals for a character, region, historical period, document or branch.
286. **Saved review policies.** Allow different approval rules for experimental and canonical material.
287. **Canon milestones.** Create named snapshots such as "Before the Long Tide" or "First published version."
288. **Restore and replay.** View the world at a previous revision or restore a prior version.
289. **Approval summaries.** Show the resulting changes to world state after a batch has been applied.
290. **Custom consistency checks.** Let users define rules for their own settings.
291. **Review comments.** Attach questions and explanations to individual proposed operations.
292. **Distinguish references from implications.** A document mentioning another entity does not necessarily mean the records should have a formal relationship.

An important example already appears in your screenshot: Mira Vale and Oren Ashe apparently mentor one another, and Review flags the relationship.

The system should recognize several possible explanations: a mistaken edge, mentorship during different periods, separate kinds of mentorship, or a genuinely reciprocal relationship. Deleting an edge should be one possible resolution, not an automatic assumption.

## **13. New worldbuilding modules that are currently missing from the visible navigation**

I would not put every module directly in the sidebar. Build a modular system where users enable the ones relevant to their worlds, and organize them under customizable collections.

| Module                        | What it should support                                                                   |
| ----------------------------- | ---------------------------------------------------------------------------------------- |
| **Factions & Organizations**  | Membership, leadership, hierarchy, goals, resources, rivalries and institutional history |
| **Politics & Governments**    | Laws, succession, constitutions, elections, governance models and territorial authority  |
| **Economics**                 | Currencies, markets, production, consumption, taxes, budgets and trade                   |
| **Societies & Cultures**      | Customs, festivals, class systems, occupations, traditions and social norms              |
| **Languages**                 | Phonology, scripts, vocabulary, grammatical rules, dialects and language evolution       |
| **Religions & Beliefs**       | Deities, doctrines, sects, rituals, religious institutions and theological disagreements |
| **Species & Races**           | Biology, ancestry, reproduction, habitats, cultural diversity and historical development |
| **Genealogy**                 | Family trees, inheritance, marriages, descendants, dynasties and disputed parentage      |
| **Flora & Fauna**             | Organisms, habitats, adaptations, ecological interactions and population changes         |
| **Artifacts & Items**         | Ownership, crafting, materials, abilities, limitations and provenance                    |
| **Technology**                | Inventions, manufacturing, prerequisites, adoption and technological development         |
| **Architecture**              | Building types, construction materials, styles, infrastructure and regional development  |
| **Settlements**               | Population, districts, government, services, trade, facilities and historical changes    |
| **Military**                  | Armies, units, ranks, equipment, fortifications, logistics and campaigns                 |
| **Diplomacy**                 | Treaties, negotiations, alliances, political marriages, sanctions and conflicts          |
| **Cosmology**                 | Planets, dimensions, stars, celestial bodies, creation rules and astronomical phenomena  |
| **Calendars & Timekeeping**   | Custom calendars, festivals, eras, time units and astronomical cycles                    |
| **Transportation**            | Roads, shipping, transport networks, vehicle types and travel constraints                |
| **Medicine & Biology**        | Diseases, treatments, anatomy, biological differences and medical knowledge              |
| **Materials & Crafting**      | Material properties, recipes, production requirements and resource availability          |
| **Legal Systems**             | Laws, jurisdictions, courts, legal status and enforcement                                |
| **Education & Knowledge**     | Schools, academies, curricula, libraries, research and institutional knowledge           |
| **Documents & Sources**       | Letters, manuscripts, books, testimony, artifacts, myths and historical records          |
| **Historical Archives**       | Primary sources, competing accounts, document provenance and source reliability          |
| **Narrative & Stories**       | Plots, scenes, chapters, character arcs and narrative continuity                         |
| **Quests & Campaigns**        | Adventures, branching objectives, encounters, rewards and RPG-style sessions             |
| **Inventory & Resources**     | Asset ownership, stockpiles, supply chains and resource transfers                        |
| **Diplomatic / Family Trees** | Dynastic relationships, alliances, inheritance claims and succession disputes            |
| **Mythology**                 | Legends, myth variants, narrative traditions and disputed origins                        |
| **Music & Art**               | Artistic traditions, instruments, styles, compositions and cultural development          |
| **World Documents**           | In-universe encyclopedias, legal codes, newspapers, journals and chronicles              |

Each module should provide its own data schema, editor, specialized visualizations, validation rules and AI operations where useful.

For example, the genealogy module should not be a generic list of family relationships. It should have a navigable family-tree editor, inheritance calculations, chronological validation and a connection to the political succession system.

### **Make modules extensible**

293. **Module marketplace or gallery.** Allow users to enable predefined modules.
294. **Custom module builder.** Create a new category and choose its fields, behaviors, views and relationships.
295. **Module dependencies.** A dynasty module can use data from characters, governments and timelines.
296. **Module-specific dashboards.** Provide views designed for the module's purpose.
297. **Module-level AI tools.** An economic module could expose trade-analysis operations; a language module could expose translation and language-generation operations.
298. **Module export and sharing.** Let users publish templates or modules for other creators.
299. **Custom visualizations.** Allow module authors to define graph, table, tree and map representations.
300. **Entity schema migration.** Preserve existing data when a module's schema changes.

## **14. Add a dedicated language and culture creation engine**

This deserves more than ordinary entity fields, especially for complex fictional worlds.

301. **Constructed-language generator.** Generate language structures using configurable phonotactics and grammatical constraints.
302. **Phoneme and script editors.** Define sounds, orthography, characters and writing systems.
303. **Vocabulary database.** Store words, meanings, forms, examples and their historical changes.
304. **Etymology trees.** Track how words originate, diverge and change across languages.
305. **Language-family graphs.** Model common ancestors and linguistic relationships.
306. **Sound-change rules.** Apply defined phonological changes over fictional centuries.
307. **Translation assistance.** Translate within established language rules while flagging missing vocabulary.
308. **Naming generators.** Generate names for characters, regions, cities and artifacts based on local linguistic patterns.
309. **Cultural practice systems.** Define rites, taboos, customs, ceremonies and their distribution among populations.
310. **Cultural evolution.** Explore how migration, trade, conquest and religion alter practices over time.
311. **Regional naming consistency.** Detect place names that contradict an established naming convention, while allowing exceptions.
312. **Cultural perspective.** Track how different societies interpret the same event or myth.

## **15. Narrative Studio: connect worldbuilding to actual stories**

Worldbuilding becomes much more useful when creators can develop narratives that draw from the world's established state.

313. **Story projects.** A single universe can contain multiple books, campaigns, scripts or independent storylines.
314. **Chapter and scene editor.** Provide long-form writing tools with a hierarchical outline.
315. **Plot boards.** Organize scenes by act, chapter, point of view, timeline and location.
316. **Character arc tracking.** Define goals, turning points, development and unresolved conflicts.
317. **Scene-level lore validation.** Check whether referenced locations, technologies, relationships and abilities are available at that point.
318. **Point-of-view consistency.** Warn when a narrator knows information unavailable to them.
319. **Story timeline versus canonical timeline.** Track flashbacks, parallel scenes and nonchronological disclosure.
320. **Foreshadowing tracking.** Link early clues to intended later developments.
321. **Unresolved thread management.** Track mysteries, character promises, objectives and planted information.
322. **Scene dependency graphs.** Identify the scenes that establish information needed by later scenes.
323. **Draft comparison.** Compare alternative scene or chapter versions.
324. **AI-assisted continuity editing.** Review specific scenes against established world facts.
325. **In-character conversations.** Simulate dialogue using a character's established knowledge, goals and personality.
326. **Character voice profiles.** Track vocabulary, speech patterns, preferences and register.
327. **Spoiler controls.** Restrict the AI's context to information revealed by a chosen chapter.
328. **Story-to-world extraction.** Propose new world facts discovered in a written scene.
329. **Interactive fiction support.** Create branching reader decisions and track possible narrative states.
330. **Campaign session support.** Record tabletop sessions and propose resulting world changes for review.
331. **Narrative visualization.** Show story locations, cast overlap and point-of-view sequences.
332. **Reader-facing exports.** Produce manuscripts, world guides or filtered companion encyclopedias.

## **16. More advanced AI systems**

The next level of Synthesis should come from the assistant understanding the structure of the world, not merely receiving increasingly large amounts of text.

### **Intelligent world operations**

333. **Hybrid retrieval.** Combine semantic search, exact entity matching, relationship traversal and temporal filtering.
334. **World-specific memory.** Maintain separate context for each universe, including long-running creative objectives.
335. **Structured tool calling.** AI operations should use validated application commands, not direct uncontrolled database modifications.
336. **Automatic relationship suggestions.** Detect potential connections from descriptions and propose them for review.
337. **Implicit fact extraction.** Identify factual statements embedded in documents and present them as proposed structured facts.
338. **Missing-information detection.** Discover unresolved properties that prevent a requested operation.
339. **Dependency-based context selection.** Retrieve only the relevant connected information for a given question.
340. **World-consistency reasoning.** Compare proposed changes with rules, history, geography and known character states.
341. **Causal consequence generation.** Generate possible second-order effects and explicitly identify the assumptions behind them.
342. **Alternative interpretation generation.** Offer multiple explanations for unresolved in-world mysteries.
343. **Adaptive creative guidance.** Learn from explicitly accepted and rejected proposals within a particular world.
344. **AI-generated test cases.** Create hypothetical situations to test whether world rules produce the intended behavior.
345. **Model routing.** Use different AI models for writing, structured extraction, classification, planning and intensive reasoning.
346. **Provider-agnostic AI.** Allow compatible local and hosted models when feasible.
347. **Transparent context inspection.** Show what lore the assistant read before generating an answer.
348. **Generation reproducibility.** Record the model, prompt configuration, relevant context and output for important operations.
349. **Automated world summaries.** Generate summaries of entities, civilizations, historical periods and changes using traceable references.
350. **Specialized collaborative agents.** Optional agents for cartography, chronology, economy, narrative and consistency, each with restricted responsibilities.
351. **Creative goal tracking.** Maintain explicit project goals such as "complete the history of the Eastern Crossing."
352. **Incremental world indexing.** Update search and context representations only for modified information.

One feature I would especially want is a **World Debugger**. The user could ask why a particular event was considered possible, then inspect the exact rules, relationships, historical conditions and assumptions used.

## **17. Multiplayer, collaboration and publishing**

353. **Real-time multiplayer editing.** Allow several creators to edit the same universe.
354. **Presence indicators.** Show which documents, maps or canvas frames collaborators are viewing.
355. **Role-based permissions.** Owner, editor, contributor, commenter and viewer roles.
356. **Canon approval permissions.** Only authorized collaborators can approve specific classes of changes.
357. **Proposed edits from collaborators.** Contributors can submit changes for review.
358. **Comments and discussion threads.** Discuss particular facts, regions, events or design decisions.
359. **Collaborative Canvas.** Multiple cursors, selections and simultaneous spatial editing.
360. **Shared creative sessions.** Work with other users in a common AI-assisted discussion.
361. **Private documents and spoilers.** Restrict access to hidden lore, plot information and selected branches.
362. **Public world encyclopedia.** Publish a browsable, read-only version of selected canonical lore.
363. **Interactive world websites.** Publish Atlas, Timeline and entity profiles together.
364. **Shareable individual views.** Create links to a specific character, map region or historical state.
365. **Community templates.** Share world structures, entity schemas, Canvas templates and custom modules.
366. **World cloning and remixing.** Duplicate an authorized public template into a new independent universe.
367. **Import tools.** Support Markdown, JSON, CSV, existing writing documents and selected third-party worldbuilding formats.
368. **Open export formats.** Export structured data, references, assets and chronology without proprietary lock-in.
369. **Developer API.** Permit external tools to read and manipulate worlds subject to user-defined permissions.
370. **Plugin SDK.** Allow community-built modules, simulations and visualizations.
371. **External writing-tool integrations.** Synchronize selected documents with supported editors where APIs permit.
372. **Optional local collaboration server.** Let users choose whether collaborative world data is hosted by Synthesis or self-managed.

## **18. Settings, performance and reliability**

Your current Settings view has a foundation of sections, but it needs more control over how the application actually behaves.

373. **Per-world configuration.** Set calendars, units, default entity types, conventions, canon rules and AI permissions separately for each world.
374. **Global versus local preferences.** Clearly distinguish application-wide settings from world-specific ones.
375. **Detailed AI configuration.** Providers, models, API credentials, context limits, data-sharing policies and cost controls.
376. **Configurable automation permissions.** Specify which operations require confirmation and which can run without editing canon.
377. **Custom keyboard shortcuts.** Allow users to rebind actions and export shortcut profiles.
378. **Editor preferences.** Control autosave, spell-checking, typography, formatting and default views.
379. **Graph performance settings.** Configure layout, rendering density, node clustering and label behavior.
380. **Map performance settings.** Control texture quality, resolution, caching and layer rendering.
381. **Offline-first operation.** Let users browse and edit local world data without internet access.
382. **Reliable synchronization.** Use explicit conflict handling for offline edits and multiple devices.
383. **Local backups and snapshots.** Provide scheduled backups, manual backups and recovery.
384. **Restore preview.** Inspect a backup before replacing or merging world data.
385. **Storage management.** Display database, image, attachment and generated-asset usage.
386. **Index management.** Explain when search indexes are stale and allow safe rebuilding.
387. **Background operation history.** Track completed, failed and canceled generation or indexing jobs.
388. **Accessible interactions.** Keyboard navigation, screen-reader labels, focus outlines and color-independent status markers.
389. **Reduced-motion support.** Respect accessibility preferences across transitions and map animations.
390. **Responsive application layouts.** Handle smaller desktop windows without overlapping toolbars or clipped controls.
391. **Application diagnostics.** Provide readable error details and recovery options for failed operations.
392. **Data ownership controls.** Make local and remote storage choices explicit.
393. **Sensitive-world permissions.** Prevent selected worlds or documents from being sent to external AI providers.
394. **Versioned settings and schemas.** Ensure application updates do not silently damage existing worlds.

## **19. Features that could make Synthesis genuinely distinctive**

These are the larger concepts I would put into a separate experimental backlog. They are more ambitious than the individual improvements above.

[AI Fantasy World Generator: Maps, Worlds & Names | AIAI.com](https://images.openai.com/static-rsc-4/fcWVV2SAkr28QuZiX719v0hLDyFfHGbpA1ZypHjyWiy8sZFBEkP4mm7NPih_XHpSuu-AGbJxH1bsiSVXGLiAmCH32wSyq4mh2HrJgdfzx8q6G--sZSru5WScQnqecotjx4VZMLPNoKxAuLfYHGIiF0u6vVwkm6smvTNhILSrYic?purpose=inline)

**1. Living World**

A mode where the world advances through time according to configured rules. Users can intervene, pause, rewind, inspect consequences and promote chosen events to canon.

[🌐💰 Networks, Crowds, and Markets: Reasoning About a Highly Connected World](https://images.openai.com/static-rsc-4/E-3ecRV7SdKmmHzqH2MVs2iHfsO2pzM7yVOOzflV0xO_H4O7CyudNBIZ7M30SWJ5n3bGR-ZQsezl66W9vWTZevCvgiiWsX1m5KEg3uGVrumd8I3V4UZYd2RSGEHpTGJZFuUvTCCqoOt8HSy8pSIz6Lgs8RpZJRkS2Jlvc2tCaK4?purpose=inline)

**2. World Debugger**

A system that traces a fictional fact to its original source and its dependencies. It can answer questions such as "Why does this character possess this ability?" and show the rules supporting the answer.

[Create city, event, tourist, and fantasy map illustration by Lacuar | Fiverr](https://images.openai.com/static-rsc-4/rYFDxKsXuC4FHtacnVjZSGrFA8Db5q_bR8tRca22PX4140c2HJmpArswoorcKHlax_mBOkdNzp8CIcIrYLJOLfTM_ykM_FroShq3m-QmOijK3qXcIJ928alJ4MHmnpVqHu606wi9b0Ge5wm01sgSYmtUKQctbfaamE2lSx5CG48?purpose=inline)

**3. World Explorer**

An interactive exploration interface for locations and historical periods. Navigate a setting, inspect places and characters, and follow guided journeys through canonical material.

[«Legend: Legacy of the Dragons» :: Infoportal](https://images.openai.com/static-rsc-4/nEclnjh6gGv0tJlbiGWrlotntvCIqpEH4Wbxe8PK0rZtGiS-CI18wl8G0q3yrPtdHL-LUaBM-_a_-uaiaNut3tTddhS6z8ejrmbfW61-jc2PkgSY1AGVRthu9Pi_NEgcJZ-epux817WXr69FccNvfuci7DD1n72mlxnIQaagymY?purpose=inline)

**4. Parallel Worlds**

A branch manager where alternate histories can evolve independently, run their own simulations and merge selected outcomes back into the original world.

[Medium](https://images.openai.com/static-rsc-4/A18UA6WGG3mPToTTzHMYxtRy2IhsVEB4lRpFIprwlUDsI3WpvRK4cQy2fRaiY4fBLNdKG82ZFy7xJPvECeGR3Fl-4N-6jGCoJbPcnOqCCNko5XPUuJ0CaSc6rDYe0VrmLpQ_s5Iy4m49Xw24965eNRVz0_Ie60fhsZQLoRLtnAI?purpose=inline)

**5. Rule Laboratory**

A visual programming environment for fictional mechanics, allowing users to define laws, build progression systems, run experiments and test interactions before approving them.

Other ambitious ideas worth exploring include:

- **Historical replay:** Watch the world change across centuries with synchronized atlas, graph and narrative events.
- **Civilization sandbox:** Create a continent, define its ecology and resources, then simulate societies developing under explicit assumptions.
- **Character mind model:** Maintain a character's personal memories, beliefs, intentions, secrets and misconceptions separately from objective canon.
- **Dynamic geopolitical simulator:** Run constrained, inspectable scenarios of alliances, trade, territorial disputes and institutional decisions.
- **Lore compiler:** Validate the world's rules and references before creating a release or publishing a world encyclopedia.
- **In-universe document generator:** Generate newspapers, legal texts, historical manuscripts and letters from a specific person's or institution's perspective.
- **Knowledge archaeology:** Explore how a myth or historical belief changes across generations and cultures.
- **Multiverse comparator:** Identify exactly which characters, events and relationships differ between two branches.
- **World dependency explorer:** Select a single fact and inspect what could change if it were removed.
- **Creator-defined simulation scripts:** Allow advanced users to add their own simulation rules and custom analysis modules.

## **20. The technical architecture I'd use**

To make all these features work together, Synthesis needs a shared model of world state.

Without that foundation, Atlas, Graph, Timeline and Conversation risk becoming separate tools that repeatedly copy information between themselves.

**Synthesis interface**

Conversation · Canvas · Atlas · Graph · Timeline · Editors

**Validated command and proposal layer**

Typed operations · Permissions · Approval · Change sets

**Canonical world-state engine**

Entities · Facts · Relationships · Time · Rules · Provenance

Simulation

Agents · Systems · Scenarios

World intelligence

Retrieval · Reasoning · Checks

Version control

Branches · Diffs · History

Persistence

Storage · Indexes · Sync

The most important implementation rules:

1. **Canonical data must have stable identifiers.** Never use an entity's visible name as its permanent identity.
2. **Relationships should be first-class records.** They need their own properties, temporal validity, provenance and history.
3. **Facts need explicit status.** Canonical, draft, disputed, hypothetical and intentionally false in-universe claims cannot be treated interchangeably.
4. **Separate actual world facts from character beliefs.** Mira believing that the Glass Sea is cursed should not automatically establish that it is cursed.
5. **Use validated, typed commands for all mutations.** The AI should propose operations that pass application-level validation.
6. **Store reversible operations and checkpoints.** Reliable undo, branching and synchronization require more than overwriting documents.
7. **Support temporal state.** Distinguish when a fact was true from when it was recorded or discovered.
8. **Make derived views incremental.** Editing one relationship should update relevant Graph and Canvas views without unnecessarily rebuilding the entire world.
9. **Give simulation its own state.** Simulation outcomes remain separate from canonical facts until explicitly committed.
10. **Keep simulation results reproducible.** Save inputs, parameters, assumptions, seeds and software versions when relevant.
11. **Treat AI-generated explanations as interpretations.** Do not confuse a convincing explanation with a verified output of the rule engine.
12. **Preserve user ownership.** The world should remain exportable and accessible even without an external AI provider.

For the data layer, I'd evaluate a local structured database, a full-text index, a semantic retrieval index, and explicit graph queries over the same canonical records. A dedicated graph database isn't necessarily required at your present scale.

For simulation, a rule-driven state-transition engine should be the core. Language models can propose inputs, run permitted tools and interpret outputs, but deterministic code should handle calculations and enforced constraints.

## **21. What I would prioritize first**

I would avoid attempting all 394 improvements simultaneously. Some depend on the same underlying systems, and building the visible interface before the data model could force expensive rewrites.

Here's the order I'd use.

## **01**

**Foundation: make the world internally coherent**

Highest priority

Typed world entities, atomic facts, temporal relationships, provenance, custom schemas, validated mutations and unified world state.

This is the foundation for nearly every advanced feature.

## **02**

**Conversation as a world-editing agent**

Let natural language produce meaningful, multi-step structured changes, including dependencies and approval previews.

## **03**

**Full interface redesign**

Upgrade navigation, window management, inspectors, command palette, AI composer, entity editor, spacing, visual states and workspace layouts.

## **04**

**Unified temporal world model**

Make dates, events, historical relationships and world-state snapshots available everywhere, especially Atlas, Graph and Conversation.

## **05**

**Graph and Canvas expansion**

Turn Graph into a queryable knowledge network and Canvas into an interactive spatial workspace with live embedded objects.

## **06**

**Advanced Atlas and Timeline**

Introduce geographical layers, linked historical states, scale, spatial calculations, chronological dependencies and playback.

## **07**

**Rule and simulation engines**

Start with a small, testable simulation of characters, factions and resources. Expand into geopolitical, economic and environmental systems.

## **08**

**Parallel worlds, collaboration and publishing**

Build advanced branching, world comparison, controlled collaborative editing, extensibility and public presentation.

## **22. The first ten concrete changes I'd ship**

If I wanted the next version of Synthesis to feel substantially more capable immediately, these would be my first visible changes.

| Priority | Update                                                                          | Difficulty |
| -------- | ------------------------------------------------------------------------------- | ---------- |
| 1        | Universal command palette and cross-world search                                | Medium     |
| 2        | Redesigned entity editor with structured fields, rich blocks and embedded views | High       |
| 3        | Advanced AI composer with entity attachments and structured change operations   | High       |
| 4        | Contextual right-side inspector across every workspace                          | Medium     |
| 5        | Visual before/after diffs for AI proposals                                      | Medium     |
| 6        | Improved Graph layouts, filtering and relationship inspection                   | Medium     |
| 7        | Truly visual timeline with parallel tracks and uncertain dates                  | High       |
| 8        | Canvas live components, nested frames and bi-directional synchronization        | High       |
| 9        | Atlas layers, geographic linking and historical states                          | High       |
| 10       | World-state debugger with source tracing and consistency checks                 | Very high  |

Difficulty estimates are relative, assuming the capabilities shown in the screenshots. Actual effort depends on the existing architecture.

## **23. What I would avoid**

A few things could make Synthesis more complicated without making it more useful.

- **Don't add hundreds of shallow AI buttons.** Prefer a smaller set of powerful operations that can work across the whole world.
- **Don't automatically establish AI-generated lore.** Preserve the approval model you've already started.
- **Don't add every new feature to the sidebar.** Use modules, context menus, command search and customizable navigation.
- **Don't make every task depend on AI.** Manual writing, mapping, editing and world exploration should remain fully capable.
- **Don't create simulations that invent results and display them as calculated facts.** Make assumptions and uncertainty inspectable.
- **Don't prioritize 3D worlds before perfecting 2D Atlas and the geographic data model.** It would be costly and could distract from core functionality.
- **Don't turn worldbuilding into a completion-score game.** Missing lore isn't necessarily a defect, and mysteries may be intentional.
- **Don't let visual polish mask inconsistent data.** An impressive Graph is useless if its relationships are stale or incorrect.

## **24. A product-defining workflow**

Imagine selecting Mira Vale and pressing a new action: **Explore consequences**.

The assistant discovers that Mira is connected to the Tidekeepers, the Glass Sea, the art of remembrance and several historical events.

You then ask:

> What would happen if Mira discovered a way to permanently erase the cost of borrowed memories?

Synthesis should first identify the relevant rules and determine whether the possibility contradicts any immutable constraints.

It could then propose several interpretations: Mira has discovered an exception, has misunderstood the underlying mechanics, or has altered the underlying power system itself.

Once you choose a hypothesis, Synthesis creates a sandbox branch and investigates its consequences using the world's recorded relationships and configured rules.

The Graph previews how Mira's relationships may change. The technique tree shows which abilities become available. The Timeline displays candidate events that could follow the discovery. If the change affects settlements, travel or territorial control, Atlas displays the corresponding hypothetical states.

The conversation remains available throughout the process for questions and refinements.

Finally, you open a single Review screen and select which changes to accept into the branch, which to reject and which to retain as unresolved possibilities. You can merge chosen changes into canon later.

At every stage, the interface should distinguish existing facts, assumptions, generated possibilities and calculated results.

**That's the standard I would design Synthesis around:** every major tool is a different way to create, inspect, test or revise one coherent fictional world.