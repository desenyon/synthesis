-- Device-local recovery copy of editor text that has not reached a saved revision yet.
-- Never exported: it is a safety net, not lore. One row per record; cleared on save.
CREATE TABLE editor_journal (
  record_id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  rtf TEXT,
  category TEXT NOT NULL,
  base_version INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(record_id,world_id) REFERENCES records(id,world_id)
);
CREATE INDEX editor_journal_world ON editor_journal(world_id,updated_at);
