CREATE TABLE structured_facts (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  subject_id TEXT NOT NULL,
  predicate TEXT NOT NULL,
  working_revision INTEGER NOT NULL CHECK(typeof(working_revision)='integer' AND working_revision>0),
  accepted_revision INTEGER CHECK(accepted_revision IS NULL OR (
    typeof(accepted_revision)='integer' AND accepted_revision BETWEEN 1 AND working_revision
  )),
  version INTEGER NOT NULL CHECK(typeof(version)='integer' AND version>=working_revision),
  archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(id,world_id),
  FOREIGN KEY(subject_id,world_id) REFERENCES records(id,world_id),
  FOREIGN KEY(id,world_id,working_revision) REFERENCES structured_fact_revisions(fact_id,world_id,revision)
    DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY(id,world_id,accepted_revision) REFERENCES structured_fact_revisions(fact_id,world_id,revision)
    DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX structured_fact_subject ON structured_facts(world_id,subject_id,archived,predicate);

CREATE TABLE structured_fact_revisions (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  fact_id TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>0),
  status TEXT NOT NULL CHECK(status IN ('draft','disputed','canon')),
  author TEXT NOT NULL,
  origin TEXT NOT NULL CHECK(origin IN ('user-authored','imported','ai-proposed','inferred')),
  recorded_at TEXT NOT NULL,
  text_value TEXT,
  entity_value_id TEXT,
  evidence_record_id TEXT,
  evidence_version INTEGER,
  CHECK((text_value IS NULL) <> (entity_value_id IS NULL)),
  CHECK((evidence_record_id IS NULL AND evidence_version IS NULL) OR
    (evidence_record_id IS NOT NULL AND typeof(evidence_version)='integer' AND evidence_version>0)),
  UNIQUE(fact_id,world_id,revision),
  FOREIGN KEY(fact_id,world_id) REFERENCES structured_facts(id,world_id),
  FOREIGN KEY(entity_value_id,world_id) REFERENCES records(id,world_id),
  FOREIGN KEY(evidence_record_id,world_id) REFERENCES records(id,world_id),
  FOREIGN KEY(evidence_record_id,evidence_version) REFERENCES native_revisions(record_id,version)
);

CREATE TRIGGER activity_structured_facts_insert AFTER INSERT ON structured_facts
WHEN NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
  VALUES(
    synthesis_uuid(),NEW.world_id,NEW.subject_id,'record','created',
    (SELECT title FROM records WHERE id=NEW.subject_id AND world_id=NEW.world_id),
    'Fact added · ' || NEW.predicate,strftime('%Y-%m-%dT%H:%M:%SZ','now')
  );
END;

CREATE TRIGGER activity_structured_facts_update AFTER UPDATE ON structured_facts
WHEN (OLD.archived IS NOT NEW.archived OR OLD.working_revision IS NOT NEW.working_revision
  OR OLD.accepted_revision IS NOT NEW.accepted_revision)
  AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
  VALUES(
    synthesis_uuid(),NEW.world_id,NEW.subject_id,'record',
    CASE
      WHEN OLD.archived IS NOT NEW.archived THEN CASE NEW.archived WHEN 1 THEN 'archived' ELSE 'restored' END
      WHEN OLD.accepted_revision IS NOT NEW.accepted_revision THEN 'approved'
      ELSE 'updated'
    END,
    (SELECT title FROM records WHERE id=NEW.subject_id AND world_id=NEW.world_id),
    CASE
      WHEN OLD.archived IS NOT NEW.archived THEN CASE NEW.archived WHEN 1 THEN 'Fact archived' ELSE 'Fact restored' END
      WHEN OLD.accepted_revision IS NOT NEW.accepted_revision THEN 'Fact approved'
      ELSE 'Fact revised'
    END || ' · ' || NEW.predicate,
    strftime('%Y-%m-%dT%H:%M:%SZ','now')
  );
END;
