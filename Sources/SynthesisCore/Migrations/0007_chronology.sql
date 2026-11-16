CREATE TABLE chronology_lanes (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 parent_id TEXT,
 name TEXT NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('branch','period')),
 start_label TEXT NOT NULL DEFAULT '',
 end_label TEXT NOT NULL DEFAULT '',
 notes TEXT NOT NULL DEFAULT '',
 archived INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 UNIQUE(id,world_id),
 FOREIGN KEY(parent_id,world_id) REFERENCES chronology_lanes(id,world_id)
);
CREATE TABLE chronology_placements (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 event_id TEXT NOT NULL REFERENCES events(id),
 lane_id TEXT NOT NULL,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 UNIQUE(world_id,event_id),
 FOREIGN KEY(lane_id,world_id) REFERENCES chronology_lanes(id,world_id)
);
CREATE INDEX chronology_world ON chronology_lanes(world_id,archived);
