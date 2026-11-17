# Create and navigate from the keyboard

The native File and View menus show the same shortcuts used by the command palette. Creation remains available in Manual mode.

| Shortcut | Action |
| --- | --- |
| ⌘N | New record: document, entity or idea |
| ⌥⌘N | New entity, with the name field ready for typing |
| ⇧⌘K | Link records in the active universe |
| ⇧⌘N | New conversation |
| ⌘K | Search and commands |
| ⌥⌘I | Toggle the focused document's inspector, or the workspace inspector |
| ⇧⌘M | Toggle AI Assisted / Manual; switching to Manual stops generation |
| ⌘[ / ⌘] | Back / Forward through documents, maps and tool subpages |

New Entity uses the regular creation form. Type a name, choose a category or enter your own, and press Return to create a draft. Escape cancels. An existing form is not replaced by another creation shortcut. Pending document saves must succeed before creating anything.

Link Records preselects the focused document or current Graph/Atlas selection. Choose **Reference** for a source link/backlink between any records, or **Relationship** for a typed connection between two entities. The latter supports an independently named reverse direction; both directions save atomically as drafts. Names are limited to 80 characters per relationship label. Graph's connection tools use this same form.

The record picker searches names, aliases and categories without a fixed record cutoff. Its search field takes focus; Up/Down moves the highlighted result and Return chooses it. Tab moves through the form, Return submits a valid connection and Escape closes it. Saved relationships refresh the shared world model, so Graph, inspectors and source views use the same data. Referencing a record never changes its prose or accepted canon.

Submission checks the current universe and live endpoints again. Removed or foreign records cannot be linked. A failed save leaves the form available to correct or retry. Linking is unavailable when the world has fewer than two records. Full session restoration is tracked separately from these in-session commands.
