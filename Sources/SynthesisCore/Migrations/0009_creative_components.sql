-- Layout metadata only; all content remains revisioned, searchable lore.
CREATE TABLE creative_components (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 record_id TEXT NOT NULL UNIQUE,
 parent_id TEXT,
 scope TEXT NOT NULL CHECK(scope IN ('conversation','canvas','library','graph','timeline','atlas','review','entity')),
 kind TEXT NOT NULL CHECK(kind IN ('notes','facts','checklist','progression')),
 archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 CHECK((scope='entity' AND parent_id IS NOT NULL) OR (scope!='entity' AND parent_id IS NULL)),
 FOREIGN KEY(record_id,world_id) REFERENCES records(id,world_id),
 FOREIGN KEY(parent_id,world_id) REFERENCES records(id,world_id)
);
CREATE INDEX creative_components_scope ON creative_components(world_id,scope,parent_id,archived);
