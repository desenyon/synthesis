-- Presentation membership only. Section content remains a normal revisioned lore record.
CREATE TABLE record_sections (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  parent_id TEXT NOT NULL,
  record_id TEXT NOT NULL UNIQUE,
  position INTEGER NOT NULL CHECK(position >= 0),
  archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK(parent_id != record_id),
  FOREIGN KEY(parent_id,world_id) REFERENCES records(id,world_id),
  FOREIGN KEY(record_id,world_id) REFERENCES records(id,world_id)
);
CREATE INDEX record_sections_parent ON record_sections(world_id,parent_id,archived,position);
