# Creative components

A component is a native presentation of a normal lore record. It can be created manually or proposed by the assistant; accepting a proposal creates a draft, never canon. No model-supplied code, HTML, network resource or executable UI is evaluated.

Open **Creative components** in a workspace toolbar. Add Notes, Facts, Checklist or Progression; give it any title and content. Entity components also appear on the entity's Sections page. Open a component to edit the full document; it keeps normal revision history, search, references and canon review. Component actions reference it in chat, place it on Canvas or remove its presentation with Undo. Removing a component preserves its underlying lore.

- Notes display free prose.
- Facts display `Label: value` lines; other lines stay visible.
- Checklists use Markdown `- [ ]` and `- [x]`. Clicking changes one marker through a version-checked draft save. Accepted canon is retained. Rich-text documents must be edited in the editor, preserving formatting.
- Progression displays ordered stages, one per line. It does not simulate advancement or enforce world mechanics.

Workspace scopes: Conversation, Canvas, Library, Graph, Timeline, Atlas and Review. Entity scopes cover any custom entity category, including Characters, Systems, Places, Power systems and Cosmology. Workspace components belong to the selected world's workspace, not to an individual board or conversation.

The assistant receives component IDs, record IDs, scope, kind and entity membership in its bounded world index. It can propose `create_component`, revise the content with `revise_record`, and place the resulting record using the existing `place_record` action. The Review UI names the presentation and destination and exposes the proposed text before approval. Unknown kinds/scopes and cross-world parents are rejected.

Migration `0009` stores presentation metadata. `.synthesis` v5 preserves it; v1–v4 imports remain supported. JSON export is schema 8. Markdown exports the ordinary underlying content, including entity section relationships.

This is the first constrained component vocabulary. It is not arbitrary generative UI, a dedicated map engine, a simulation system, or a replacement for the specialized workspaces. Those remain separate milestones.
