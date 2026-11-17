# World activity

Open **Dashboard → World activity → View history**, choose **View → World Activity History…** in the native menu, or search for **World activity history** in ⌘K.

The history records committed edits, canon approvals, review decisions, new and changed relationships, chronology, maps, boards, entity sections, rules, artwork, conversations and world settings. Search titles and change descriptions; filter by source type or action. Load earlier changes without losing your current filters.

**Open source** resolves the current record, map, board, review, conversation or timeline object. It does not restore a historical revision or approve canon. Archived objects keep their history but cannot be opened until restored. Record revision restoration remains in the editor's Revision history action.

Activity uses local editing times. Fictional dates, eras and branches belong in Timeline. Failed transactions leave no activity entry. Manual mode has the same history without any model requests. Message bodies, streaming tokens, provider settings and device navigation preferences are not activity entries. Canvas viewport movement and serialization bookkeeping do not count as creative edits.

Existing installations reconstruct entries from saved record revisions, relationship history and rule snapshots. Other old objects receive a clearly labeled last-saved-state entry. The app cannot recover edits that were never retained; it does not invent them.

The log belongs to its universe. `.synthesis` format v9 and JSON schema 12 include it. Import remaps source identifiers, validates their world, preserves history and adds one import entry. Earlier v1–v8 files reconstruct available history. Export never includes authentication or device preferences. The dashboard and palette retain a compact latest-object summary; the history window is the complete retained edit log.
