CREATE TABLE rules (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 system_id TEXT NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('source','cost','limit','progression','technique','exception')),
 title TEXT NOT NULL,
 body TEXT NOT NULL,
 state TEXT NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','canon')),
 origin TEXT NOT NULL DEFAULT 'user-authored',
 canonical TEXT,
 position INTEGER NOT NULL DEFAULT 0,
 archived INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 FOREIGN KEY(system_id,world_id) REFERENCES records(id,world_id)
);
CREATE INDEX rules_system ON rules(world_id,system_id);
CREATE TABLE rule_scenarios (
 id TEXT PRIMARY KEY,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 system_id TEXT NOT NULL,
 title TEXT NOT NULL,
 situation TEXT NOT NULL,
 expectation TEXT NOT NULL CHECK(expectation IN ('works','fails','unclear')),
 verdict TEXT NOT NULL DEFAULT '',
 archived INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 FOREIGN KEY(system_id,world_id) REFERENCES records(id,world_id)
);
CREATE INDEX rule_scenarios_system ON rule_scenarios(world_id,system_id);
