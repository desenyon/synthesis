-- Additive, world-owned structured entity profiles. Existing lore and canon are untouched.
CREATE TABLE entity_types (
 id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id), name TEXT NOT NULL,
 description TEXT NOT NULL DEFAULT '', parent_type_id TEXT,
 fields_json TEXT NOT NULL DEFAULT '[]', defaults_json TEXT NOT NULL DEFAULT '{}',
 version INTEGER NOT NULL DEFAULT 1 CHECK(version >= 1), archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL, UNIQUE(id,world_id),
 FOREIGN KEY(parent_type_id,world_id) REFERENCES entity_types(id,world_id) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX entity_types_world ON entity_types(world_id,archived,name);
CREATE TABLE entity_profiles (
 id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id), record_id TEXT NOT NULL UNIQUE,
 type_id TEXT NOT NULL, values_json TEXT NOT NULL DEFAULT '{}', canonical_json TEXT,
 version INTEGER NOT NULL DEFAULT 1 CHECK(version >= 1), created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 UNIQUE(id,world_id), FOREIGN KEY(record_id,world_id) REFERENCES records(id,world_id),
 FOREIGN KEY(type_id,world_id) REFERENCES entity_types(id,world_id)
);
CREATE TABLE entity_profile_history (
 id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id), profile_id TEXT NOT NULL,
 version INTEGER NOT NULL CHECK(version >= 1), snapshot_json TEXT NOT NULL, created_at TEXT NOT NULL,
 FOREIGN KEY(profile_id,world_id) REFERENCES entity_profiles(id,world_id), UNIQUE(profile_id,version)
);
CREATE TABLE entity_type_history (
 id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id), type_id TEXT NOT NULL,
 version INTEGER NOT NULL CHECK(version >= 1), snapshot_json TEXT NOT NULL, created_at TEXT NOT NULL,
 FOREIGN KEY(type_id,world_id) REFERENCES entity_types(id,world_id), UNIQUE(type_id,version)
);
CREATE TABLE entity_templates (
 id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id), type_id TEXT NOT NULL,
 name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '',
 values_json TEXT NOT NULL DEFAULT '{}', version INTEGER NOT NULL DEFAULT 1 CHECK(version >= 1),
 archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 FOREIGN KEY(type_id,world_id) REFERENCES entity_types(id,world_id)
);
CREATE INDEX entity_templates_world ON entity_templates(world_id,archived,name);
-- Derived, disposable text index; image bytes are never indexed or sent as lore text.
CREATE VIRTUAL TABLE entity_profile_search USING fts5(record_id UNINDEXED,world_id UNINDEXED,content);
CREATE TABLE entity_template_history (
 id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id), template_id TEXT NOT NULL,
 version INTEGER NOT NULL CHECK(version >= 1), snapshot_json TEXT NOT NULL, created_at TEXT NOT NULL,
 FOREIGN KEY(template_id) REFERENCES entity_templates(id), UNIQUE(template_id,version)
);
CREATE TRIGGER activity_entity_properties_create AFTER INSERT ON entity_profiles
WHEN NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
 INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
 VALUES(synthesis_uuid(),NEW.world_id,NEW.record_id,'record','updated',(SELECT title FROM records WHERE id=NEW.record_id),'Structured property profile created',NEW.updated_at);
END;
CREATE TRIGGER activity_entity_properties_update AFTER UPDATE ON entity_profiles
WHEN NEW.version!=OLD.version AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
 INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
 VALUES(synthesis_uuid(),NEW.world_id,NEW.record_id,'record',CASE WHEN NEW.canonical_json IS NOT OLD.canonical_json THEN 'approved' ELSE 'updated' END,(SELECT title FROM records WHERE id=NEW.record_id),CASE WHEN NEW.canonical_json IS NOT OLD.canonical_json THEN 'Property canon accepted' ELSE 'Structured property draft saved' END,NEW.updated_at);
END;
CREATE TRIGGER activity_entity_type_update AFTER UPDATE ON entity_types
WHEN NEW.version!=OLD.version AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
 INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
 VALUES(synthesis_uuid(),NEW.world_id,NEW.world_id,'world','updated',NEW.name,'Entity type updated',NEW.updated_at);
END;
