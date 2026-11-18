# Drag references between workspaces

Drag a lore result from Search (⌘K), a record in sidebar Favorites, or an unarchived Library row. The search overlay steps aside during the gesture and returns if you cancel.

- **Open here** opens the source in the main editor. **Open beside** creates a second pane; dropping onto an existing secondary pane replaces its displayed record. Pending edits must save first.
- **Place linked record** on Canvas positions a record card at the pointer, using the board's current zoom and pan. Dropping a record already on that board moves its existing card and artwork together. It does not make a second copy. Canvas Undo reverses the placement or move.
- The card remains a reference to the Library record. Its description and stored relationships update through the existing shared model. Dropping never edits source lore or promotes canon.
- These actions work in Manual mode. No model request is involved.

Drag targets appear only during an internal record drag. In narrow windows, the new-pane target sits along the bottom and the resulting panes stack. The compact composer temporarily hides without changing the pane layout.

The local drag payload contains only version, universe ID and record ID. It is available only inside the current app process. The receiver resolves the latest source, rejects archived or foreign-world records, and rejects delivery after the destination changes. A Canvas placement is confirmed only after the engine acknowledges its save; an unavailable or failed board does not report success.

Keyboard alternatives remain available: Search → Return opens a record; “Open document beside workspace” in Search and the existing context menu open a second pane; “Show on canvas” places and reveals a record without dragging.

## Events, proposals, boards and images

Drag an event from Timeline, artwork from an entity, or a proposal from Review. Atlas exposes separate map and image drag handles. Canvas exposes its board handle and an image handle when exactly one image is selected. All carry local addresses that resolve against the current world.

- Drop into the writing area of either pane to insert a linked label at the caret or selected text. It uses the editor's normal save and Undo path. Open the link to revisit its source.
- Drop onto empty Canvas space to place a reference card. Moving the same source again reuses its card. The board keeps the position and address, and opening a Canvas image reference reveals the actual image.
- Drop on the composer to add an inline source to the current draft. Review the context before sending. A lore chip and either form of inline record link count as one source. Each distinct event, image or other typed reference counts separately. An image reference supplies text metadata to the assistant.

`.synthesis` copies remap typed links in Canvas, current rich text, accepted snapshots and native revision history. Reference labels stay in the local draft and transcript. App-generated labels for excluded references are filtered from the provider request.

The original record-drop behavior has [#27 capture evidence](verification/expansion-027/README.md). #35 has Linux core and Canvas checks. The native capture, editor Undo and physical drop precedence checks are pending macOS verification.
