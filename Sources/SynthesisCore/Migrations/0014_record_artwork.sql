CREATE TABLE record_artwork (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  record_id TEXT NOT NULL REFERENCES records(id),
  image TEXT NOT NULL,
  mime_type TEXT NOT NULL CHECK (mime_type IN ('image/png', 'image/jpeg')),
  origin TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX active_record_artwork ON record_artwork(record_id) WHERE archived=0;
CREATE INDEX artwork_by_world ON record_artwork(world_id, archived);
