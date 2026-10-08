ALTER TABLE app.refresh_tokens ADD COLUMN successor_hash text
  CHECK (successor_hash IS NULL OR char_length(successor_hash) = 64);
