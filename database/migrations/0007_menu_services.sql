-- ADR-033: additive development menu data. Original player/result rows stay intact.
ALTER TABLE app.players ADD COLUMN canonical_player_id uuid REFERENCES app.players(player_id);
ALTER TABLE app.players ADD CONSTRAINT players_canonical_not_self CHECK (canonical_player_id IS NULL OR canonical_player_id <> player_id);
DROP INDEX app.players_nickname_unique;
CREATE UNIQUE INDEX players_nickname_unique ON app.players (lower(nickname) COLLATE "C") WHERE nickname IS NOT NULL AND canonical_player_id IS NULL;
CREATE TABLE app.menu_service_identity (singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton), service_id uuid NOT NULL UNIQUE);
INSERT INTO app.menu_service_identity (service_id) VALUES (gen_random_uuid());
CREATE TABLE app.identity_merge_requests (
 actor_id uuid NOT NULL REFERENCES app.players, request_id uuid NOT NULL, request_hash text NOT NULL,
 response jsonb NOT NULL, source_player_id uuid REFERENCES app.players, originals jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(actor_id,request_id)
);
CREATE TABLE app.menu_offline_events (
 event_id uuid PRIMARY KEY, player_id uuid NOT NULL REFERENCES app.players, mode text NOT NULL CHECK(mode IN ('ai','solo','team')),
 outcome text NOT NULL CHECK(outcome IN ('win','loss','draw')), character_id text NOT NULL,
 ended_at timestamptz NOT NULL, payload_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX menu_offline_player_time ON app.menu_offline_events(player_id,ended_at DESC);
CREATE TABLE app.menu_friend_requests (
 request_id uuid PRIMARY KEY, from_player_id uuid NOT NULL REFERENCES app.players, to_player_id uuid NOT NULL REFERENCES app.players,
 state text NOT NULL CHECK(state IN ('pending','accepted','rejected','cancelled')), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(from_player_id <> to_player_id)
);
CREATE TABLE app.menu_friendships (
 first_player_id uuid NOT NULL REFERENCES app.players, second_player_id uuid NOT NULL REFERENCES app.players,
 created_at timestamptz NOT NULL DEFAULT now(), removed_at timestamptz, PRIMARY KEY(first_player_id,second_player_id), CHECK(first_player_id < second_player_id)
);
CREATE TABLE app.menu_presence (player_id uuid PRIMARY KEY REFERENCES app.players, state text NOT NULL CHECK(state IN ('online','offline')), last_seen timestamptz NOT NULL DEFAULT now());
CREATE TABLE app.menu_lan_rooms (
 room_code text NOT NULL, host_player_id uuid NOT NULL REFERENCES app.players, invite_code text NOT NULL,
 state text NOT NULL CHECK(state IN ('waiting','closed')), updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(room_code,invite_code)
);
CREATE TABLE app.menu_invites (
 invite_id uuid PRIMARY KEY, from_player_id uuid NOT NULL REFERENCES app.players, to_player_id uuid NOT NULL REFERENCES app.players,
 room_code text NOT NULL, invite_code text NOT NULL,
 FOREIGN KEY(room_code,invite_code) REFERENCES app.menu_lan_rooms,
 state text NOT NULL CHECK(state IN ('pending','accepted','rejected')), expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(from_player_id <> to_player_id)
);
CREATE TABLE app.menu_social_operations (
 actor_id uuid NOT NULL REFERENCES app.players, operation_key text NOT NULL, request_hash text NOT NULL, response jsonb NOT NULL,
 PRIMARY KEY(actor_id,operation_key)
);
CREATE TABLE app.menu_lan_matches (
 match_id uuid PRIMARY KEY, room_code text NOT NULL, registration_hash text NOT NULL, result_hash text,
 result_reason text CHECK(result_reason IN ('combat','draw','disconnect','abandoned')), winner_player_id uuid REFERENCES app.players,
 final_tick integer CHECK(final_tick >= 0), snapshot_hash text, registered_at timestamptz NOT NULL DEFAULT now(), ended_at timestamptz
);
CREATE TABLE app.menu_lan_participants (
 match_id uuid NOT NULL REFERENCES app.menu_lan_matches, player_id uuid NOT NULL REFERENCES app.players,
 slot smallint NOT NULL CHECK(slot IN (1,2)), character_id text NOT NULL, accessory_id text NOT NULL,
 PRIMARY KEY(match_id,slot), UNIQUE(match_id,player_id)
);
-- Keep the older duel_dev path compatible with the four approved IDs too.
ALTER TABLE app.match_participants DROP CONSTRAINT match_participants_character_id_check;
ALTER TABLE app.match_participants ADD CONSTRAINT match_participants_character_id_check CHECK(character_id IN ('ja-hyun','myo-ryung','nabi','yu-ran'));
