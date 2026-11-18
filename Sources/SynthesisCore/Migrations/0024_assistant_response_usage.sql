CREATE TABLE assistant_response_usage (
  message_id TEXT PRIMARY KEY REFERENCES messages(id),
  provider TEXT NOT NULL CHECK (provider IN ('claude-code','codex')),
  input_tokens INTEGER NOT NULL CHECK (input_tokens >= 0),
  output_tokens INTEGER NOT NULL CHECK (output_tokens >= 0),
  cache_read_input_tokens INTEGER CHECK (cache_read_input_tokens >= 0),
  cache_write_input_tokens INTEGER CHECK (cache_write_input_tokens >= 0)
) STRICT, WITHOUT ROWID;
