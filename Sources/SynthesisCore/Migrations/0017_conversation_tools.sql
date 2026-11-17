-- Conversation branches share source lore, never proposal approval capabilities.
CREATE TABLE conversation_branches (
  conversation_id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  parent_conversation_id TEXT NOT NULL,
  fork_message_id TEXT NOT NULL REFERENCES messages(id),
  created_at TEXT NOT NULL,
  FOREIGN KEY(conversation_id,world_id) REFERENCES conversations(id,world_id),
  FOREIGN KEY(parent_conversation_id,world_id) REFERENCES conversations(id,world_id),
  CHECK(conversation_id<>parent_conversation_id)
);
CREATE INDEX conversation_branch_parent ON conversation_branches(world_id,parent_conversation_id);
CREATE TABLE conversation_message_origins (
  message_id TEXT PRIMARY KEY NOT NULL REFERENCES messages(id),
  world_id TEXT NOT NULL REFERENCES worlds(id),
  source_message_id TEXT NOT NULL REFERENCES messages(id),
  created_at TEXT NOT NULL,
  CHECK(message_id<>source_message_id)
);
CREATE TABLE prompt_recipes (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  title TEXT NOT NULL,
  instructions TEXT NOT NULL,
  mode TEXT NOT NULL CHECK(mode IN ('Create','Develop','Critique','Simulate','Canonize')),
  version INTEGER NOT NULL DEFAULT 1 CHECK(version>=1),
  archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(id,world_id)
);
CREATE INDEX prompt_recipes_world ON prompt_recipes(world_id,archived,updated_at);
