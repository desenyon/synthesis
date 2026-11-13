CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS conversations (id TEXT PRIMARY KEY,world_id TEXT NOT NULL REFERENCES worlds(id),title TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,UNIQUE(id,world_id));
CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY,world_id TEXT NOT NULL REFERENCES worlds(id),conversation_id TEXT NOT NULL,role TEXT NOT NULL,body TEXT NOT NULL,state TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,FOREIGN KEY(conversation_id,world_id) REFERENCES conversations(id,world_id));
CREATE INDEX IF NOT EXISTS messages_conversation ON messages(conversation_id,created_at);
CREATE TABLE IF NOT EXISTS rich_documents (record_id TEXT PRIMARY KEY REFERENCES records(id),rtf TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS native_revisions (id TEXT PRIMARY KEY,world_id TEXT NOT NULL REFERENCES worlds(id),record_id TEXT NOT NULL,version INTEGER NOT NULL,snapshot TEXT NOT NULL,created_at TEXT NOT NULL,FOREIGN KEY(record_id,world_id) REFERENCES records(id,world_id),UNIQUE(record_id,version));
CREATE TABLE IF NOT EXISTS boards (id TEXT PRIMARY KEY,world_id TEXT NOT NULL REFERENCES worlds(id),name TEXT NOT NULL,content TEXT NOT NULL,kind TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
