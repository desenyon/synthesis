CREATE TABLE relationship_history (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 relationship_id TEXT NOT NULL,
 source_id TEXT NOT NULL,
 target_id TEXT NOT NULL,
 label TEXT NOT NULL,
 action TEXT NOT NULL,
 created_at TEXT NOT NULL
);
ALTER TABLE relationships ADD COLUMN archived INTEGER NOT NULL DEFAULT 0;
