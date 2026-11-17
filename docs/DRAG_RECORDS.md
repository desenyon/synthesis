# Drag records between workspaces

Drag a lore result from Search (⌘K), a record in sidebar Favorites, or an unarchived Library row. The search overlay steps aside during the gesture and returns if you cancel.

- **Open here** opens the source in the main editor. **Open beside** creates a second pane; dropping onto an existing secondary pane replaces its displayed record. Pending edits must save first.
- **Place linked record** on Canvas positions a record card at the pointer, using the board's current zoom and pan. Dropping a record already on that board moves its existing card and artwork together. It does not make a second copy. Canvas Undo reverses the placement or move.
- The card remains a reference to the Library record. Its description and stored relationships update through the existing shared model. Dropping never edits source lore or promotes canon.
- These actions work in Manual mode. No model request is involved.

Drag targets appear only during an internal record drag. In narrow windows, the new-pane target sits along the bottom and the resulting panes stack. The compact composer temporarily hides without changing the pane layout.

The local drag payload contains only version, universe ID and record ID. It is available only inside the current app process. The receiver resolves the latest source, rejects archived or foreign-world records, and rejects delivery after the destination changes. A Canvas placement is confirmed only after the engine acknowledges its save; an unavailable or failed board does not report success.

Keyboard alternatives remain available: Search → Return opens a record; “Open document beside workspace” in Search and the existing context menu open a second pane; “Show on canvas” places and reveals a record without dragging.

Broader cross-workspace drops of events, images and proposals are expansion #35, not part of this record-address feature. Background checks and native captures are recorded in [expansion #27 evidence](verification/expansion-027/README.md); physical OS drag feel is a separate foreground interaction check.
