ALTER TABLE proposals ADD COLUMN message_id TEXT;
ALTER TABLE proposals ADD COLUMN conversation_id TEXT;
CREATE INDEX proposals_message ON proposals(world_id,conversation_id);
CREATE TABLE message_context (
 message_id TEXT NOT NULL,
 world_id TEXT NOT NULL REFERENCES worlds(id),
 record_id TEXT NOT NULL,
 reason TEXT NOT NULL,
 position INTEGER NOT NULL,
 PRIMARY KEY(message_id,record_id)
);
