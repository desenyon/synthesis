-- Committed editing activity, separate from fictional chronology. No document bodies or credentials.
CREATE TABLE world_activity (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  object_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('record','relationship','event','board','proposal','lane','world','conversation')),
  action TEXT NOT NULL CHECK(action IN ('created','updated','approved','rejected','archived','restored','linked','unlinked','moved','recorded')),
  title TEXT NOT NULL,
  detail TEXT NOT NULL,
  created_at TEXT NOT NULL,
  record_version INTEGER,
  board_kind TEXT CHECK(board_kind IS NULL OR board_kind IN ('atlas','canvas')),
  reconstructed INTEGER NOT NULL DEFAULT 0 CHECK(reconstructed IN (0,1))
);
CREATE INDEX activity_world_date ON world_activity(world_id,created_at DESC);
CREATE INDEX activity_world_kind ON world_activity(world_id,kind,created_at DESC);
CREATE INDEX activity_world_action ON world_activity(world_id,action,created_at DESC);
-- Scoped only to an atomic import. Rollback removes this guard too; never exported.
CREATE TABLE activity_imports (world_id TEXT PRIMARY KEY);

-- Existing-data reconstruction runs atomically with this migration in ActivityHistoryMigration.

CREATE TRIGGER activity_worlds_create AFTER INSERT ON worlds
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.id,NEW.id,'world','created',NEW.name,'World created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_worlds_update AFTER UPDATE ON worlds
WHEN (OLD.name IS NOT NEW.name OR OLD.description IS NOT NEW.description) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.id,NEW.id,'world','updated',NEW.name,'World name or description updated',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_records_create AFTER INSERT ON records
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'record','created',NEW.title,'Created · revision ' || NEW.version,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NEW.version,NULL);
END;

CREATE TRIGGER activity_records_revision AFTER UPDATE OF version ON records
WHEN (NEW.version<>OLD.version) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'record',CASE WHEN NEW.state='canon' THEN 'approved' ELSE 'updated' END,NEW.title,(CASE WHEN NEW.state='canon' THEN 'Canon accepted · revision ' ELSE 'Draft saved · revision ' END) || NEW.version || CASE WHEN OLD.title<>NEW.title THEN ' · previously ' || OLD.title ELSE '' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NEW.version,NULL);
END;

CREATE TRIGGER activity_records_archive AFTER UPDATE OF archived ON records
WHEN (OLD.archived<>NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,NEW.title,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Record archived' ELSE 'Record restored' END ELSE 'Record updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NEW.version,NULL);
END;

CREATE TRIGGER activity_relationships_create AFTER INSERT ON relationships
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'relationship','linked',(SELECT title FROM records WHERE id=NEW.source_id) || ' → ' || (SELECT title FROM records WHERE id=NEW.target_id),'Relationship created · ' || NEW.label,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_relationships_update AFTER UPDATE ON relationships
WHEN (OLD.label IS NOT NEW.label OR OLD.state IS NOT NEW.state OR OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'relationship',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE CASE WHEN NEW.state='canon' AND OLD.state<>'canon' THEN 'approved' ELSE 'updated' END END,(SELECT title FROM records WHERE id=NEW.source_id) || ' → ' || (SELECT title FROM records WHERE id=NEW.target_id),CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Relationship archived' ELSE 'Relationship restored' END ELSE 'Relationship updated' END || ' · ' || NEW.label,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_events_create AFTER INSERT ON events
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'event','created',NEW.title,'Event created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_events_update AFTER UPDATE ON events
WHEN ((1) AND (OLD.title IS NOT NEW.title OR OLD.date_label IS NOT NEW.date_label OR OLD.sort_order IS NOT NEW.sort_order OR OLD.source_id IS NOT NEW.source_id OR OLD.body IS NOT NEW.body OR OLD.state IS NOT NEW.state OR OLD.archived IS NOT NEW.archived)) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'event',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,NEW.title,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Event archived' ELSE 'Event restored' END ELSE 'Event updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_boards_create AFTER INSERT ON boards
WHEN (NEW.kind IN ('atlas','canvas')) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'board','created',NEW.name,'Workspace created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NEW.kind);
END;

CREATE TRIGGER activity_boards_update AFTER UPDATE ON boards
WHEN (NEW.kind IN ('atlas','canvas') AND (OLD.name IS NOT NEW.name OR OLD.archived IS NOT NEW.archived OR synthesis_board_changed(OLD.content,NEW.content))) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'board',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,NEW.name,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Workspace archived' ELSE 'Workspace restored' END ELSE 'Workspace updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NEW.kind);
END;

