# Open documents

Opening any document, entity, section or idea adds it to the current universe’s tab strip. Switch by clicking a tab or with Control-Tab / Control-Shift-Tab. The active document keeps its shared contextual assistant; Manual mode uses the same editor.

- Right-click a tab to pin/unpin it, close it, or close other unpinned documents. Pins stay first and have no incidental close button.
- Use the clock menu in the editor or Library for open and recently closed records. Shift-Command-T reopens the most recently closed available document; the command is also in quick-open and File.
- Command-W closes the active document; when no document is open it closes the window. The breadcrumb back to the workspace leaves tabs available. Closing never archives lore.
- Tab changes flush autosave first. A failed save keeps the current document and its text open. Native editor views retain their caret, scroll position, rich formatting and per-document Undo/Redo while switching tabs or returning from another workspace.
- A newly reviewed/external content revision replaces a clean cached editor and clears its obsolete text undo stack. It cannot replace unsaved typing.

Open IDs, pins and the last 50 recent IDs persist per world on this device. They do not enter lore exports or model context. Archived/foreign records are filtered out, and reopened records resolve current content. Damaged preference data is backed up locally before a new tab list can be written; it cannot prevent opening the world.

This is not full session restoration (#33): the selected workspace/tab and native undo stacks are not restored after quitting. Switching worlds reloads that world’s tab addresses with fresh native editor views.
