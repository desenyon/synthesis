CREATE TABLE simulation_runs (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
  unit TEXT NOT NULL CHECK(length(unit) BETWEEN 1 AND 40),
  snapshot TEXT NOT NULL CHECK(length(CAST(snapshot AS BLOB)) <= 6000000),
  completed_steps INTEGER NOT NULL CHECK(completed_steps BETWEEN 1 AND 10000),
  total_steps INTEGER NOT NULL CHECK(total_steps BETWEEN completed_steps AND 10000),
  archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision)='integer' AND revision>=1),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX simulation_runs_world ON simulation_runs(world_id,archived,created_at);
