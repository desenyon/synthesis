# Split workspace

Open a character, place or document while keeping Atlas, Timeline, Graph, Canvas or another record visible. Use **View → Open Document Beside Workspace**, the split button in the workspace bar, or **Open beside workspace** in a Library, Favorites or document-tab context menu. The chooser searches only the current universe.

The second pane uses the same native editor: Overview, Sections, Mechanics, formatting, revisions and explicit canon review. Its header can choose another record, move it to the main pane (swapping when two documents are open), show details or close the pane. ⌘W and the inspector shortcut target the focused document. Opening one record in the other pane moves it; there are never two competing editors for the same source.

At desktop widths, drag the divider to resize the second pane between 380 and 720pt. Shorter/narrower windows stack the workspaces, with independent scrolling. A single compact assistant composer sits below the split; current context includes both documents and the active spatial workspace, subject to the existing context exclusions. Manual mode retains both panes without a composer or provider calls.

Both editors retain their native caret and separate undo histories. Navigation, closing, world changes and swapping flush both drafts first; a failed save keeps the current writing open. Archived or foreign-world records cannot be restored into a pane. Closing a pane does not archive its source.

The second record address is stored per universe; its preferred width is a device-wide setting. Back/Forward and per-world saved workspace layouts include the split. These preferences contain no copies of lore and are not exported as world content. Full application session restoration is tracked separately at expansion #33.

Verification: [expansion #26](verification/expansion-026/README.md). Native captures verify layout; they do not establish physical gesture feel or VoiceOver behavior.
