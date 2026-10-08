CREATE TABLE app.player_profiles (
  player_id uuid PRIMARY KEY REFERENCES app.players(player_id),
  profile jsonb NOT NULL CHECK (jsonb_typeof(profile) = 'object'),
  revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE app.profile_requests (
  player_id uuid NOT NULL REFERENCES app.player_profiles(player_id),
  request_id uuid NOT NULL,
  request_hash text NOT NULL,
  response jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (player_id, request_id)
);
