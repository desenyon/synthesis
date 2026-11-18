# Relationships

Create a relationship from **Link records** or Graph. Drawing a connector between entity cards in Canvas can also open the relationship form. Enter a label from the source toward the target. Use the same stored edge from either entity profile. An optional reverse label creates a second edge when the reverse connection carries its own meaning.

Choose a meaning such as Mentor, Political superior, Legal guardian, Former ally or Rival. Older labels have Unknown meaning until the creator classifies them. Expand **Dates, status and evidence** to enter fictional start and end labels, strength, secrecy, mutuality, status and supporting records. Leaving a value blank or Unknown preserves uncertainty. Secrecy describes who knows about the relationship inside the fictional world.

Open a Graph edge to edit its draft details or choose **Inspect relationship** to read them and open their sources. Canvas opens the same edit form. Saved edits check the original revision. Archive removes the connection from both endpoints and offers Undo. Canonical relationships are read-only in these editors.

Migration 0018 records attributes and optimistic revisions with each edge. Changes retain the previous revision and generate world activity. `.synthesis` v11 and JSON schema 14 include attributes and archived evidence. Import copies the world and remaps evidence addresses. Legacy archives default to Unknown values.

The Linux core tests cover both endpoints, migration, validation, history, activity and portability. The Graph and entity surfaces still need the quiet macOS screenshot review and native tests. [Run record](PROGRESS.md)
