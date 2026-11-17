CREATE TABLE rule_history (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 rule_id TEXT NOT NULL REFERENCES rules(id),
 snapshot TEXT NOT NULL,
 created_at TEXT NOT NULL
);
CREATE INDEX rule_history_record ON rule_history(world_id,rule_id,created_at);