CREATE TRIGGER activity_chronology_lanes_create AFTER INSERT ON chronology_lanes
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'lane','created',NEW.name,'History branch or period created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_chronology_lanes_update AFTER UPDATE ON chronology_lanes
WHEN ((1) AND (OLD.parent_id IS NOT NEW.parent_id OR OLD.name IS NOT NEW.name OR OLD.kind IS NOT NEW.kind OR OLD.start_label IS NOT NEW.start_label OR OLD.end_label IS NOT NEW.end_label OR OLD.notes IS NOT NEW.notes OR OLD.archived IS NOT NEW.archived)) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'lane',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,NEW.name,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'History branch or period archived' ELSE 'History branch or period restored' END ELSE 'History branch or period updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_conversations_create AFTER INSERT ON conversations
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'conversation','created',NEW.title,'Conversation created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_conversations_update AFTER UPDATE ON conversations
WHEN ((1) AND (OLD.title IS NOT NEW.title OR OLD.archived IS NOT NEW.archived)) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'conversation',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,NEW.title,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Conversation archived' ELSE 'Conversation restored' END ELSE 'Conversation updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_proposals_create AFTER INSERT ON proposals
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'proposal','created',COALESCE(NULLIF(NEW.reason,''),'Proposed changes'),'Changes proposed for review',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_proposals_review AFTER UPDATE ON proposals
WHEN (OLD.state IS NOT NEW.state OR OLD.payload IS NOT NEW.payload) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.id,'proposal',CASE NEW.state WHEN 'accepted' THEN 'approved' WHEN 'rejected' THEN 'rejected' ELSE 'updated' END,COALESCE(NULLIF(NEW.reason,''),'Proposed changes'),CASE NEW.state WHEN 'accepted' THEN 'Review completed' WHEN 'rejected' THEN 'Proposal dismissed' ELSE 'Review decisions updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_rules_create AFTER INSERT ON rules
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.system_id,'record','created',NEW.title,'Rule created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_rules_update AFTER UPDATE ON rules
WHEN (OLD.kind IS NOT NEW.kind OR OLD.title IS NOT NEW.title OR OLD.body IS NOT NEW.body OR OLD.state IS NOT NEW.state OR OLD.canonical IS NOT NEW.canonical OR OLD.position IS NOT NEW.position OR OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.system_id,'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE CASE WHEN NEW.state='canon' AND OLD.state<>'canon' THEN 'approved' ELSE 'updated' END END,NEW.title,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Rule archived' ELSE 'Rule restored' END WHEN NEW.state='canon' AND OLD.state<>'canon' THEN 'Rule canon accepted' ELSE 'Rule updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_rule_scenarios_create AFTER INSERT ON rule_scenarios
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.system_id,'record','created',NEW.title,'Scenario created',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_rule_scenarios_update AFTER UPDATE ON rule_scenarios
WHEN (OLD.title IS NOT NEW.title OR OLD.situation IS NOT NEW.situation OR OLD.expectation IS NOT NEW.expectation OR OLD.verdict IS NOT NEW.verdict OR OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.system_id,'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,NEW.title,CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Scenario archived' ELSE 'Scenario restored' END ELSE 'Scenario updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_links_insert AFTER INSERT ON links
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.source_id,'record','linked',(SELECT title FROM records WHERE id=NEW.source_id),'Lore link added · ' || (SELECT title FROM records WHERE id=NEW.target_id),strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_links_delete AFTER DELETE ON links
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=OLD.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),OLD.world_id,OLD.source_id,'record','unlinked',(SELECT title FROM records WHERE id=OLD.source_id),'Lore link removed · ' || (SELECT title FROM records WHERE id=OLD.target_id),strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_chronology_placements_insert AFTER INSERT ON chronology_placements
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.event_id,'event','moved',(SELECT title FROM events WHERE id=NEW.event_id),'Event placed in history · ' || (SELECT name FROM chronology_lanes WHERE id=NEW.lane_id),strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_chronology_placements_update AFTER UPDATE ON chronology_placements
WHEN (OLD.lane_id IS NOT NEW.lane_id) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.event_id,'event','moved',(SELECT title FROM events WHERE id=NEW.event_id),'Event placed in history · ' || (SELECT name FROM chronology_lanes WHERE id=NEW.lane_id),strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_chronology_placements_delete AFTER DELETE ON chronology_placements
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=OLD.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),OLD.world_id,OLD.event_id,'event','moved',(SELECT title FROM events WHERE id=OLD.event_id),'Event returned to All history',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_record_sections_create AFTER INSERT ON record_sections
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.parent_id,'record','linked',(SELECT title FROM records WHERE id=NEW.record_id),'Entity section added',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_record_sections_update AFTER UPDATE ON record_sections
WHEN (OLD.position IS NOT NEW.position OR OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.parent_id,'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,(SELECT title FROM records WHERE id=NEW.record_id),CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Entity section archived' ELSE 'Entity section restored' END ELSE 'Entity section updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_creative_components_create AFTER INSERT ON creative_components
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.record_id,'record','linked',(SELECT title FROM records WHERE id=NEW.record_id),'Creative component added',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_creative_components_update AFTER UPDATE ON creative_components
WHEN (OLD.parent_id IS NOT NEW.parent_id OR OLD.scope IS NOT NEW.scope OR OLD.kind IS NOT NEW.kind OR OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.record_id,'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,(SELECT title FROM records WHERE id=NEW.record_id),CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Creative component archived' ELSE 'Creative component restored' END ELSE 'Creative component updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_record_artwork_create AFTER INSERT ON record_artwork
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.record_id,'record','linked',(SELECT title FROM records WHERE id=NEW.record_id),'Record artwork added',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_record_artwork_update AFTER UPDATE ON record_artwork
WHEN (OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,NEW.record_id,'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,(SELECT title FROM records WHERE id=NEW.record_id),CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Record artwork archived' ELSE 'Record artwork restored' END ELSE 'Record artwork updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_rule_prerequisites_create AFTER INSERT ON rule_prerequisites
WHEN (1) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,(SELECT system_id FROM rules WHERE id=NEW.rule_id),'record','linked',(SELECT title FROM rules WHERE id=NEW.rule_id),'Technique prerequisite added',strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_rule_prerequisites_update AFTER UPDATE ON rule_prerequisites
WHEN (OLD.archived IS NOT NEW.archived) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),NEW.world_id,(SELECT system_id FROM rules WHERE id=NEW.rule_id),'record',CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'archived' ELSE 'restored' END ELSE 'updated' END,(SELECT title FROM rules WHERE id=NEW.rule_id),CASE WHEN OLD.archived<>NEW.archived THEN CASE WHEN NEW.archived=1 THEN 'Technique prerequisite archived' ELSE 'Technique prerequisite restored' END ELSE 'Technique prerequisite updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_preferences_insert AFTER INSERT ON preferences
WHEN ((NEW.key LIKE 'world-cover:%' OR NEW.key LIKE 'world-defaults:%') AND EXISTS(SELECT 1 FROM worlds WHERE id=substr(NEW.key,instr(NEW.key,':')+1))) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=substr(NEW.key,instr(NEW.key,':')+1))
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),substr(NEW.key,instr(NEW.key,':')+1),substr(NEW.key,instr(NEW.key,':')+1),'world','updated',(SELECT name FROM worlds WHERE id=substr(NEW.key,instr(NEW.key,':')+1)),CASE WHEN NEW.key LIKE 'world-cover:%' THEN 'World artwork updated' ELSE 'World defaults updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;

CREATE TRIGGER activity_preferences_update AFTER UPDATE ON preferences
WHEN ((NEW.key LIKE 'world-cover:%' OR NEW.key LIKE 'world-defaults:%') AND EXISTS(SELECT 1 FROM worlds WHERE id=substr(NEW.key,instr(NEW.key,':')+1)) AND OLD.value<>NEW.value) AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=substr(NEW.key,instr(NEW.key,':')+1))
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at,record_version,board_kind)
  VALUES(synthesis_uuid(),substr(NEW.key,instr(NEW.key,':')+1),substr(NEW.key,instr(NEW.key,':')+1),'world','updated',(SELECT name FROM worlds WHERE id=substr(NEW.key,instr(NEW.key,':')+1)),CASE WHEN NEW.key LIKE 'world-cover:%' THEN 'World artwork updated' ELSE 'World defaults updated' END,strftime('%Y-%m-%dT%H:%M:%SZ','now'),NULL,NULL);
END;
