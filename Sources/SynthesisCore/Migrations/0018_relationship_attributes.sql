ALTER TABLE relationships ADD COLUMN attributes TEXT NOT NULL DEFAULT '{}';
ALTER TABLE relationships ADD COLUMN revision INTEGER NOT NULL DEFAULT 1
  CHECK(typeof(revision)='integer' AND revision>0);
ALTER TABLE relationship_history ADD COLUMN attributes TEXT NOT NULL DEFAULT '{}';
ALTER TABLE relationship_history ADD COLUMN revision INTEGER
  CHECK(revision IS NULL OR (typeof(revision)='integer' AND revision>0));

DROP TRIGGER activity_relationships_update;
CREATE TRIGGER activity_relationships_update AFTER UPDATE ON relationships
WHEN (OLD.label IS NOT NEW.label OR OLD.state IS NOT NEW.state OR OLD.archived IS NOT NEW.archived OR OLD.attributes IS NOT NEW.attributes) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'relationship',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE CASE WHEN NEW.state='canon' AND OLD.state<>'canon' THEN 'approved' ELSE 'updated' END END,(SELECT title FROM records WHERE id=NEW.source_id) || ' → ' || (SELECT title FROM records WHERE id=NEW.target_id),CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Relationship archived' ELSE 'Relationship restored' END WHEN OLD.label IS NEW.label AND OLD.attributes IS NOT NEW.attributes THEN 'Relationship details updated' ELSE 'Relationship updated' END || ' · ' || NEW.label,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;
