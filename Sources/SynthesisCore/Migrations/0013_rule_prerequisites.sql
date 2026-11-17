-- A technique or progression step that requires another rule of the same system first.
-- Removing an edge archives it, so the tree's earlier shape stays auditable.
CREATE TABLE rule_prerequisites (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  rule_id TEXT NOT NULL REFERENCES rules(id),
  requires_id TEXT NOT NULL REFERENCES rules(id),
  archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(rule_id, requires_id),
  CHECK(rule_id != requires_id)
);
CREATE INDEX rule_prerequisites_world ON rule_prerequisites(world_id, archived);
