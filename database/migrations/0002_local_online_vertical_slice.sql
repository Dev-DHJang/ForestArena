CREATE TABLE app.players (
  player_id uuid PRIMARY KEY,
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 40),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.refresh_tokens (
  token_hash text PRIMARY KEY CHECK (char_length(token_hash) = 64),
  player_id uuid NOT NULL REFERENCES app.players(player_id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_player_id_idx ON app.refresh_tokens(player_id);

CREATE TABLE app.matches (
  match_id uuid PRIMARY KEY,
  status text NOT NULL CHECK (status IN ('matched', 'running', 'ended')),
  winner_player_id uuid REFERENCES app.players(player_id),
  result_reason text CHECK (result_reason IN ('combat', 'draw', 'disconnect')),
  final_tick integer CHECK (final_tick IS NULL OR final_tick >= 0),
  snapshot_hash text CHECK (snapshot_hash IS NULL OR char_length(snapshot_hash) = 64),
  created_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  ended_at timestamptz,
  CHECK ((status = 'ended') = (ended_at IS NOT NULL))
);

CREATE TABLE app.match_participants (
  match_id uuid NOT NULL REFERENCES app.matches(match_id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES app.players(player_id),
  slot smallint NOT NULL CHECK (slot IN (1, 2)),
  character_id text NOT NULL CHECK (character_id IN ('ja-hyun', 'myo-ryung')),
  PRIMARY KEY (match_id, slot),
  UNIQUE (match_id, player_id)
);
