-- A what-if branch is an independent world copied from another. These tables remember where each
-- copy came from, so its changes can be proposed back to the original through ordinary review.
CREATE TABLE world_branches (
  world_id TEXT PRIMARY KEY REFERENCES worlds(id),
  parent_id TEXT NOT NULL REFERENCES worlds(id),
  created_at TEXT NOT NULL,
  last_proposal_id TEXT
);
-- One row per record copied into the branch: the original's ID, version and text at branch time.
CREATE TABLE branch_origins (
  world_id TEXT NOT NULL REFERENCES worlds(id),
  record_id TEXT NOT NULL,
  origin_id TEXT NOT NULL,
  origin_version INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL,
  PRIMARY KEY(world_id, record_id)
);
-- Relationships and events that existed when the branch was made; anything else is new.
CREATE TABLE branch_items (
  world_id TEXT NOT NULL REFERENCES worlds(id),
  item_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('relationship','event')),
  PRIMARY KEY(world_id, item_id)
);
