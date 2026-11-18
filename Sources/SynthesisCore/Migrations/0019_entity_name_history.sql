CREATE TABLE entity_name_periods (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  record_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('name','alias')),
  name TEXT NOT NULL,
  start_label TEXT NOT NULL DEFAULT '',
  end_label TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision)='integer' AND revision>0),
  archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(id,world_id),
  FOREIGN KEY(record_id,world_id) REFERENCES records(id,world_id)
);

CREATE INDEX entity_name_periods_owner ON entity_name_periods(world_id,record_id,archived);

CREATE TABLE entity_name_period_history (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  period_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('name','alias')),
  name TEXT NOT NULL,
  start_label TEXT NOT NULL,
  end_label TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>0),
  archived INTEGER NOT NULL CHECK(archived IN (0,1)),
  updated_at TEXT NOT NULL,
  UNIQUE(period_id,revision),
  FOREIGN KEY(period_id,world_id) REFERENCES entity_name_periods(id,world_id)
);

-- Historical names participate only in local Library search. Assistant retrieval still
-- uses the separately scoped record and property indexes.
CREATE VIRTUAL TABLE entity_name_search USING fts5(
  name, period_id UNINDEXED, record_id UNINDEXED, world_id UNINDEXED, tokenize='unicode61'
);

CREATE TRIGGER entity_name_search_insert AFTER INSERT ON entity_name_periods
WHEN NEW.archived=0
BEGIN
  INSERT INTO entity_name_search(name,period_id,record_id,world_id)
  VALUES(NEW.name,NEW.id,NEW.record_id,NEW.world_id);
END;

CREATE TRIGGER entity_name_search_update AFTER UPDATE OF name,archived ON entity_name_periods
WHEN OLD.name IS NOT NEW.name OR OLD.archived IS NOT NEW.archived
BEGIN
  DELETE FROM entity_name_search WHERE period_id=OLD.id;
  INSERT INTO entity_name_search(name,period_id,record_id,world_id)
  SELECT NEW.name,NEW.id,NEW.record_id,NEW.world_id WHERE NEW.archived=0;
END;
